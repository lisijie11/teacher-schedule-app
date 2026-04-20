package com.lisijie.teacher_schedule

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.Calendar

/**
 * 实时更新服务 - 前台服务保活
 * 参考 mikcb 项目实现：
 * - 使用 START_STICKY 确保服务被杀死自动重启
 * - 显示常驻通知，支持折叠/展开双布局
 * - 定时刷新小组件和课程状态
 */
class LiveUpdateService : Service() {

    companion object {
        private const val TAG = "LiveUpdateService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "course_live_update"
        private const val UPDATE_INTERVAL = 60000L // 1分钟更新一次通知（保持进度同步）

        private var instance: LiveUpdateService? = null
        fun getInstance(): LiveUpdateService? = instance

        /**
         * 启动服务
         */
        fun start(context: Context) {
            val intent = Intent(context, LiveUpdateService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * 停止服务
         */
        fun stop(context: Context) {
            context.stopService(Intent(context, LiveUpdateService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var updateRunnable: Runnable? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var restartReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "LiveUpdateService 已创建")

        createNotificationChannel()
        acquireWakeLock()
        registerRestartReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "LiveUpdateService 已启动")

        // 启动为前台服务
        startForeground(NOTIFICATION_ID, createNotification())

        // 开始定时更新
        startUpdateLoop()

        // 立即刷新一次小组件
        refreshWidgets()

        // START_STICKY: 服务被杀死会自动重启
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "LiveUpdateService 已销毁")

        // 停止定时更新
        updateRunnable?.let { handler.removeCallbacks(it) }

        // 释放唤醒锁
        wakeLock?.let {
            if (it.isHeld) it.release()
        }

        // 注销广播接收器
        restartReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "注销广播接收器失败", e)
            }
        }

