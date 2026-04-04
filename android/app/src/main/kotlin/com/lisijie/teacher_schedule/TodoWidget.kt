package com.lisijie.teacher_schedule

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import kotlin.math.min
import kotlin.math.roundToInt

// ─── 待办事项 4×2 小部件 ──────────────────────────────────────────────────────

class TodoWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "TodoWidget"

        // 优先级颜色（普通/重要/紧急）
        private val PRIORITY_COLORS = intArrayOf(
            Color.parseColor("#94A3B8"), // 0=普通 灰蓝
            Color.parseColor("#F59E0B"), // 1=重要 橙色
            Color.parseColor("#EF4444"), // 2=紧急 红色
        )

        fun updateWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_todo)
            val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
            val dark = WidgetSupport.isDarkMode(context)

            // 读取实际尺寸（dp）
            val opts: Bundle = mgr.getAppWidgetOptions(appWidgetId)
            val wDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 260).coerceAtLeast(180)
            val hDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110).coerceAtLeast(80)

            // 读取待办数据
            val todoJson = prefs.getString("todo_json", null)
            val bitmap = drawTodoWidget(todoJson, dark, wDp, hDp)

            views.setImageViewBitmap(R.id.widget_todo_card, bitmap)

            // 点击跳转到 app（待办页）
            views.setOnClickPendingIntent(
                R.id.widget_todo_root,
                WidgetSupport.buildLaunchPendingIntent(context, 40000 + appWidgetId, "/todo")
            )

            mgr.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "todo widget updated: ${wDp}x${hDp}dp")
        }

        // ─── Canvas 绘制 ─────────────────────────────────────────────────────

        private fun drawTodoWidget(json: String?, dark: Boolean, wDp: Int, hDp: Int): Bitmap {
            val density = 2.75f
            val wPx = (wDp * density).toInt()
            val hPx = (hDp * density).toInt()
            val bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            // ── 颜色系统 ──
            val bgColor       = if (dark) Color.parseColor("#1C1C2E") else Color.parseColor("#FFFFFF")
            val headerBg      = if (dark) Color.parseColor("#252538") else Color.parseColor("#F1F5FF")
            val textPrimary   = if (dark) Color.parseColor("#F1F5F9") else Color.parseColor("#0F172A")
            val textSecondary = if (dark) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
            val textMuted     = if (dark) Color.parseColor("#4B5563") else Color.parseColor("#CBD5E1")
            val accentBlue    = Color.parseColor("#1D9BF0")
            val accentGreen   = Color.parseColor("#22C55E")
            val dividerColor  = if (dark) Color.parseColor("#2D2D45") else Color.parseColor("#E8EEF8")
            val doneTextColor = if (dark) Color.parseColor("#4B5563") else Color.parseColor("#CBD5E1")

            // ── 圆角背景 ──
            val cornerRadius = 20f * density
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
            canvas.drawRoundRect(
                RectF(0f, 0f, wPx.toFloat(), hPx.toFloat()),
                cornerRadius, cornerRadius, bgPaint
            )

            // ── 解析数据 ──
            var totalCount   = 0
            var doneCount    = 0
            var pendingCount = 0
            var progress     = 0.0
            // (title, priority, isDone)
            val allItems     = mutableListOf<Triple<String, Int, Boolean>>()

            if (json != null) {
                try {
                    val obj = org.json.JSONObject(json)
                    totalCount   = obj.optInt("totalCount",   0)
                    doneCount    = obj.optInt("doneCount",    0)
                    pendingCount = obj.optInt("pendingCount", 0)
                    progress     = obj.optDouble("progress",  0.0)

                    // 未完成项
                    val pendingArr = obj.optJSONArray("items")
                    if (pendingArr != null) {
                        for (i in 0 until pendingArr.length()) {
                            val item = pendingArr.getJSONObject(i)
                            allItems.add(Triple(
                                item.optString("title", ""),
                                item.optInt("priority", 0),
                                false
                            ))
                        }
                    }
                    // 已完成项
                    val doneArr = obj.optJSONArray("doneItems")
                    if (doneArr != null) {
                        for (i in 0 until doneArr.length()) {
                            val item = doneArr.getJSONObject(i)
                            allItems.add(Triple(
                                item.optString("title", ""),
                                item.optInt("priority", 0),
                                true
                            ))
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "解析 todo_json 失败", e)
                }
            }

            val pad = 14f * density
            val contentW = wPx - pad * 2
            val percent = (progress * 100).roundToInt()

            // ── 顶部标题栏 ──
            val headerH = 36f * density
            val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headerBg }
            val headerRect = RectF(pad * 0.5f, pad * 0.5f, wPx - pad * 0.5f, pad * 0.5f + headerH)
            canvas.drawRoundRect(headerRect, 12f * density, 12f * density, headerPaint)

            // 标题"待办事项"（加粗加大）
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color     = accentBlue
                textSize  = 13.5f * density
                typeface  = Typeface.DEFAULT_BOLD
                isFakeBoldText = true
            }
            canvas.drawText("待办事项", pad, pad * 0.5f + headerH * 0.68f, titlePaint)

            // 右侧统计：已完成/总数
            val statText = if (totalCount == 0) "暂无待办" else "$doneCount/$totalCount 已完成"
            val statPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color     = textSecondary
                textSize  = 10f * density
                textAlign = Paint.Align.RIGHT
            }
            canvas.drawText(statText, wPx - pad, pad * 0.5f + headerH * 0.68f, statPaint)

            // ── 进度条（8dp粗，底部吸底，与课程小部件一致）──
            val barH = 8f * density
            val barY = hPx - pad - barH  // 紧贴底部
            val barR = 4f * density       // 圆角4dp

            val barBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (dark) Color.parseColor("#374151") else Color.parseColor("#E2E8F0")
            }
            canvas.drawRoundRect(
                RectF(pad, barY, wPx - pad, barY + barH),
                barR, barR, barBgPaint
            )

            if (progress > 0) {
                val barColor = if (percent >= 100) accentGreen else accentBlue
                val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = barColor
                    // 渐变效果
                    shader = LinearGradient(
                        pad, barY,
                        pad + contentW * progress.toFloat(), barY,
                        intArrayOf(
                            if (percent >= 100) Color.parseColor("#4ADE80") else Color.parseColor("#38BDF8"),
                            barColor
                        ),
                        null, Shader.TileMode.CLAMP
                    )
                }
                val barW = (contentW * progress.toFloat()).coerceAtMost(contentW)
                canvas.drawRoundRect(
                    RectF(pad, barY, pad + barW, barY + barH),
                    barR, barR, progressPaint
                )
            }

            // ── 待办列表（进度条上方）──
            val listTop = pad * 0.5f + headerH + 14f * density
            val availH  = barY - 6f * density - listTop
            val itemH   = (availH / 4f).coerceAtLeast(16f * density)  // 最多4条均分高度
            val maxItems = min(allItems.size, (availH / itemH).toInt().coerceAtLeast(1))

            if (allItems.isEmpty()) {
                // 空状态
                val emptyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color    = textMuted
                    textSize = 11f * density
                    textAlign = Paint.Align.CENTER
                }
                canvas.drawText("✓ 暂无待办，好好休息～", wPx / 2f, listTop + availH / 2, emptyPaint)
            } else {
                for (i in 0 until maxItems) {
                    val (title, priority, isDone) = allItems[i]
                    val y = listTop + itemH * i

                    if (isDone) {
                        // 已完成：绿色勾 + 删除线文字
                        val checkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color    = accentGreen
                            textSize = 10f * density
                        }
                        canvas.drawText("✓", pad, y + itemH * 0.72f, checkPaint)

                        val donePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color    = doneTextColor
                            textSize = 11f * density
                            flags    = Paint.STRIKE_THRU_TEXT_FLAG
                        }
                        val maxW = contentW - 18f * density
                        val display = truncateText(title, Paint(donePaint), maxW)
                        canvas.drawText(display, pad + 13f * density, y + itemH * 0.72f, donePaint)
                    } else {
                        // 未完成：优先级圆点 + 普通文字
                        val dotColor = PRIORITY_COLORS[priority.coerceIn(0, 2)]
                        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = dotColor }
                        canvas.drawCircle(
                            pad + 4f * density,
                            y + itemH * 0.5f,
                            3.5f * density,
                            dotPaint
                        )

                        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color    = textPrimary
                            textSize = 11f * density
                        }
                        val maxW = contentW - 18f * density
                        val display = truncateText(title, Paint(textPaint), maxW)
                        canvas.drawText(display, pad + 13f * density, y + itemH * 0.72f, textPaint)
                    }

                    // 分隔线（最后一条不画）
                    if (i < maxItems - 1) {
                        val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color       = dividerColor
                            strokeWidth = 0.8f * density
                        }
                        canvas.drawLine(
                            pad + 12f * density, y + itemH,
                            wPx - pad,            y + itemH,
                            divPaint
                        )
                    }
                }

                // 还有更多未显示
                if (allItems.size > maxItems) {
                    val morePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color    = textMuted
                        textSize = 9.5f * density
                    }
                    canvas.drawText(
                        "…还有 ${allItems.size - maxItems} 项",
                        pad + 13f * density,
                        listTop + itemH * maxItems + 8f * density,
                        morePaint
                    )
                }
            }

            return bitmap
        }

        private fun truncateText(text: String, paint: Paint, maxWidth: Float): String {
            if (text.isEmpty()) return text
            if (paint.measureText(text) <= maxWidth) return text
            var end = text.length
            while (end > 1 && paint.measureText(text.substring(0, end) + "..") > maxWidth) {
                end--
            }
            return text.substring(0, end) + ".."
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) updateWidget(context, mgr, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, mgr: AppWidgetManager, id: Int, opts: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, mgr, id, opts)
        updateWidget(context, mgr, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            WidgetSupport.updateAll(context)
        }
    }
}
