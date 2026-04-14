package com.lisijie.teacher_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
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
     * 执行刷新
     */
    private fun performRefresh(context: Context) {
        // 1. 计算当前课程状态
        val scheduleData = calculateCurrentSchedule(context)

        // 2. 更新 HomeWidgetPlugin SharedPreferences
        updateWidgetData(context, scheduleData)

        // 3. 触发小组件刷新
        triggerWidgetUpdate(context)

        // 4. 触发通知刷新
        triggerNotificationUpdate(context)

        Log.d(TAG, "刷新完成: ${scheduleData["state"]}")
    }

    /**
     * 计算当前课程状态
     */
    private fun calculateCurrentSchedule(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences("ScheduleData", Context.MODE_PRIVATE)
        val coursesJson = prefs.getString("courses_json", null)

        val now = Calendar.getInstance()
        val todayWeekday = now.get(Calendar.DAY_OF_WEEK)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

        // 转换星期（Calendar: 1=周日, 2=周一... -> 我们用: 1=周一, 2=周二... 7=周日）
        val weekday = if (todayWeekday == Calendar.SUNDAY) 7 else todayWeekday - 1

        var state = "no_course"
        var progress = 0
        var currentCourseName = ""
        var currentCourseLocation = ""
        var currentTimeRange = ""
        var nextCourseName = ""
        var nextCourseTime = ""
        var remainingMinutes = 0

        if (coursesJson != null) {
            try {
                val json = org.json.JSONObject(coursesJson)
                val periods = json.optJSONArray("periods")
                val courses = json.optJSONArray("courses")

                if (periods != null) {
                    var foundCurrent = false
                    var findNext = false

                    for (i in 0 until periods.length()) {
                        val period = periods.getJSONObject(i)
                        val periodIndex = period.getInt("index")
                        val startHour = period.getInt("sh")
                        val startMinute = period.getInt("sm")
                        val endHour = period.getInt("eh")
                        val endMinute = period.getInt("em")
                        val startTime = period.getString("startTime")
                        val endTime = period.getString("endTime")

                        val startMin = startHour * 60 + startMinute
                        val endMin = endHour * 60 + endMinute

                        // 查找当前课程
                        if (!foundCurrent && currentMinutes >= startMin && currentMinutes < endMin) {
                            val course = findCourseByPeriod(courses, weekday, periodIndex)
                            if (course != null) {
                                state = "ongoing"
                                currentCourseName = course.optString("courseName", "")
                                currentCourseLocation = course.optString("classroom", "")
                                currentTimeRange = "$startTime-$endTime"
                                progress = if (endMin > startMin) {
                                    ((currentMinutes - startMin) * 100) / (endMin - startMin)
                                } else 0
                                remainingMinutes = endMin - currentMinutes
                                foundCurrent = true
                            }
                        }

                        // 查找下一节课
                        if (!findNext && !foundCurrent && currentMinutes < startMin) {
                            val course = findCourseByPeriod(courses, weekday, periodIndex)
                            if (course != null) {
                                state = "upcoming"
                                nextCourseName = course.optString("courseName", "")
                                nextCourseTime = startTime
                                remainingMinutes = startMin - currentMinutes
                                findNext = true
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "解析课程数据失败", e)
            }
        }

        // 如果已过所有课程
        if (state == "no_course" && remainingMinutes == 0 && currentMinutes > 0) {
            state = "completed"
        }

        return mapOf(
            "state" to state,
            "progress" to progress,
            "currentCourseName" to currentCourseName,
            "currentCourseLocation" to currentCourseLocation,
            "currentTimeRange" to currentTimeRange,
            "nextCourseName" to nextCourseName,
            "nextCourseTime" to nextCourseTime,
            "remainingMinutes" to remainingMinutes
        )
    }

    /**
     * 根据节次查找课程
     */
    private fun findCourseByPeriod(courses: org.json.JSONArray?, weekday: Int, periodIndex: Int): org.json.JSONObject? {
        if (courses == null) return null

        for (i in 0 until courses.length()) {
            val course = courses.getJSONObject(i)
            if (course.getInt("weekday") == weekday && course.getInt("periodIndex") == periodIndex) {
                return course
            }
        }
        return null
    }

    /**
     * 更新小组件数据
     */
    private fun updateWidgetData(context: Context, data: Map<String, Any>) {
        val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
        val editor = prefs.edit()

        // 写入当前课程信息
        editor.putString("course_name", data["currentCourseName"] as String)
        editor.putString("location", data["currentCourseLocation"] as String)
        editor.putString("time_range", data["currentTimeRange"] as String)
        editor.putInt("progress", data["progress"] as Int)

        // 写入下一节课信息
        editor.putString("course_2_name", data["nextCourseName"] as String)
        editor.putString("course_2_time", data["nextCourseTime"] as String)

        // 写入状态
        editor.putString("state", data["state"] as String)
        editor.putInt("remaining_minutes", data["remainingMinutes"] as Int)

        // 写入更新时间戳
        editor.putLong("last_update_time", System.currentTimeMillis())

        editor.apply()
        Log.d(TAG, "小组件数据已更新: state=${data["state"]}, progress=${data["progress"]}%")
    }

    /**
     * 触发小组件刷新
     */
    private fun triggerWidgetUpdate(context: Context) {
        try {
            WidgetSupport.updateAll(context)
            Log.d(TAG, "小组件刷新已触发")
        } catch (e: Exception) {
            Log.e(TAG, "触发小组件刷新失败", e)
        }
    }

    /**
     * 触发通知刷新 - 通知 LiveUpdateService 刷新
     */
    private fun triggerNotificationUpdate(context: Context) {
        try {
            // 通知 LiveUpdateService 刷新（如果有实例）
            LiveUpdateService.getInstance()?.updateNotification()
            Log.d(TAG, "通知刷新已触发")
        } catch (e: Exception) {
            Log.e(TAG, "触发通知刷新失败", e)
        }
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
