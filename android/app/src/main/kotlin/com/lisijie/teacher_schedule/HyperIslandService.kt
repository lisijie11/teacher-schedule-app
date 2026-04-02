package com.lisijie.teacher_schedule

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * 超级岛服务 - 澎湃 OS 3 风格卡片弹窗
 * 
 * 澎湃OS3 设计风格：
 * - 纯净浅色背景 + 微妙渐变
 * - 圆角卡片设计 (28dp)
 * - 左右两侧彩色竖条（左侧状态条 + 右侧进度条）
 * - 实时倒计时动画
 * - 平滑出现/消失动画
 */
class HyperIslandService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var cardView: LinearLayout? = null
    private var progressBar: ProgressBar? = null
    private var timeTextView: TextView? = null
    private var progressTextView: TextView? = null
    private var isShowing = false
    private val handler = Handler(Looper.getMainLooper())
    private var hideRunnable: Runnable? = null
    private var countdownRunnable: Runnable? = null
    private var totalSeconds = 10
    private var courseColor = Color.parseColor("#1D9BF0") // 默认蓝色
    
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
         * @param courseColorHex 课程颜色（如 "#FF5722"）
         */
        fun show(context: Context, title: String, body: String, durationSeconds: Int = 10, 
                 mode: String = MODE_FLOATING, courseColorHex: String = "#1D9BF0") {
            val intent = Intent(context, HyperIslandService::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
                putExtra("duration", durationSeconds)
                putExtra("mode", mode)
                putExtra("courseColor", courseColorHex)
                action = "show_island"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun hide() {
            instance?.hideHyperIslandPublic()
        }
        
        fun hideIsland() {
            instance?.hideHyperIsland()
        }
        
        fun hasOverlayPermission(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.provider.Settings.canDrawOverlays(context)
            } else {
                true
            }
        }
        
        fun requestOverlayPermission(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:${context.packageName}")
                )
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            }
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "show_island" -> {
                val title = intent.getStringExtra("title") ?: "课程提醒"
                val body = intent.getStringExtra("body") ?: ""
                val duration = intent.getIntExtra("duration", 10)
                val mode = intent.getStringExtra("mode") ?: MODE_FLOATING
                val colorHex = intent.getStringExtra("courseColor") ?: "#1D9BF0"
                
                totalSeconds = duration
                courseColor = try {
                    Color.parseColor(colorHex)
                } catch (e: Exception) {
                    Color.parseColor("#1D9BF0")
                }
                
                showHyperIsland(title, body, duration * 1000L, mode)
            }
            "hide_island" -> hideHyperIsland()
        }
        return START_NOT_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        hideHyperIsland()
        instance = null
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "超级岛服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "用于显示澎湃OS风格超级岛"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("课表助手")
            .setContentText("超级岛服务运行中")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        
        startForeground(NOTIFICATION_ID, notification)
    }
    
    private fun showHyperIsland(title: String, body: String, durationMs: Long, mode: String) {
        // 隐藏已存在的弹窗
        hideHyperIsland()
        
        isShowing = true
        
        // 创建悬浮窗视图
        val (container, card, progress, timeText, progressText) = createHyperIslandCard(title, body)
        floatingView = container
        cardView = card
        progressBar = progress
        timeTextView = timeText
        progressTextView = progressText
        
        val params = WindowManager.LayoutParams().apply {
            width = dpToPx(320)
            height = WindowManager.LayoutParams.WRAP_CONTENT
            format = PixelFormat.TRANSLUCENT
            
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            x = 0
            y = dpToPx(24)
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        }
        
        try {
            windowManager?.addView(floatingView, params)
            
            // 胶囊出现动画
            card.alpha = 0f
            card.scaleX = 0.8f
            card.scaleY = 0.8f
            card.translationY = -dpToPx(20).toFloat()
            
            card.animate()
                .alpha(1f)
                .scaleX(1f)
                .scaleY(1f)
                .translationY(0f)
                .setDuration(350)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .start()
                
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
        handler.postDelayed(hideRunnable!!, durationMs.toLong())
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
                    updateProgress(0, 0, 0)
                    return
                }
                
                val remainingSec = (remaining / 1000).toInt() + 1
                val progressPercent = ((remaining * 100) / totalDuration).toInt()
                val elapsedPercent = 100 - progressPercent
                
                updateProgress(progressPercent, remainingSec, elapsedPercent)
                handler.postDelayed(this, 50)
            }
        }
        handler.post(countdownRunnable!!)
    }
    
    private fun updateProgress(progress: Int, remainingSec: Int, elapsedPercent: Int) {
        progressBar?.progress = progress
        timeTextView?.text = "${remainingSec}s"
        progressTextView?.text = "$elapsedPercent%"
    }
    
    private fun hideHyperIsland() {
        isShowing = false
        countdownRunnable?.let { handler.removeCallbacks(it) }
        hideRunnable?.let { handler.removeCallbacks(it) }
        
        try {
            floatingView?.let {
                windowManager?.removeView(it)
            }
        } catch (e: Exception) {
            // 视图可能已移除
        }
        
        floatingView = null
        cardView = null
        progressBar = null
        timeTextView = null
        progressTextView = null
    }
    
    fun hideHyperIslandPublic() {
        hideHyperIsland()
    }
    
    private fun hideHyperIslandWithAnimation() {
        cardView?.animate()
            ?.alpha(0f)
            ?.scaleX(0.8f)
            ?.scaleY(0.8f)
            ?.translationY(-dpToPx(20).toFloat())
            ?.setDuration(300)
            ?.setInterpolator(AccelerateDecelerateInterpolator())
            ?.withEndAction {
                hideHyperIsland()
            }
            ?.start()
    }
    
    /**
     * 创建超级岛卡片视图
     * 布局：左侧状态条 + 中间内容 + 右侧进度条
     */
    private fun createHyperIslandCard(title: String, body: String): 
            Quintuple<View, LinearLayout, ProgressBar, TextView, TextView> {
        
        // 外层容器
        val container = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        
        // 主卡片
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                dpToPx(320),
                WindowManager.LayoutParams.WRAP_CONTENT
            )
            background = createCardBackground()
            elevation = dpToPx(16).toFloat()
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12))
        }
        
        // 内容区域：水平排列
        val contentLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(320),
                dpToPx(60)
            )
            gravity = Gravity.CENTER_VERTICAL
        }
        
        // 左侧竖条 - 彩色状态条
        val leftBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(4),
                dpToPx(48)
            )
            gravity = Gravity.CENTER
            background = createColorBarDrawable()
        }
        
        // 中间内容
        val middleContent = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(56), 1f)
            gravity = Gravity.CENTER_VERTICAL
            setPaddingRelative(dpToPx(12), 0, dpToPx(12), 0)
        }
        
        // 图标
        val iconView = TextView(this).apply {
            text = "📚"
            textSize = 28f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(48),
                dpToPx(48)
            )
        }
        
        // 文字区域
        val textContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(56), 1f)
            gravity = Gravity.CENTER_VERTICAL
            setPaddingRelative(dpToPx(10), 0, dpToPx(8), 0)
        }
        
        // 课程名称
        val titleView = TextView(this).apply {
            text = title
            textSize = 16f
            setTextColor(Color.parseColor("#1A1A1A"))
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        
        // 地点
        val bodyView = TextView(this).apply {
            text = body
            textSize = 13f
            setTextColor(Color.parseColor("#666666"))
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dpToPx(2)
            }
        }
        
        textContainer.addView(titleView)
        textContainer.addView(bodyView)
        
        // 倒计时和百分比
        val timerContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(48),
                dpToPx(48)
            )
            gravity = Gravity.CENTER
        }
        
        val timeText = TextView(this).apply {
            text = "${totalSeconds}s"
            textSize = 18f
            setTextColor(courseColor)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        
        val progressText = TextView(this).apply {
            text = "100%"
            textSize = 11f
            setTextColor(Color.parseColor("#999999"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dpToPx(2)
            }
        }
        
        timerContainer.addView(timeText)
        timerContainer.addView(progressText)
        
        // 右侧竖条 - 进度条
        val rightBar = ProgressBar(
            this, null,
            android.R.attr.progressBarStyleHorizontal
        ).apply {
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(4),
                dpToPx(48)
            )
            max = 100
            progress = 100
            progressDrawable = createProgressDrawable()
        }
        
        // 组装
        middleContent.addView(iconView)
        middleContent.addView(textContainer)
        middleContent.addView(timerContainer)
        
        contentLayout.addView(leftBar)
        contentLayout.addView(middleContent)
        contentLayout.addView(rightBar)
        
        card.addView(contentLayout)
        container.addView(card)
        
        return Quintuple(container, card, rightBar, timeText, progressText)
    }
    
    private fun createCardBackground(): android.graphics.drawable.Drawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(24).toFloat()
            colors = intArrayOf(
                Color.WHITE,
                Color.parseColor("#F8F9FA")
            )
            orientation = android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM
        }
    }
    
    private fun createColorBarDrawable(): android.graphics.drawable.Drawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(2).toFloat()
            colors = intArrayOf(
                courseColor,
                Color.argb(180,
                    Color.red(courseColor),
                    Color.green(courseColor),
                    Color.blue(courseColor)
                )
            )
            orientation = android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM
        }
    }
    
    private fun createProgressDrawable(): android.graphics.drawable.Drawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(2).toFloat()
            colors = intArrayOf(
                Color.parseColor("#E8E8E8"),
                courseColor
            )
            orientation = android.graphics.drawable.GradientDrawable.Orientation.LEFT_RIGHT
        }
    }
    
    private fun dpToPx(dp: Int): Int {
        val density = resources.displayMetrics.density
        return (dp * density).toInt()
    }
    
    // Kotlin 数据类
    private data class Quintuple<A, B, C, D, E>(
        val first: A,
        val second: B,
        val third: C,
        val fourth: D,
        val fifth: E
    )
}
