package com.lisijie.teacher_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * 服务重启广播接收器
 * 用于在服务被杀死或开机时自动重启服务
 */
class ServiceRestartReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ServiceRestartReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "开机完成，启动保活服务")
                startServices(context)
            }
            "com.lisijie.teacher_schedule.RESTART_LIVE_UPDATE" -> {
                Log.d(TAG, "收到LiveUpdate服务重启广播")
                LiveUpdateService.start(context)
            }
            "com.lisijie.teacher_schedule.RESTART_KEEP_ALIVE" -> {
                Log.d(TAG, "收到保活服务重启广播")
                // 无障碍服务无法通过代码启动，需要用户手动开启
                // 但可以启动前台服务
                LiveUpdateService.start(context)
            }
            "com.lisijie.teacher_schedule.KEEP_ALIVE_STARTED" -> {
                Log.d(TAG, "无障碍服务已启动")
            }
        }
    }

    /**
     * 启动所有保活服务
     */
    private fun startServices(context: Context) {
        // 启动前台服务
        LiveUpdateService.start(context)

        // 检查无障碍服务是否已启用
        if (!KeepAliveAccessibilityService.isEnabled(context)) {
            Log.d(TAG, "无障碍服务未启用，建议用户开启")
            // 这里可以发送通知提醒用户开启无障碍服务
        }
    }
}
