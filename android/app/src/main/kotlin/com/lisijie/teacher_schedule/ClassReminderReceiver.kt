package com.lisijie.teacher_schedule

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * 课程提醒广播接收器
 * 使用 AlarmManager.setExactAndAllowWhileIdle 实现精确课前提醒
 *
 * 功能：
 * 1. 接收 AlarmManager 触发的精确闹钟
 * 2. 发送高优先级课程提醒通知
 * 3. 自动显示超级岛提醒
 *
 * 通知格式：澎湃OS3 风格
 * - 大文本显示课程名称、时间、地点
 * - 点击打开 App
 */
class ClassReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ClassReminderReceiver"
        private const val CHANNEL_ID = "class_reminder_exact"
        private const val CHANNEL_ID_HYPER = "hyper_island_reminder"

        // Action 常量
        const val ACTION_CLASS_REMINDER = "com.lisijie.teacher_schedule.ACTION_CLASS_REMINDER"
        const val ACTION_HYPER_ISLAND_REMINDER = "com.lisijie.teacher_schedule.ACTION_HYPER_ISLAND_REMINDER"

        // Extra 常量
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_COURSE_NAME = "course_name"
        const val EXTRA_TIME_RANGE = "time_range"
        const val EXTRA_LOCATION = "location"
        const val EXTRA_MINUTES_LEFT = "minutes_left"

        /**
         * 设置精确闹钟 - 课前提醒
         * @param context 上下文
         * @param triggerTimeMillis 触发时间（毫秒）
         * @param notificationId 通知 ID
         * @param courseName 课程名称
         * @param timeRange 时间范围
         * @param location 地点
         * @param minutesLeft 剩余分钟数
         */
        fun setExactAlarm(
            context: Context,
            triggerTimeMillis: Long,
            notificationId: Int,
            courseName: String,
            timeRange: String,
            location: String,
            minutesLeft: Int
        ) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, ClassReminderReceiver::class.java).apply {
                    action = ACTION_CLASS_REMINDER
                    putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                    putExtra(EXTRA_COURSE_NAME, courseName)
                    putExtra(EXTRA_TIME_RANGE, timeRange)
                    putExtra(EXTRA_LOCATION, location)
                    putExtra(EXTRA_MINUTES_LEFT, minutesLeft)
                }

                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    notificationId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // 使用 setExactAndAllowWhileIdle 保证精确触发（即使设备空闲）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTimeMillis,
                            pendingIntent
                        )
                        Log.d(TAG, "设置精确闹钟成功: ${formatTime(triggerTimeMillis)}")
                    } else {
                        // 没有精确闹钟权限，降级使用 inexact
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTimeMillis,
                            pendingIntent
                        )
                        Log.w(TAG, "没有精确闹钟权限，降级使用普通闹钟")
                    }
                } else {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTimeMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "设置精确闹钟成功: ${formatTime(triggerTimeMillis)}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "设置精确闹钟失败", e)
            }
        }

        /**
         * 取消精确闹钟
         */
        fun cancelExactAlarm(context: Context, notificationId: Int) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, ClassReminderReceiver::class.java).apply {
                    action = ACTION_CLASS_REMINDER
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    notificationId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                Log.d(TAG, "取消闹钟: $notificationId")
            } catch (e: Exception) {
                Log.e(TAG, "取消闹钟失败", e)
            }
        }

        /**
         * 格式化时间用于日志
         */
        private fun formatTime(timeMillis: Long): String {
            val sdf = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
            return sdf.format(timeMillis)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_CLASS_REMINDER -> {
                handleClassReminder(context, intent)
            }
            ACTION_HYPER_ISLAND_REMINDER -> {
                handleHyperIslandReminder(context, intent)
            }
        }
    }

    /**
     * 处理课程提醒
     */
    private fun handleClassReminder(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val courseName = intent.getStringExtra(EXTRA_COURSE_NAME) ?: "Unknown"
        val timeRange = intent.getStringExtra(EXTRA_TIME_RANGE) ?: ""
        val location = intent.getStringExtra(EXTRA_LOCATION) ?: ""
        val minutesLeft = intent.getIntExtra(EXTRA_MINUTES_LEFT, 0)

        Log.d(TAG, "Class reminder: $courseName, $minutesLeft min left")

        // 创建通知渠道
        createNotificationChannels(context)

        // 构建通知
        showNotification(context, notificationId, courseName, timeRange, location, minutesLeft)

        // 尝试显示超级岛
        tryShowHyperIsland(context, courseName, location, minutesLeft)
    }

    /**
     * 处理超级岛提醒（用于 LiveUpdateService 触发）
     */
    private fun handleHyperIslandReminder(context: Context, intent: Intent) {
        val courseName = intent.getStringExtra(EXTRA_COURSE_NAME) ?: "Unknown"
        val location = intent.getStringExtra(EXTRA_LOCATION) ?: ""
        val minutesLeft = intent.getIntExtra(EXTRA_MINUTES_LEFT, 0)

        Log.d(TAG, "HyperIsland reminder: $courseName, $minutesLeft min left")

        tryShowHyperIsland(context, courseName, location, minutesLeft)
    }

    /**
     * 创建通知渠道
     */
    private fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(NotificationManager::class.java)

            // 课程提醒渠道 - 高优先级
            val classChannel = NotificationChannel(
                CHANNEL_ID,
                "课程提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "上课前提醒通知"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }

            // 超级岛提醒渠道
            val hyperChannel = NotificationChannel(
                CHANNEL_ID_HYPER,
                "超级岛提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "超级岛课程提醒"
                enableVibration(true)
                setShowBadge(false)
            }

            notificationManager.createNotificationChannels(listOf(classChannel, hyperChannel))
        }
    }

    /**
     * 显示课程提醒通知
     * 澎湃OS3 风格：白色/浅色背景 + 蓝色主色调
     */
    private fun showNotification(
        context: Context,
        notificationId: Int,
        courseName: String,
        timeRange: String,
        location: String,
        minutesLeft: Int
    ) {
        // 构建标题 - 澎湃OS3 风格中文
        val title = when {
            minutesLeft <= 0 -> "$courseName 开始了"
            minutesLeft >= 60 -> {
                val hours = minutesLeft / 60
                val mins = minutesLeft % 60
                if (mins > 0) "$courseName ${hours}小时${mins}分钟后"
                else "$courseName ${hours}小时后"
            }
            else -> "$courseName ${minutesLeft}分钟后"
        }

        // 构建内容
        val body = "$timeRange，准备上课"
        val locationText = if (location.isNotEmpty()) "\n$location" else ""

        // 点击意图
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 通知样式
        val bigTextStyle = NotificationCompat.BigTextStyle()
            .bigText("$body$locationText")
            .setBigContentTitle(title)
            .setSummaryText(timeRange)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(bigTextStyle)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setTimeoutAfter(30 * 60 * 1000L) // 30分钟后自动消失
            .setColor(0xFF1D9BF0.toInt()) // 澎湃OS3 经典蓝
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "我知道了",
                null
            )
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(notificationId, notification)

        Log.d(TAG, "Notification shown: $title")
    }

    /**
     * 尝试显示超级岛 - 澎湃OS风格卡片弹窗
     */
    private fun tryShowHyperIsland(
        context: Context,
        courseName: String,
        location: String,
        minutesLeft: Int,
        courseColorHex: String = "#1D9BF0"
    ) {
        try {
            // 检查是否有悬浮窗权限
            if (Settings.canDrawOverlays(context)) {
                val title = when {
                    minutesLeft <= 0 -> "$courseName 开始了"
                    else -> "$courseName ${minutesLeft}分钟后"
                }
                val body = if (location.isNotEmpty()) "$location · 准备上课" else "准备上课"

                // 直接使用 HyperIslandService.show 方法 - 澎湃OS风格卡片弹窗
                HyperIslandService.show(
                    context, 
                    title, 
                    body, 
                    durationSeconds = 10,
                    courseColorHex = courseColorHex
                )

                Log.d(TAG, "HyperIsland shown: $title")
            } else {
                Log.d(TAG, "No overlay permission")
            }
        } catch (e: Exception) {
            Log.e(TAG, "HyperIsland failed", e)
        }
    }
}

