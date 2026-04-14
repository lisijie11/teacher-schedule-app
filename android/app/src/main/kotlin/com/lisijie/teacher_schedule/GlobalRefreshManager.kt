package com.lisijie.teacher_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * 全局刷新管理器 - 低功耗后台任务调度
 *
 * 使用 AlarmManager + BroadcastReceiver 实现定期刷新：
 * - 刷新间隔：15 分钟
 * - 使用 setExactAndAllowWhileIdle 确保准时执行
 * - 支持设备空闲时执行（低耗电）
 */
object GlobalRefreshManager {

    private const val TAG = "GlobalRefreshManager"
    private const val ACTION_GLOBAL_REFRESH = "com.lisijie.teacher_schedule.GLOBAL_REFRESH"
    private const val REQUEST_CODE = 10001
    private const val REFRESH_INTERVAL_MS = 15 * 60 * 1000L // 15分钟

    /**
     * 启动全局刷新
     */
    fun start(context: Context) {
        Log.d(TAG, "启动全局刷新管理器")

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, GlobalRefreshReceiver::class.java).apply {
            action = ACTION_GLOBAL_REFRESH
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 使用 setExactAndAllowWhileIdle 实现低功耗定时刷新
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + REFRESH_INTERVAL_MS,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + REFRESH_INTERVAL_MS,
                pendingIntent
            )
        }

        Log.d(TAG, "AlarmManager 全局刷新已调度（15分钟间隔）")
    }

    /**
     * 停止全局刷新
     */
    fun stop(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, GlobalRefreshReceiver::class.java).apply {
            action = ACTION_GLOBAL_REFRESH
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "AlarmManager 全局刷新已停止")
    }

    /**
     * 检查刷新服务状态
     */
    fun isRunning(context: Context): Boolean {
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, GlobalRefreshReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        return pendingIntent != null
    }
}

/**
 * 全局刷新广播接收器 - 收到 Alarm 后执行刷新
 */
class GlobalRefreshReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GlobalRefreshReceiver"
        private const val ACTION_GLOBAL_REFRESH = "com.lisijie.teacher_schedule.GLOBAL_REFRESH"
        private const val REQUEST_CODE = 10001
        private const val REFRESH_INTERVAL_MS = 15 * 60 * 1000L
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent?.action != ACTION_GLOBAL_REFRESH) return

        Log.d(TAG, "GlobalRefreshReceiver 收到广播，开始刷新")

        try {
            // 执行刷新逻辑
            performRefresh(context)

            // 重新调度下一次刷新
            reschedule(context)
        } catch (e: Exception) {
            Log.e(TAG, "刷新失败", e)

            // 即使失败也重新调度
            try {
                reschedule(context)
            } catch (e2: Exception) {
                Log.e(TAG, "重新调度失败", e2)
            }
        }
    }

    /**
     * 执行刷新 - 生成完整的 snapshot_json 并刷新小组件
     */
    private fun performRefresh(context: Context) {
        // 1. 生成完整的 snapshot_json
        val snapshotJson = generateSnapshotJson(context)

        // 2. 更新 HomeWidgetPlugin SharedPreferences
        val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
        prefs.edit().putString("snapshot_json", snapshotJson).apply()

        Log.d(TAG, "snapshot_json 已更新")

        // 3. 触发小组件刷新
        WidgetSupport.updateAll(context)
        Log.d(TAG, "小组件刷新已触发")

        // 4. 触发通知刷新
        LiveUpdateService.getInstance()?.updateNotification()
        Log.d(TAG, "通知刷新已触发")
    }

    /**
     * 生成完整的 snapshot_json（与 Flutter WidgetService.updateWidget() 保持一致）
     */
    private fun generateSnapshotJson(context: Context): String {
        val now = Calendar.getInstance()
        val todayWeekday = now.get(Calendar.DAY_OF_WEEK)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val nowSeconds = now.get(Calendar.SECOND)

        // 转换星期（Calendar: 1=周日, 2=周一... -> 我们用: 1=周一, 2=周二... 7=周日）
        val weekday = if (todayWeekday == Calendar.SUNDAY) 7 else todayWeekday - 1

        // 日期文字
        val weekdays = arrayOf("", "周一", "周二", "周三", "周四", "周五", "周六", "周日")
        val dateText = "${now.get(Calendar.MONTH) + 1}月${now.get(Calendar.DAY_OF_MONTH)}日 ${weekdays[weekday]}"

        // 读取课程数据
        val schedulePrefs = context.getSharedPreferences("ScheduleData", Context.MODE_PRIVATE)
        val coursesJson = schedulePrefs.getString("courses_json", null)

        // 默认作息表
        val defaultPeriods = getDefaultPeriods(weekday)
        val courses = mutableListOf<JSONObject>()
        val periods = JSONArray()

        // 先添加默认作息表
        for (i in 0 until defaultPeriods.length()) {
            periods.put(defaultPeriods.getJSONObject(i))
        }

        if (coursesJson != null) {
            try {
                val json = JSONObject(coursesJson)
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
        var currentPeriod: JSONObject? = null
        var currentCourse: JSONObject? = null
        var nextPeriod: JSONObject? = null
        var nextCourse: JSONObject? = null

        for (i in 0 until periods.length()) {
            val period = periods.getJSONObject(i)
            val startHour = period.optInt("sh", 8)
            val startMinute = period.optInt("sm", 0)
            val endHour = period.optInt("eh", 9)
            val endMinute = period.optInt("em", 40)
            val startMin = startHour * 60 + startMinute
            val endMin = endHour * 60 + endMinute

            // 查找当前课程
            if (currentPeriod == null && currentMinutes >= startMin && currentMinutes < endMin) {
                val course = findCourseByPeriod(courses, weekday, period.optInt("index", i + 1))
                if (course != null && course.optString("courseName", "").isNotEmpty()) {
                    currentPeriod = period
                    currentCourse = course
                }
            }

            // 查找下一节课
            if (nextPeriod == null && currentPeriod == null && currentMinutes < startMin) {
                val course = findCourseByPeriod(courses, weekday, period.optInt("index", i + 1))
                if (course != null && course.optString("courseName", "").isNotEmpty()) {
                    nextPeriod = period
                    nextCourse = course
                }
            }
        }

        // 构建 allCourses JSON
        val allCoursesJson = JSONArray()
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

            val course = findCourseByPeriod(courses, weekday, period.optInt("index", i + 1))
            val name = if (course != null) course.optString("courseName", "") else period.optString("name", "")
            val loc = if (course != null) course.optString("classroom", "") else ""

            allCoursesJson.put(JSONObject().apply {
                put("id", "p${period.optInt("index", i + 1)}")
                put("name", name)
                put("location", loc)
                put("startTime", period.optString("startTime", ""))
                put("endTime", period.optString("endTime", ""))
                put("status", status)
            })
        }

        // 确定状态和 highlightCourse
        var state = "no_course"
        var highlightCourseJson: JSONObject? = null
        var tomorrowCourseJson: JSONObject? = null

        if (currentPeriod != null && currentCourse != null) {
            state = "ongoing"
            val startMin = currentPeriod.optInt("sh", 8) * 60 + currentPeriod.optInt("sm", 0)
            val endMin = currentPeriod.optInt("eh", 9) * 60 + currentPeriod.optInt("em", 40)
            val elapsed = currentMinutes - startMin
            val total = endMin - startMin
            val progress = if (total > 0) (elapsed * 100) / total else 0

            highlightCourseJson = JSONObject().apply {
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
            highlightCourseJson = JSONObject().apply {
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

        // 构建 4天×4节 色块表格数据
        val gridData = JSONArray()
        for (dayOffset in 0 until 4) {
            val targetCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, dayOffset) }
            val targetWeekday = targetCal.get(Calendar.DAY_OF_WEEK)
            val targetWeekdayNum = if (targetWeekday == Calendar.SUNDAY) 7 else targetWeekday - 1
            val dayLabel = "${targetCal.get(Calendar.MONTH) + 1}/${targetCal.get(Calendar.DAY_OF_MONTH)}"
            val weekdayLabel = weekdays[targetWeekdayNum]
            val isToday = dayOffset == 0

            val dayCourses = JSONArray()
            for (periodIdx in 1..4) {
                val course = findCourseByPeriod(courses, targetWeekdayNum, periodIdx)
                dayCourses.put(JSONObject().apply {
                    put("period", periodIdx)
                    put("name", course?.optString("courseName", "") ?: "")
                    put("color", course?.optInt("colorIndex", -1) ?: -1)
                })
            }

            gridData.put(JSONObject().apply {
                put("date", dayLabel)
                put("weekday", weekdayLabel)
                put("isToday", isToday)
                put("courses", dayCourses)
            })
        }

        // 构建完整的 snapshot
        val snapshot = JSONObject().apply {
            put("date", dateText)
            put("state", state)
            put("highlightCourse", highlightCourseJson)
            put("tomorrowCourse", tomorrowCourseJson)
            put("allCourses", allCoursesJson)
            put("totalCourseCount", allCoursesJson.length())
            put("gridData", gridData)
        }

        return snapshot.toString()
    }

    /**
     * 根据节次查找课程
     */
    private fun findCourseByPeriod(courses: MutableList<JSONObject>, weekday: Int, periodIndex: Int): JSONObject? {
        for (course in courses) {
            if (course.optInt("weekday") == weekday && course.optInt("periodIndex") == periodIndex) {
                return course
            }
        }
        return null
    }

    /**
     * 获取默认作息表
     */
    private fun getDefaultPeriods(weekday: Int): JSONArray {
        // 工作日作息
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

        // 周末作息
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

        val json = JSONArray()
        for (p in selectedPeriods) {
            json.put(JSONObject(p))
        }
        return json
    }

    /**
     * 重新调度下一次刷新
     */
    private fun reschedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, GlobalRefreshReceiver::class.java).apply {
            action = ACTION_GLOBAL_REFRESH
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + REFRESH_INTERVAL_MS,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + REFRESH_INTERVAL_MS,
                pendingIntent
            )
        }
        Log.d(TAG, "已重新调度下一次刷新（15分钟后）")
    }
}
