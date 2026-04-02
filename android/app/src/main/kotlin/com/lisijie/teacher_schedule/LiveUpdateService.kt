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
        private const val UPDATE_INTERVAL = 60000L // 1分钟更新一次

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

        // 获取当前课程信息
        val prefs = getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
        val courseName = prefs.getString("course_name", null)
        val courseLocation = prefs.getString("location", null)
        val progress = prefs.getInt("progress", 0)
        val timeRange = prefs.getString("time_range", "")

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
     */
    private fun startUpdateLoop() {
        updateRunnable = Runnable {
            try {
                // 刷新通知
                updateNotification()

                // 刷新小组件
                refreshWidgets()

                // 检查是否需要显示超级岛提醒
                checkAndShowHyperIsland()

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