/**
 * 课程闹钟调度器
 * 负责计算和设置所有课程的精确提醒闹钟
 */
object ClassReminderScheduler {

    private const val TAG = "ClassReminderScheduler"

    /**
     * 课程提醒数据结构
     */
    data class ClassReminder(
        val notificationId: Int,
        val courseName: String,
        val timeRange: String,
        val location: String,
        val weekday: Int, // 1-7 (周一到周日)
        val startHour: Int,
        val startMinute: Int,
        val advanceMinutes: Int // 提前提醒分钟数
    )

    /**
     * 调度所有课程提醒
     * @param context 上下文
     * @param reminders 课程提醒列表
     */
    fun scheduleAll(context: Context, reminders: List<ClassReminder>) {
        // 先取消所有现有闹钟
        cancelAll(context)

        val now = Calendar.getInstance()
        val currentWeekday = now.get(Calendar.DAY_OF_WEEK)
        val currentHour = now.get(Calendar.HOUR_OF_DAY)
        val currentMinute = now.get(Calendar.MINUTE)
        val currentTotalMinutes = currentHour * 60 + currentMinute

        for (reminder in reminders) {
            val targetTotalMinutes = reminder.startHour * 60 + reminder.startMinute - reminder.advanceMinutes
            val targetWeekday = reminder.weekday

            // 计算下次触发时间
            val calendar = Calendar.getInstance().apply {
                set(Calendar.DAY_OF_WEEK, targetWeekday)
                set(Calendar.HOUR_OF_DAY, reminder.startHour)
                set(Calendar.MINUTE, reminder.startMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.MINUTE, -reminder.advanceMinutes)
            }

            // 如果时间已过，跳到下周
            if (calendar.timeInMillis <= now.timeInMillis) {
                calendar.add(Calendar.WEEK_OF_YEAR, 1)
            }

            // 计算剩余分钟数
            val triggerTotalMinutes = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
            val minutesLeft = if (targetTotalMinutes >= 0) {
                targetTotalMinutes
            } else {
                targetTotalMinutes + 24 * 60
            }

            // 设置闹钟
            ClassReminderReceiver.setExactAlarm(
                context,
                calendar.timeInMillis,
                reminder.notificationId,
                reminder.courseName,
                reminder.timeRange,
                reminder.location,
                reminder.advanceMinutes
            )

            Log.d(TAG, "Alarm set: ${reminder.courseName} " +
                    "Weekday ${reminder.weekday} ${calendar.get(Calendar.HOUR_OF_DAY)}:${String.format("%02d", calendar.get(Calendar.MINUTE))} " +
                    "(advance ${reminder.advanceMinutes}min)")
        }
    }

