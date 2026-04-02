package com.lisijie.teacher_schedule

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.teacher_schedule/hyper_island"
    private val SCHEDULE_DATA_CHANNEL = "com.lisijie.teacher_schedule/schedule_data"
    private val WIDGET_DATA_CHANNEL = "com.lisijie.teacher_schedule/widget_data"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== 课程表数据同步 Channel =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCHEDULE_DATA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveScheduleData" -> {
                    val json = call.argument<String>("json") ?: ""
                    val prefs = getSharedPreferences("ScheduleData", android.content.Context.MODE_PRIVATE)
                    prefs.edit().putString("courses_json", json).apply()
                    android.util.Log.d("ScheduleData", "课程表已保存到 ScheduleData SharedPreferences，长度=${json.length}")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ===== 小组件数据同步 Channel =====
        // Flutter 直接写入 HomeWidgetPlugin SharedPreferences，确保 Kotlin 端能读取到
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_DATA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveWidgetData" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<String>("value") ?: ""
                    val prefs = getSharedPreferences("HomeWidgetPlugin", android.content.Context.MODE_PRIVATE)
                    prefs.edit().putString(key, value).apply()
                    android.util.Log.d("WidgetData", "写入 HomeWidgetPlugin: $key = $value")
                    result.success(true)
                }
                "saveWidgetInt" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<Int>("value") ?: 0
                    val prefs = getSharedPreferences("HomeWidgetPlugin", android.content.Context.MODE_PRIVATE)
                    prefs.edit().putInt(key, value).apply()
                    android.util.Log.d("WidgetData", "写入 HomeWidgetPlugin: $key = $value")
                    result.success(true)
                }
                "updateWidget" -> {
                    // 触发小组件刷新
                    val widgetName = call.argument<String>("widgetName") ?: ""
                    WidgetSupport.updateAll(this)
                    android.util.Log.d("WidgetData", "触发小组件刷新: $widgetName")
                    result.success(true)
                }
                // ========== 原生闹钟调度 ==========
                "scheduleClassReminders" -> {
                    val coursesJson = call.argument<String>("coursesJson") ?: ""
                    val advanceMinutes = call.argument<Int>("advanceMinutes") ?: 15
                    ClassReminderScheduler.scheduleFromJson(this, coursesJson, advanceMinutes)
                    result.success(true)
                }
                "cancelClassReminders" -> {
                    ClassReminderScheduler.cancelAll(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ========== 超级岛相关 ==========
                "showIsland" -> {
                    val title = call.argument<String>("title") ?: "课程提醒"
                    val body = call.argument<String>("body") ?: "准备上课"
                    val duration = call.argument<Int>("duration") ?: 10
                    
                    if (Settings.canDrawOverlays(this)) {
                        HyperIslandService.show(this, title, body, duration)
                        result.success(true)
                    } else {
                        result.error("NO_PERMISSION", "需要悬浮窗权限", null)
                    }
                }
                "hideIsland" -> {
                    HyperIslandService.hideIsland()
                    result.success(true)
                }
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }

                // ========== 保活服务相关 ==========
                "startKeepAliveService" -> {
                    // 启动前台服务
                    LiveUpdateService.start(this)
                    result.success(true)
                }
                "stopKeepAliveService" -> {
                    LiveUpdateService.stop(this)
                    result.success(true)
                }
                "isKeepAliveServiceRunning" -> {
                    val isRunning = LiveUpdateService.getInstance() != null
                    result.success(isRunning)
                }

                // ========== 无障碍服务相关 ==========
                "isAccessibilityServiceEnabled" -> {
                    val isEnabled = KeepAliveAccessibilityService.isEnabled(this)
                    result.success(isEnabled)
                }
                "openAccessibilitySettings" -> {
                    KeepAliveAccessibilityService.openSettings(this)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // 应用回到前台时，启动保活服务
        LiveUpdateService.start(this)
    }
}
