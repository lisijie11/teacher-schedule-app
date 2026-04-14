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
    private val ROUTE_CHANNEL = "com.lisijie.teacher_schedule/widget_route"
    private val LOCATION_CHANNEL = "com.lisijie.teacher_schedule/location"
    private val SETTINGS_CHANNEL = "com.lisijie.teacher_schedule/app_settings"

    // 存储来自 widget 点击的路由（解决 Activity 复用时 Intent 不更新的问题）
    private var pendingRoute: String = ""

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Activity 被 widget 拉起时，onNewIntent 才是真正的最新 Intent
        this.intent = intent
        val route = intent.getStringExtra("route") ?: ""
        if (route.isNotEmpty()) {
            pendingRoute = route
            android.util.Log.d("WidgetRoute", "onNewIntent 捕获路由: $route")
        }
    }

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

        // ===== 小组件路由 Channel =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROUTE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRoute" -> {
                    // 优先读 onNewIntent 捕获的路由，其次读原始 Intent
                    val route = pendingRoute.ifEmpty { intent.getStringExtra("route") ?: "" }
                    android.util.Log.d("WidgetRoute", "getRoute 返回: '$route' (pending=$pendingRoute)")
                    result.success(route)
                    // 清除已消费的路由
                    pendingRoute = ""
                }
                else -> result.notImplemented()
            }
        }

        // ===== 网络定位 Channel =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNetworkLocation" -> {
                    NetworkLocationService.getNetworkLocation(this) { lat, lng ->
                        if (lat != null && lng != null) {
                            result.success(mapOf("latitude" to lat, "longitude" to lng))
                        } else {
                            result.error("LOCATION_FAILED", "网络定位失败", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ===== 应用设置 Channel =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ===== 小组件数据同步 Channel =====
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
                // ========== 全局刷新回调 ==========
                "onWidgetRefreshRequested" -> {
                    // Kotlin 端请求 Flutter 端刷新小组件数据
                    // 通过 EventChannel 通知 Flutter
                    android.util.Log.d("WidgetData", "收到小组件刷新请求")
                    result.success(true)
                }
                // ========== 全局刷新控制 ==========
                "startGlobalRefresh" -> {
                    GlobalRefreshManager.start(this)
                    android.util.Log.d("WidgetData", "全局刷新已启动")
                    result.success(true)
                }
                "stopGlobalRefresh" -> {
                    GlobalRefreshManager.stop(this)
                    android.util.Log.d("WidgetData", "全局刷新已停止")
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
        // 应用回到前台时，启动全局刷新管理器
        GlobalRefreshManager.start(this)
    }
}
