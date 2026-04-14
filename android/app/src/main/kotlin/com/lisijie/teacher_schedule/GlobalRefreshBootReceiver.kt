package com.lisijie.teacher_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 全局刷新开机自启接收器
 */
class GlobalRefreshBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GlobalRefreshBootReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return

        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {

            Log.d(TAG, "开机/更新启动，重新调度全局刷新")

            // 延迟 30 秒启动（等待系统稳定）
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                GlobalRefreshManager.start(context)
            }, 30000)
        }
    }
}
