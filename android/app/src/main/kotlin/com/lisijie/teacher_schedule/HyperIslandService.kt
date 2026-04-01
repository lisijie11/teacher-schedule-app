package com.lisijie.teacher_schedule

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * 超级岛服务 - 支持两种模式：
 * 1. 悬浮窗模式（兼容所有设备）
 * 2. MIUI/HyperOS 官方灵眸岛模式（仅支持 HyperOS 3+）
 * 
 * 参考 mikcb 项目实现，使用 miui.focus.param 参数
 */
class HyperIslandService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var cardView: LinearLayout? = null
    private var progressBar: ProgressBar? = null
    private var timeTextView: TextView? = null
    private var isShowing = false
    private val handler = Handler(Looper.getMainLooper())
    private var hideRunnable: Runnable? = null
    private var countdownRunnable: Runnable? = null
    private var remainingSeconds = 10
    private var totalSeconds = 10
    
    companion object {
        private const val TAG = "HyperIslandService"
        private const val NOTIFICATION_ID = 9999
        private const val CHANNEL_ID = "hyperos_island"
        private const val MODE_FLOATING = "floating"
        private const val MODE_MIUI = "miui"
        private var instance: HyperIslandService? = null
        
        fun getInstance(): HyperIslandService? = instance
        
        /**
         * 显示超级岛
         * @param mode 显示模式：floating(悬浮窗) 或 miui(MIUI官方)
         */
        fun show(context: Context, title: String, body: String, durationSeconds: Int = 10, mode: String = MODE_FLOATING) {
            val intent = Intent(context, HyperIslandService::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
                putExtra("duration", durationSeconds)
                putExtra("mode", mode)
                action = "show_island"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun hide() {
            instance?.hideHyperIsland()
        }
        
        /**
         * 检查是否有悬浮窗权限
         */
        fun hasOverlayPermission(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.provider.Settings.canDrawOverlays(context)
            } else {
                true
            }
        }
        
        /**
         * 请求悬浮窗权限
         */
        fun requestOverlayPermission(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:${context.packageName}")
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            }
        }
        
        /**
         * 检查是否为 MIUI/HyperOS 系统
         */
        fun isMIUI(): Boolean {
            return !android.os.Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true).not() ||
                   android.os.Build.DISPLAY.contains("MIUI") ||
                   android.os.Build.DISPLAY.contains("HyperOS")
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "系统通知",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "系统服务"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "show_island" -> {
                val title = intent.getStringExtra("title") ?: "课程提醒"
                val body = intent.getStringExtra("body") ?: "准备上课"
                totalSeconds = intent.getIntExtra("duration", 10)
                val mode = intent.getStringExtra("mode") ?: MODE_FLOATING
                remainingSeconds = totalSeconds
                
                if (mode == MODE_MIUI && isMIUI()) {
                    showMIUIIsland(title, body, totalSeconds * 1000L)
                } else {
                    showFloatingIsland(title, body, totalSeconds * 1000L)
                }
            }
            "hide_island" -> {
                hideHyperIsland()
            }
        }
        return START_STICKY
    }
    
    /**
     * MIUI/HyperOS 官方灵眸岛实现
     * 使用 miui.focus.param 参数
     */
    private fun showMIUIIsland(title: String, body: String, durationMs: Long) {
        // 创建 MIUI 灵眸岛通知
        val notification = createMIUINotification(title, body)
        
        // 显示为前台服务通知
        startForeground(NOTIFICATION_ID, notification)
        
        isShowing = true
        
        // 自动关闭
        hideRunnable?.let { handler.removeCallbacks(it) }
        hideRunnable = Runnable {
            hideHyperIsland()
        }
        handler.postDelayed(hideRunnable!!, durationMs)
    }
    
    /**
     * 创建 MIUI 灵眸岛通知
     * 参考 mikcb 实现，使用 miui.focus.param 参数
     */
    private fun createMIUINotification(title: String, body: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // MIUI 灵眸岛参数
        val miuiExtras = Bundle().apply {
            // 标签样式：text_only 只显示文字
            putString("miui.focus.param", "text_only")
            
            // 标签内容
            putString("miuiIslandLabelContent", title)
            
            // 标签字体颜色
            putInt("miuiIslandLabelFontColor", Color.WHITE)
            
            // 标签字体大小
            putInt("miuiIslandLabelFontSize", 14)
            
            // 标签偏移量
            putInt("miuiIslandLabelOffsetX", 0)
            putInt("miuiIslandLabelOffsetY", 0)
            
            // 扩展图标模式
            putString("miuiIslandExpandedIconMode", "app_icon")
            
            // 扩展图标路径（可选）
            // putString("miuiIslandExpandedIconPath", "")
            
            // 背景颜色
            putInt("miuiIslandBackgroundColor", Color.argb(240, 20, 20, 20))
            
            // 显示时长
            putLong("miuiIslandDuration", totalSeconds * 1000L)
        }
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .addExtras(miuiExtras)
            .build()
    }
    
    /**
     * 悬浮窗模式（兼容所有设备）
     */
    private fun showFloatingIsland(title: String, body: String, durationMs: Long) {
        if (isShowing) {
            hideHyperIsland()
        }
        
        isShowing = true
        remainingSeconds = totalSeconds
        
        // 创建悬浮窗视图
        val (container, card, progress, timeText) = createIslandView(title, body)
        floatingView = container
        cardView = card
        progressBar = progress
        timeTextView = timeText
        
        val params = WindowManager.LayoutParams().apply {
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            
            format = PixelFormat.TRANSLUCENT
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            
            // 胶囊宽度，居中显示
            width = dpToPx(380)
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = 0
            y = dpToPx(28) // 状态栏下方
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        }
        
        try {
            windowManager?.addView(floatingView, params)
            // 淡入动画
            cardView?.alpha = 0f
            cardView?.scaleX = 0.9f
            cardView?.scaleY = 0.9f
            cardView?.animate()
                ?.alpha(1f)
                ?.scaleX(1f)
                ?.scaleY(1f)
                ?.setDuration(250)
                ?.setInterpolator(android.view.animation.DecelerateInterpolator())
                ?.start()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        // 启动实时倒计时
        startRealtimeCountdown()
        
        // 自动关闭
        hideRunnable?.let { handler.removeCallbacks(it) }
        hideRunnable = Runnable {
            hideHyperIslandWithAnimation()
        }
        handler.postDelayed(hideRunnable!!, durationMs)
    }
    
    private fun startRealtimeCountdown() {
        countdownRunnable?.let { handler.removeCallbacks(it) }
        
        val startTime = System.currentTimeMillis()
        val totalDuration = totalSeconds * 1000L
        
        countdownRunnable = object : Runnable {
            override fun run() {
                if (!isShowing) return
                
                val elapsed = System.currentTimeMillis() - startTime
                val remaining = totalDuration - elapsed
                
                if (remaining <= 0) {
                    updateProgress(0, 0)
                    return
                }
                
                val remainingSec = (remaining / 1000).toInt() + 1
                val progress = ((remaining * 100) / totalDuration).toInt()
                
                updateProgress(progress, remainingSec)
                
                // 每100ms更新一次，实现平滑动画
                handler.postDelayed(this, 100)
            }
        }
        handler.post(countdownRunnable!!)
    }
    
    private fun updateProgress(progress: Int, remainingSec: Int) {
        progressBar?.progress = progress
        timeTextView?.text = if (remainingSec > 0) "${remainingSec}s" else ""
    }
    
    private fun createIslandView(title: String, body: String): Quadruple<View, LinearLayout, ProgressBar, TextView> {
        val container = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setBackgroundColor(Color.TRANSPARENT)
        }
        
        // 超级岛卡片 - 胶囊形状
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                dpToPx(380),
                dpToPx(64)
            ).apply {
                topMargin = dpToPx(12)
            }
            
            // 胶囊背景 - 纯黑带轻微透明，模仿系统通知
            background = createCapsuleBackground()
            elevation = dpToPx(4).toFloat()
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(12), 0, dpToPx(12), 0)
        }
        
        // 左侧：应用图标（伪装成系统应用）
        val iconView = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(40), dpToPx(40)).apply {
                marginEnd = dpToPx(10)
            }
            // 使用系统风格的图标
            setImageResource(android.R.drawable.ic_dialog_info)
            setColorFilter(Color.parseColor("#1D9BF0"))
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            // 圆形背景
            background = createIconBackground()
        }
        
        // 中间：内容区域
        val contentContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            gravity = Gravity.CENTER_VERTICAL
        }
        
        // 标题 - 系统通知样式
        val titleView = TextView(this).apply {
            text = title
            textSize = 14f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            maxLines = 1
        }
        
        // 副标题
        val subtitleView = TextView(this).apply {
            text = body
            textSize = 12f
            setTextColor(Color.parseColor("#AAAAAA"))
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dpToPx(1)
            }
        }
        
        contentContainer.addView(titleView)
        contentContainer.addView(subtitleView)
        
        // 右侧：倒计时 + 进度
        val rightContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(50),
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = dpToPx(8)
            }
            gravity = Gravity.CENTER
        }
        
        // 倒计时文字
        val timeText = TextView(this).apply {
            text = "${totalSeconds}s"
            textSize = 11f
            setTextColor(Color.parseColor("#1D9BF0"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        
        // 迷你进度条
        val progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(40),
                dpToPx(2)
            ).apply {
                topMargin = dpToPx(4)
            }
            max = 100
            progress = 100
            progressDrawable = createMiniProgressDrawable()
        }
        
        rightContainer.addView(timeText)
        rightContainer.addView(progress)
        
        // 组装
        card.addView(iconView)
        card.addView(contentContainer)
        card.addView(rightContainer)
        
        container.addView(card)
        return Quadruple(container, card, progress, timeText)
    }
    
    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
    
    /**
     * 创建胶囊形状背景 - 模仿系统通知样式
     */
    private fun createCapsuleBackground(): android.graphics.drawable.Drawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            // 大圆角，形成胶囊形状
            cornerRadius = dpToPx(32).toFloat()
            // 纯黑背景，带轻微透明
            setColor(Color.argb(245, 20, 20, 20))
            // 细微边框
            setStroke(dpToPx(1), Color.argb(30, 255, 255, 255))
        }
    }
    
    /**
     * 创建图标背景 - 圆形
     */
    private fun createIconBackground(): android.graphics.drawable.Drawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.OVAL
            setColor(Color.argb(30, 29, 155, 240))
        }
    }
    
    /**
     * 创建迷你进度条样式
     */
    private fun createMiniProgressDrawable(): android.graphics.drawable.Drawable {
        return android.graphics.drawable.LayerDrawable(
            arrayOf(
                // 背景
                android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(1).toFloat()
                    setColor(Color.argb(30, 255, 255, 255))
                },
                // 进度
                android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(1).toFloat()
                    setColor(Color.parseColor("#1D9BF0"))
                }
            )
        ).apply {
            setId(0, android.R.id.background)
            setId(1, android.R.id.progress)
        }
    }
    
    private fun hideHyperIslandWithAnimation() {
        cardView?.animate()
            ?.alpha(0f)
            ?.scaleX(0.95f)
            ?.scaleY(0.95f)
            ?.setDuration(200)
            ?.withEndAction {
                hideHyperIsland()
            }
            ?.start()
    }
    
    fun hideHyperIsland() {
        countdownRunnable?.let { handler.removeCallbacks(it) }
        hideRunnable?.let { handler.removeCallbacks(it) }
        
        if (floatingView != null) {
            try {
                windowManager?.removeView(floatingView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            floatingView = null
            cardView = null
            progressBar = null
            timeTextView = null
        }
        isShowing = false
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("系统服务")
            .setContentText("正在运行")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        hideHyperIsland()
        instance = null
    }
    
    // 简单的四元组数据类
    data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
}
