package com.lisijie.teacher_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 课程提醒开机自启接收器
 * 开机后重新调度所有课程提醒闹钟
 */
class ClassReminderBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ClassReminderBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "收到开机/更新广播，重新调度课程提醒")

                // 从 SharedPreferences 读取课程数据并重新调度
                try {
                    val prefs = context.getSharedPreferences("ClassReminderData", Context.MODE_PRIVATE)
                    val coursesJson = prefs.getString("courses_json", null)
                    val advanceMinutes = prefs.getInt("advance_minutes", 15)

                    if (!coursesJson.isNullOrEmpty()) {
                        ClassReminderScheduler.scheduleFromJson(context, coursesJson, advanceMinutes)
                        Log.d(TAG, "课程提醒已重新调度")
                    } else {
                        Log.d(TAG, "没有找到课程数据，跳过调度")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "重新调度失败", e)
                }

                // 同时启动 LiveUpdateService
                LiveUpdateService.start(context)
            }
        }
    }
}