    /**
     * 取消所有课程提醒闹钟
     */
    fun cancelAll(context: Context) {
        // 取消 ID 范围 100-199 的所有闹钟
        for (id in 100..199) {
            ClassReminderReceiver.cancelExactAlarm(context, id)
        }
        Log.d(TAG, "All alarms cancelled")
    }

    /**
     * 从课程数据 JSON 解析并调度提醒
     * @param context 上下文
     * @param coursesJson 课程数据 JSON
     * @param advanceMinutes 提前提醒分钟数
     */
    fun scheduleFromJson(
        context: Context,
        coursesJson: String,
        advanceMinutes: Int
    ) {
        try {
            val json = JSONObject(coursesJson)
            val reminders = mutableListOf<ClassReminder>()

            // 解析每门课程
            val courses = json.optJSONArray("courses") ?: return
            for (i in 0 until courses.length()) {
                val course = courses.getJSONObject(i)
                val weekday = course.optInt("weekday", 0)
                val periodIndex = course.optInt("periodIndex", 0)
                val courseName = course.optString("courseName", "未知课程")
                val location = course.optString("classroom", "")
                val startTime = course.optString("startTime", "")
                val endTime = course.optString("endTime", "")

                if (weekday == 0 || periodIndex == 0) continue

                // 解析时间
                val timeParts = startTime.split(":")
                if (timeParts.size < 2) continue
                val startHour = timeParts[0].toIntOrNull() ?: continue
                val startMinute = timeParts[1].toIntOrNull() ?: 0

                val notificationId = 100 + weekday * 10 + periodIndex
                val timeRange = "$startTime-$endTime"

                reminders.add(
                    ClassReminder(
                        notificationId = notificationId,
                        courseName = courseName,
                        timeRange = timeRange,
                        location = location,
                        weekday = weekday,
                        startHour = startHour,
                        startMinute = startMinute,
                        advanceMinutes = advanceMinutes
                    )
                )
            }

            // 调度所有提醒
            scheduleAll(context, reminders)

        } catch (e: Exception) {
            Log.e(TAG, "解析课程数据失败", e)
        }
    }
}