        // 发送广播尝试重启服务
        sendBroadcast(Intent("com.lisijie.teacher_schedule.RESTART_LIVE_UPDATE"))
    }

    /**
     * 创建通知渠道
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "课程实时更新",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "显示当前课程进度和下一节课信息"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * 创建通知 - 使用折叠/展开双布局
     */
    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 获取当前课程信息（从 snapshot_json 读取，与小部件保持一致）
        val prefs = getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
        val snapshotJson = prefs.getString("snapshot_json", null)

        var courseName: String? = null
        var courseLocation: String? = null
        var progress = 0
        var timeRange = ""

        if (snapshotJson != null) {
            try {
                val snapshot = JSONObject(snapshotJson)
                val highlightCourse = snapshot.optJSONObject("highlightCourse")
                if (highlightCourse != null) {
                    courseName = highlightCourse.optString("name", null)
                    if (courseName.isNullOrEmpty()) courseName = null
                    courseLocation = highlightCourse.optString("location", null)
                    if (courseLocation.isNullOrEmpty()) courseLocation = null
                    progress = highlightCourse.optInt("progress", 0)
                    val startTime = highlightCourse.optString("startTime", "")
                    val endTime = highlightCourse.optString("endTime", "")
                    if (startTime.isNotEmpty() && endTime.isNotEmpty()) {
                        timeRange = "$startTime - $endTime"
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "解析 snapshot_json 失败", e)
            }
        }

        // 读取下一节课信息
        val nextCourseName = prefs.getString("course_2_name", null)
        val nextCourseTime = prefs.getString("course_2_time", "")

        // 创建折叠布局
        val collapsedView = RemoteViews(packageName, R.layout.notification_collapsed).apply {
            setTextViewText(R.id.notification_title, courseName ?: "暂无课程")
            setTextViewText(R.id.notification_subtitle, 
                if (courseLocation != null) "$courseLocation · 剩余${calculateRemaining(timeRange)}" else "点击查看课表")
            setTextViewText(R.id.notification_progress_text, "$progress%")
        }

        // 创建展开布局
        val expandedView = RemoteViews(packageName, R.layout.notification_expanded).apply {
            setTextViewText(R.id.expanded_course_name, courseName ?: "暂无课程")
            setTextViewText(R.id.expanded_course_info, 
                if (courseLocation != null && timeRange != null) "$courseLocation · $timeRange" else "")
            setTextViewText(R.id.expanded_progress_percent, "$progress%")
            setTextViewText(R.id.expanded_remaining, "剩余${calculateRemaining(timeRange)}")
            setProgressBar(R.id.expanded_progress_bar, 100, progress, false)

            // 下一节课
            if (nextCourseName != null) {
                setTextViewText(R.id.next_course_name, nextCourseName)
                setTextViewText(R.id.next_course_time, nextCourseTime ?: "")
                setViewVisibility(R.id.next_course_container, android.view.View.VISIBLE)
            } else {
                setViewVisibility(R.id.next_course_container, android.view.View.GONE)
            }
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setCustomContentView(collapsedView)
            .setCustomBigContentView(expandedView)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .build()
    }

    /**
     * 计算剩余时间
     */
    private fun calculateRemaining(timeRange: String?): String {
        if (timeRange.isNullOrEmpty()) return "--"
        
        try {
            val parts = timeRange.split("-")
            if (parts.size == 2) {
                val endTime = parts[1].trim()
                val now = java.util.Calendar.getInstance()
                val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
                
                val endParts = endTime.split(":")
                if (endParts.size == 2) {
                    val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()
                    val remaining = endMinutes - currentMinutes
                    if (remaining > 0) {
                        return "${remaining}分钟"
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "计算剩余时间失败", e)
        }
        return "--"
    }

    /**
     * 开始定时更新循环
     * 双重保障：
     * 1. 每分钟更新通知
     * 2. 每5分钟重新生成 snapshot 数据并刷新小部件（确保长时间不打开 APP 时小部件仍有数据）
     */
    private fun startUpdateLoop() {
        var widgetRefreshCounter = 0
        val WIDGET_REFRESH_INTERVAL = 5 // 每5次循环（约5分钟）刷新一次小部件

        updateRunnable = Runnable {
            try {
                // 刷新通知
                updateNotification()

                // 检查是否需要显示超级岛提醒
                checkAndShowHyperIsland()

                // 定期刷新小组件数据（关键修复：解决长时间不操作后小部件不更新的问题）
                widgetRefreshCounter++
                if (widgetRefreshCounter >= WIDGET_REFRESH_INTERVAL) {
                    widgetRefreshCounter = 0
                    refreshWidgetsWithSnapshot()
                    Log.d(TAG, "定时刷新：已重新生成 snapshot 并刷新小组件")
                }
            } catch (e: Exception) {
                Log.e(TAG, "更新失败", e)
            }

            // 继续下一次更新
            handler.postDelayed(updateRunnable!!, UPDATE_INTERVAL)
        }

        handler.post(updateRunnable!!)
    }

    /**
     * 更新通知
     */
    fun updateNotification() {
        try {
            val notification = createNotification()
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "更新通知失败", e)
        }
    }

    /**
     * 刷新所有小组件：
     * 1. 从 HomeWidgetPlugin 读取 Flutter 写入的数据（不覆盖）
     * 2. 触发所有小组件 onUpdate
     *
     * 注意：不再从 ScheduleData 重新计算！
     * Flutter 端 WidgetService.updateWidget() 会通过
     * HomeWidget.saveWidgetData() 写入正确数据到 HomeWidgetPlugin SP，
     * LiveUpdateService 只需触发小组件刷新即可。
     */
    private fun refreshWidgets() {
        try {
            // 直接触发所有小组件刷新（读取 HomeWidgetPlugin 中 Flutter 写入的 snapshot JSON）
            WidgetSupport.updateAll(this)
        } catch (e: Exception) {
            Log.e(TAG, "刷新小组件失败", e)
        }
    }

    /**
     * 刷新小组件（带 snapshot 数据重新生成）
     * 
     * 关键修复：当 Flutter 进程不运行时，LiveUpdateService 作为前台服务仍然存活，
     * 可以从 ScheduleData SharedPreferences 重新计算 snapshot 并写入，
     * 确保4x4等大号小部件在长时间不打开APP的情况下也能显示课程内容。
     */
    private fun refreshWidgetsWithSnapshot() {
        try {
            // 1. 从 ScheduleData 读取课程数据并生成 snapshot
            val snapshotJson = generateSnapshotFromScheduleData(this)
            
            // 2. 写入 HomeWidgetPlugin SharedPreferences
            if (snapshotJson.isNotEmpty()) {
                val prefs = getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
                prefs.edit().putString("snapshot_json", snapshotJson).apply()
                Log.d(TAG, "已重新生成 snapshot_json (${snapshotJson.length} 字符)")
            }
            
            // 3. 触发所有小组件刷新
            WidgetSupport.updateAll(this)
        } catch (e: Exception) {
            Log.e(TAG, "刷新小组件(带数据)失败", e)
        }
    }

    /**
     * 从 ScheduleData SharedPreferences 生成完整的 snapshot JSON
     * 与 GlobalRefreshReceiver.generateSnapshotJson() 保持一致的逻辑
     */
    private fun generateSnapshotFromScheduleData(context: Context): String {
        return try {
            val now = java.util.Calendar.getInstance()
            val todayWeekday = now.get(java.util.Calendar.DAY_OF_WEEK)
            val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)

            // 转换星期
            val weekday = if (todayWeekday == java.util.Calendar.SUNDAY) 7 else todayWeekday - 1

            // 日期文字
            val weekdays = arrayOf("", "周一", "周二", "周三", "周四", "周五", "周六", "周日")
            val dateText = "${now.get(java.util.Calendar.MONTH) + 1}月${now.get(java.util.Calendar.DAY_OF_MONTH)}日 ${weekdays[weekday]}"

            // 读取课程数据
            val schedulePrefs = context.getSharedPreferences("ScheduleData", Context.MODE_PRIVATE)
            val coursesJson = schedulePrefs.getString("courses_json", null)

            // 默认作息表
            val defaultPeriods = getDefaultPeriodsForRefresh(weekday)
            val courses = mutableListOf<org.json.JSONObject>()
            val periods = org.json.JSONArray()

            for (i in 0 until defaultPeriods.length()) {
                periods.put(defaultPeriods.getJSONObject(i))
            }

            if (coursesJson != null) {
                try {
                    val json = org.json.JSONObject(coursesJson)
                    val periodsArray = json.optJSONArray("periods")
                    val coursesArray = json.optJSONArray("courses")

                    if (periodsArray != null) {
                        for (i in 0 until periodsArray.length()) {
                            periods.put(periodsArray.getJSONObject(i))
                        }
                    }
                    if (coursesArray != null) {
                        for (i in 0 until coursesArray.length()) {
                            courses.add(coursesArray.getJSONObject(i))
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "解析课程数据失败", e)
                }
            }

            // 查找当前和下一节课程
            var currentPeriod: org.json.JSONObject? = null
            var currentCourse: org.json.JSONObject? = null
            var nextPeriod: org.json.JSONObject? = null
            var nextCourse: org.json.JSONObject? = null

            for (i in 0 until periods.length()) {
                val period = periods.getJSONObject(i)
                val startHour = period.optInt("sh", 8)
                val startMinute = period.optInt("sm", 0)
                val endHour = period.optInt("eh", 9)
                val endMinute = period.optInt("em", 40)
                val startMin = startHour * 60 + startMinute
                val endMin = endHour * 60 + endMinute

                if (currentPeriod == null && currentMinutes >= startMin && currentMinutes < endMin) {
                    val course = findCourseForRefresh(courses, weekday, period.optInt("index", i + 1))
                    if (course != null && course.optString("courseName", "").isNotEmpty()) {
                        currentPeriod = period
                        currentCourse = course
                    }
                }

                if (nextPeriod == null && currentPeriod == null && currentMinutes < startMin) {
                    val course = findCourseForRefresh(courses, weekday, period.optInt("index", i + 1))
                    if (course != null && course.optString("courseName", "").isNotEmpty()) {
                        nextPeriod = period
                        nextCourse = course
                    }
                }
            }

            // 构建 allCourses
            val allCoursesJson = org.json.JSONArray()
            for (i in 0 until periods.length()) {
                val period = periods.getJSONObject(i)
                val startMin = period.optInt("sh", 8) * 60 + period.optInt("sm", 0)
                val endMin = period.optInt("eh", 9) * 60 + period.optInt("em", 40)
                val isPast = currentMinutes >= endMin
                val isActive = currentPeriod != null && currentPeriod.optInt("index") == period.optInt("index")
                val isUpcoming = nextPeriod != null && nextPeriod.optInt("index") == period.optInt("index")

                val status = when {
                    isPast -> "completed"
                    isActive -> "ongoing"
                    isUpcoming -> "upcoming"
                    else -> ""
                }

                val course = findCourseForRefresh(courses, weekday, period.optInt("index", i + 1))
                val name = if (course != null) course.optString("courseName", "") else period.optString("name", "")
                val loc = if (course != null) course.optString("classroom", "") else ""

                allCoursesJson.put(org.json.JSONObject().apply {
                    put("id", "p${period.optInt("index", i + 1)}")
                    put("name", name)
                    put("location", loc)
                    put("startTime", period.optString("startTime", ""))
                    put("endTime", period.optString("endTime", ""))
                    put("status", status)
                })
            }

            // 状态和 highlightCourse
            var state = "no_course"
            var highlightCourseJson: org.json.JSONObject? = null

            if (currentPeriod != null && currentCourse != null) {
                state = "ongoing"
                val startMin = currentPeriod.optInt("sh", 8) * 60 + currentPeriod.optInt("sm", 0)
                val endMin = currentPeriod.optInt("eh", 9) * 60 + currentPeriod.optInt("em", 40)
                val elapsed = currentMinutes - startMin
                val total = endMin - startMin
                val progress = if (total > 0) (elapsed * 100) / total else 0

                highlightCourseJson = org.json.JSONObject().apply {
                    put("id", "p${currentPeriod.optInt("index")}")
                    put("name", currentCourse.optString("courseName", ""))
                    put("location", currentCourse.optString("classroom", ""))
                    put("startTime", currentPeriod.optString("startTime", ""))
                    put("endTime", currentPeriod.optString("endTime", ""))
                    put("status", "ongoing")
                    put("progress", progress)
                    put("section", currentPeriod.optString("name", ""))
                }
            } else if (nextPeriod != null && nextCourse != null) {
                state = "upcoming"
                highlightCourseJson = org.json.JSONObject().apply {
                    put("id", "p${nextPeriod.optInt("index")}")
                    put("name", nextCourse.optString("courseName", ""))
                    put("location", nextCourse.optString("classroom", ""))
                    put("startTime", nextPeriod.optString("startTime", ""))
                    put("endTime", nextPeriod.optString("endTime", ""))
                    put("status", "upcoming")
                    put("progress", 0)
                    put("section", nextPeriod.optString("name", ""))
                }
            } else if (periods.length() > 0) {
                val lastPeriod = periods.getJSONObject(periods.length() - 1)
                val lastEndMin = lastPeriod.optInt("eh", 17) * 60 + lastPeriod.optInt("em", 40)
                if (currentMinutes >= lastEndMin) {
                    state = "completed"
                }
            }

            // 构建 gridData（4天×4节）
            val gridData = org.json.JSONArray()
            for (dayOffset in 0 until 4) {
                val targetCal = java.util.Calendar.getInstance().apply { add(java.util.Calendar.DAY_OF_YEAR, dayOffset) }
                val targetWeekdayVal = targetCal.get(java.util.Calendar.DAY_OF_WEEK)
                val targetWeekdayNum = if (targetWeekdayVal == java.util.Calendar.SUNDAY) 7 else targetWeekdayVal - 1
                val dayLabel = "${targetCal.get(java.util.Calendar.MONTH) + 1}/${targetCal.get(java.util.Calendar.DAY_OF_MONTH)}"
                val weekdayLabel = weekdays[targetWeekdayNum]
                val isToday = dayOffset == 0

                val dayCourses = org.json.JSONArray()
                for (periodIdx in 1..4) {
                    val course = findCourseForRefresh(courses, targetWeekdayNum, periodIdx)
                    dayCourses.put(org.json.JSONObject().apply {
                        put("period", periodIdx)
                        put("name", course?.optString("courseName", "") ?: "")
                        put("color", course?.optInt("colorIndex", -1) ?: -1)
                    })
                }

                gridData.put(org.json.JSONObject().apply {
                    put("date", dayLabel)
                    put("weekday", weekdayLabel)
                    put("isToday", isToday)
                    put("courses", dayCourses)
                })
            }

            // 完整 snapshot
            org.json.JSONObject().apply {
                put("date", dateText)
                put("state", state)
                put("highlightCourse", highlightCourseJson)
                put("allCourses", allCoursesJson)
                put("totalCourseCount", allCoursesJson.length())
                put("gridData", gridData)
            }.toString()
        } catch (e: Exception) {
            Log.e(TAG, "生成 snapshot 失败", e)
            ""
        }
    }

    private fun findCourseForRefresh(courses: MutableList<org.json.JSONObject>, weekday: Int, periodIndex: Int): org.json.JSONObject? {
        for (course in courses) {
            if (course.optInt("weekday") == weekday && course.optInt("periodIndex") == periodIndex) {
                return course
            }
        }
        return null
    }

    private fun getDefaultPeriodsForRefresh(weekday: Int): org.json.JSONArray {
        val workDayPeriods = arrayOf(
            mapOf("index" to 1, "sh" to 8, "sm" to 0, "eh" to 9, "em" to 40, "name" to "第1-2节", "startTime" to "08:00", "endTime" to "09:40"),
            mapOf("index" to 2, "sh" to 10, "sm" to 0, "eh" to 11, "em" to 40, "name" to "第3-4节", "startTime" to "10:00", "endTime" to "11:40"),
            mapOf("index" to 3, "sh" to 14, "sm" to 0, "eh" to 15, "em" to 40, "name" to "第5-6节", "startTime" to "14:00", "endTime" to "15:40"),
            mapOf("index" to 4, "sh" to 16, "sm" to 0, "eh" to 17, "em" to 40, "name" to "第7-8节", "startTime" to "16:00", "endTime" to "17:40"),
            mapOf("index" to 5, "sh" to 19, "sm" to 0, "eh" to 20, "em" to 40, "name" to "第9-10节", "startTime" to "19:00", "endTime" to "20:40"),
            mapOf("index" to 6, "sh" to 20, "sm" to 50, "eh" to 21, "em" to 30, "name" to "第11-12节", "startTime" to "20:50", "endTime" to "21:30"),
            mapOf("index" to 7, "sh" to 21, "sm" to 40, "eh" to 22, "em" to 20, "name" to "第13-14节", "startTime" to "21:40", "endTime" to "22:20"),
            mapOf("index" to 8, "sh" to 22, "sm" to 30, "eh" to 23, "em" to 10, "name" to "第15-16节", "startTime" to "22:30", "endTime" to "23:10")
        )

        val weekendPeriods = arrayOf(
            mapOf("index" to 1, "sh" to 8, "sm" to 30, "eh" to 10, "em" to 0, "name" to "第1-2节", "startTime" to "08:30", "endTime" to "10:00"),
            mapOf("index" to 2, "sh" to 10, "sm" to 15, "eh" to 11, "em" to 45, "name" to "第3-4节", "startTime" to "10:15", "endTime" to "11:45"),
            mapOf("index" to 3, "sh" to 14, "sm" to 0, "eh" to 15, "em" to 30, "name" to "第5-6节", "startTime" to "14:00", "endTime" to "15:30"),
            mapOf("index" to 4, "sh" to 15, "sm" to 45, "eh" to 17, "em" to 15, "name" to "第7-8节", "startTime" to "15:45", "endTime" to "17:15"),
            mapOf("index" to 5, "sh" to 19, "sm" to 0, "eh" to 20, "em" to 30, "name" to "第9-10节", "startTime" to "19:00", "endTime" to "20:30"),
            mapOf("index" to 6, "sh" to 20, "sm" to 45, "eh" to 22, "em" to 15, "name" to "第11-12节", "startTime" to "20:45", "endTime" to "22:15")
        )

        val isWeekend = weekday == 6 || weekday == 7
        val selectedPeriods = if (isWeekend) weekendPeriods else workDayPeriods
        val json = org.json.JSONArray()
        for (p in selectedPeriods) json.put(org.json.JSONObject(p))
        return json
    }

    /**
     * 检查并显示超级岛提醒
     * 从 snapshot_json 读取数据，只在有下一节课且 state=="upcoming" 时显示
     */
    private fun checkAndShowHyperIsland() {
        try {
            val prefs = getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)

            // 从 snapshot_json 读取数据
            val snapshotJson = prefs.getString("snapshot_json", null) ?: return
            val snapshot = JSONObject(snapshotJson)

            // 获取当前状态
            val state = snapshot.optString("state", "")

            // 只有即将上课(upcoming)状态才显示提醒
            if (state != "upcoming") {
                return // ongoing(正在上课)或no_course(无课)都不显示
            }

            // 获取高亮课程信息（下一节课）
            val highlightCourse = snapshot.optJSONObject("highlightCourse") ?: return
            val courseName = highlightCourse.optString("name", "")
            if (courseName.isEmpty()) return

            val startTime = highlightCourse.optString("startTime", "")
            val location = highlightCourse.optString("location", "")

            // 解析开始时间
            val timeParts = startTime.split("-")
            if (timeParts.isEmpty()) return
            val startParts = timeParts[0].trim().split(":")
            if (startParts.size < 2) return

            val startHour = startParts[0].toIntOrNull() ?: return
            val startMinute = startParts[1].toIntOrNull() ?: return

            // 计算当前时间和下一节课的时间差
            val now = Calendar.getInstance()
            val currentTotalMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val nextTotalMinutes = startHour * 60 + startMinute

            var minutesToNext = nextTotalMinutes - currentTotalMinutes
            if (minutesToNext < 0) minutesToNext += 24 * 60 // 跨天

            // 只在课程前 30 分钟内显示
            if (minutesToNext in 1..30) {
                // 构建提醒内容
                val title = "$courseName ${minutesToNext}分钟后"
                val body = if (location.isNotEmpty()) location else "准备上课"

                // 检查是否需要显示（每 5 分钟显示一次）
                val lastShownKey = "last_hyper_island_time"
                val lastShown = prefs.getLong(lastShownKey, 0)
                val currentTime = System.currentTimeMillis()

                // 如果距离上次显示超过 5 分钟，显示新的超级岛
                if (currentTime - lastShown > 5 * 60 * 1000) {
                    prefs.edit().putLong(lastShownKey, currentTime).apply()

                    // 尝试显示超级岛
                    tryShowHyperIsland(title, body, 8)

                    Log.d(TAG, "超级岛提醒已显示: $title (剩余${minutesToNext}分钟)")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "检查超级岛提醒失败", e)
        }
    }

    /**
     * 尝试显示超级岛
     */
    private fun tryShowHyperIsland(title: String, body: String, duration: Int) {
        try {
            // 检查是否有悬浮窗权限
            if (Settings.canDrawOverlays(this)) {
                HyperIslandService.show(this, title, body, duration)
            } else {
                Log.d(TAG, "没有悬浮窗权限，无法显示超级岛")
            }
        } catch (e: Exception) {
            Log.e(TAG, "显示超级岛失败", e)
        }
    }

    /**
     * 获取唤醒锁
     */
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "TeacherSchedule::LiveUpdateWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(10 * 60 * 1000L) // 10分钟
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取唤醒锁失败", e)
        }
    }

    /**
     * 注册重启广播接收器
     */
    private fun registerRestartReceiver() {
        restartReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    "com.lisijie.teacher_schedule.RESTART_LIVE_UPDATE" -> {
                        Log.d(TAG, "收到重启广播，尝试重启服务")
                        context?.let { start(it) }
                    }
                    Intent.ACTION_BOOT_COMPLETED -> {
                        Log.d(TAG, "开机完成，启动服务")
                        context?.let { start(it) }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction("com.lisijie.teacher_schedule.RESTART_LIVE_UPDATE")
            addAction(Intent.ACTION_BOOT_COMPLETED)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(restartReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(restartReceiver, filter)
        }
    }
}
