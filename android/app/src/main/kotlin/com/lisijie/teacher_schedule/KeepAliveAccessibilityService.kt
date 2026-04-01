package com.lisijie.teacher_schedule

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.os.Handler
import android.os.Looper

/**
 * 保活无障碍服务
 * 参考 mikcb 项目实现：
 * - 利用无障碍服务的高优先级特性保持应用存活
 * - 系统很少会杀死无障碍服务
 * - 结合前台服务实现双重保活
 * - 监听屏幕状态变化，及时恢复服务
 */
class KeepAliveAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "KeepAliveService"
        private var instance: KeepAliveAccessibilityService? = null
        private val handler = Handler(Looper.getMainLooper())

        fun getInstance(): KeepAliveAccessibilityService? = instance

        /**
         * 检查无障碍服务是否已启用
         */
        fun isEnabled(context: android.content.Context): Boolean {
            val enabledServices = android.provider.Settings.Secure.getString(
                context.contentResolver,
                android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val serviceName = "${context.packageName}/${KeepAliveAccessibilityService::class.java.canonicalName}"
            return enabledServices.contains(serviceName) || enabledServices.contains(context.packageName)
        }

        /**
         * 打开无障碍服务设置页面
         */
        fun openSettings(context: android.content.Context) {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "无障碍服务已创建")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "无障碍服务已连接")

        // 启动前台保活服务
        startKeepAliveService()

        // 发送服务启动广播
        sendBroadcast(Intent("com.lisijie.teacher_schedule.KEEP_ALIVE_STARTED"))
        
        // 延迟检查服务状态
        handler.postDelayed({
            checkAndRestartServices()
        }, 5000)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 监听关键系统事件来触发服务检查
        event?.let {
            when (it.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    // 窗口切换时检查服务状态
                    checkAndRestartServices()
                }
                AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                    // 通知变化时检查
                    checkAndRestartServices()
                }
                else -> {}
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "无障碍服务被中断")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        Log.d(TAG, "无障碍服务解绑")
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "无障碍服务已销毁")

        // 尝试重启服务
        sendBroadcast(Intent("com.lisijie.teacher_schedule.RESTART_KEEP_ALIVE"))
    }

    /**
     * 启动前台保活服务
     */
    private fun startKeepAliveService() {
        val serviceIntent = Intent(this, LiveUpdateService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        Log.d(TAG, "已启动 LiveUpdateService")
    }

    /**
     * 检查并重启服务
     */
    private fun checkAndRestartServices() {
        // 检查 LiveUpdateService 是否运行
        if (!isServiceRunning(LiveUpdateService::class.java)) {
            Log.d(TAG, "LiveUpdateService 未运行，尝试重启")
            startKeepAliveService()
        }
    }

    /**
     * 检查服务是否正在运行
     */
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
