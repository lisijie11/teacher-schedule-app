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
import org.json.JSONObject

/**
 * 待办事项四分类小部件
 * 四分类: 科研课题 / 教改课题 / 教师比赛 / 学生比赛
 */
class TodoWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "TodoWidget"

        // 四分类颜色（与 Flutter TodoCategoryMeta 对应）
        private val CAT_COLORS = intArrayOf(
            Color.parseColor("#6C63FF"), // 科研课题 - 紫蓝
            Color.parseColor("#07C160"), // 教改课题 - 绿
            Color.parseColor("#FF7043"), // 教师比赛 - 橙
            Color.parseColor("#1D9BF0"), // 学生比赛 - 蓝
        )

        private val CAT_NAMES = arrayOf("科研", "教改", "教师赛", "学生赛")
        private val CAT_KEYS = arrayOf("research", "teaching", "teacherComp", "studentComp")

        fun updateWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_todo)
            val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
            val dark = WidgetSupport.isDarkMode(context)

            val opts: Bundle = mgr.getAppWidgetOptions(appWidgetId)
            val wDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 260).coerceAtLeast(180)
            val hDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110).coerceAtLeast(80)

            val todoJson = prefs.getString("todo_json", null)
            val bitmap = drawTodoWidget(todoJson, dark, wDp, hDp)

            views.setImageViewBitmap(R.id.widget_todo_card, bitmap)
            views.setOnClickPendingIntent(
                R.id.widget_todo_root,
                WidgetSupport.buildLaunchPendingIntent(context, 40000 + appWidgetId, "/todo")
            )
            mgr.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "todo widget updated: ${wDp}x${hDp}dp")
        }

        private fun drawTodoWidget(json: String?, dark: Boolean, wDp: Int, hDp: Int): Bitmap {
            val density = 2.75f
            val wPx = (wDp * density).toInt()
            val hPx = (hDp * density).toInt()
            val bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            // 颜色定义
            val bgColor       = if (dark) Color.parseColor("#1C1C2E") else Color.WHITE
            val textPrimary   = if (dark) Color.parseColor("#F1F5F9") else Color.parseColor("#0F172A")
            val textSecondary = if (dark) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
            val textMuted     = if (dark) Color.parseColor("#4B5563") else Color.parseColor("#CBD5E1")
            val accentBlue    = Color.parseColor("#1D9BF0")
            val accentGreen   = Color.parseColor("#22C55E")

            // 圆角背景
            canvas.drawRoundRect(
                RectF(0f, 0f, wPx.toFloat(), hPx.toFloat()),
                20f * density, 20f * density,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
            )

            // 解析 JSON 数据
            var totalCount = 0; var doneCount = 0; var pendingCount = 0; var progress = 0.0
            val catCounts = IntArray(4) { 0 }
            val allItems = mutableListOf<Triple<String, Int, String>>()

            if (json != null) {
                try {
                    val obj = JSONObject(json)
                    totalCount = obj.optInt("totalCount", 0)
                    doneCount = obj.optInt("doneCount", 0)
                    pendingCount = obj.optInt("pendingCount", 0)
                    progress = obj.optDouble("progress", 0.0)

                    val categoriesObj = obj.optJSONObject("categories")
                    if (categoriesObj != null) {
                        for (i in CAT_KEYS.indices) {
                            val catObj = categoriesObj.optJSONObject(CAT_KEYS[i])
                            if (catObj != null) catCounts[i] = catObj.optInt("count", 0)
                        }
                    }

                    val itemsArr = obj.optJSONArray("items")
                    if (itemsArr != null) {
                        for (i in 0 until min(itemsArr.length(), 10)) {
                            val item = itemsArr.getJSONObject(i)
                            allItems.add(Triple(
                                item.optString("title", ""),
                                item.optInt("priority", 0),
                                item.optString("category", "")
                            ))
                        }
                    }
                } catch (e: Exception) { Log.e(TAG, "parse error", e) }
            }

            val pad = 12f * density
            val contentW = wPx - pad * 2
            val percent = (progress * 100).roundToInt()

            // 根据高度选择布局
            when {
                hDp >= 200 -> drawFourCategoryLayout(canvas, dark, wPx, hPx, pad, contentW,
                        catCounts, allItems, totalCount, doneCount, percent,
                        textPrimary, textSecondary, textMuted, accentBlue, accentGreen, density)
                hDp >= 140 -> drawCompactLayout(canvas, dark, wPx, hPx, pad, contentW,
                        catCounts, allItems, totalCount, doneCount, percent,
                        textPrimary, textSecondary, accentBlue, accentGreen, density)
                else -> drawMiniLayout(canvas, dark, wPx, hPx, pad, contentW,
                        catCounts, allItems, pendingCount, percent,
                        textPrimary, textSecondary, accentBlue, accentGreen, density)
            }

            return bitmap
        }

        // ═══════════════════ 完整四分类布局 ═══════════════════
        private fun drawFourCategoryLayout(
            canvas: Canvas, isDark: Boolean, wPx: Int, hPx: Int,
            pad: Float, cw: Float, catCounts: IntArray, items: List<Triple<String, Int, String>>,
            tc: Int, dc: Int, pct: Int, tpColor: Int, tsColor: Int, tmColor: Int, abColor: Int, agColor: Int, density: Float
        ) {
            val headerBg = if (isDark) Color.parseColor("#252538") else Color.parseColor("#F1F5FF")
            val divColor = if (isDark) Color.parseColor("#2D2D45") else Color.parseColor("#E8EEF8")

            // 标题栏背景
            val headerH = 34f * density
            val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headerBg }
            canvas.drawRoundRect(RectF(pad * 0.5f, pad * 0.5f, wPx - pad * 0.5f, pad * 0.5f + headerH),
                    12f * density, 12f * density, headerPaint)

            // 标题文字
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = abColor; textSize = 13f * density; typeface = Typeface.DEFAULT_BOLD; isFakeBoldText = true
            }
            canvas.drawText("\u5de5\u4f5c\u5f85\u529e", pad, pad * 0.5f + headerH * 0.68f, titlePaint)

            // 右侧统计
            val statPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = tsColor; textSize = 10.5f * density; textAlign = Paint.Align.RIGHT
            }
            val statText = if (tc == 0) "" else "$dc/$tc"
            canvas.drawText(statText, wPx - pad, pad * 0.5f + headerH * 0.68f, statPaint)

            // ── 四分类卡片行 ──
            val cardTop = pad * 0.5f + headerH + 8f * density
            val cardH = 44f * density
            val cardGap = 4f * density
            val cardLw = (cw - cardGap * 3) / 4f

            for (i in 0..3) {
                val cx = pad + (cardLw + cardGap) * i
                val cy = cardTop
                val cc = CAT_COLORS[i]

                // 卡片半透明背景
                val cardBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = cc and 0x00FFFFFF or (if (isDark) 30 else 20 shl 24)
                }
                val cr = RectF(cx, cy, cx + cardLw, cy + cardH)
                canvas.drawRoundRect(cr, 10f * density, 10f * density, cardBgPaint)

                // 卡片彩色边框
                val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE; strokeWidth = 1.5f * density; color = cc
                }
                canvas.drawRoundRect(cr, 10f * density, 10f * density, strokePaint)

                // 数量数字
                val countPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = cc; textSize = 18f * density; typeface = Typeface.DEFAULT_BOLD
                    isFakeBoldText = true; textAlign = Paint.Align.CENTER
                }
                canvas.drawText("${catCounts[i]}", cx + cardLw / 2f, cy + cardH * 0.52f, countPaint)

                // 分类名称
                val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = tmColor; textSize = 9f * density; textAlign = Paint.Align.CENTER
                }
                canvas.drawText(CAT_NAMES[i], cx + cardLw / 2f, cy + cardH * 0.85f, namePaint)
            }

            // ── 待办列表 ──
            val listTop = cardTop + cardH + 8f * density
            val availH = hPx.toFloat() - listTop - 24f * density
            val itemH = (availH / 3.5f).coerceIn(22f * density, 32f * density)

            if (items.isEmpty()) {
                val emptyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = tmColor; textSize = 11f * density; textAlign = Paint.Align.CENTER
                }
                canvas.drawText("\u2713 \u6682\u65e0\u5f85\u529e\uff0c\u597d\u597d\u4f11\u606f\uff5e",
                        wPx / 2f, listTop + availH / 2f, emptyPaint)
            } else {
                val maxRows = min(items.size, (availH / itemH).toInt().coerceAtLeast(1))
                for (i in 0 until maxRows) {
                    val (title, _, catKey) = items[i]
                    val y = listTop + itemH * i
                    val ci = CAT_KEYS.indexOf(catKey).coerceIn(0, 3)

                    // 分类色圆点
                    val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CAT_COLORS[ci] }
                    canvas.drawCircle(pad + 4f * density, y + itemH * 0.5f, 3.5f * density, dotPaint)

                    // 文字
                    val txtPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = tpColor; textSize = 11f * density
                    }
                    canvas.drawText(trunc(title, txtPaint, cw - 16f * density),
                            pad + 13f * density, y + itemH * 0.72f, txtPaint)

                    // 分隔线
                    if (i < maxRows - 1) {
                        val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = divColor; strokeWidth = 0.6f * density
                        }
                        canvas.drawLine(pad + 12f * density, y + itemH, wPx - pad, y + itemH, divPaint)
                    }
                }
            }

            // 进度条
            val ratio = if (tc == 0) 0.0f else dc.toFloat() / tc.toFloat()
            drawProgressBar(canvas, pad, hPx - 14f * density, cw, 6f * density, 4f * density, ratio, pct, agColor, abColor, isDark)
        }

        // ═══════════════════ 紧凑双行布局 ═══════════════════
        private fun drawCompactLayout(
            canvas: Canvas, isDark: Boolean, wPx: Int, hPx: Int,
            pad: Float, cw: Float, catCounts: IntArray, items: List<Triple<String, Int, String>>,
            tc: Int, dc: Int, pct: Int, tpColor: Int, tsColor: Int, abColor: Int, agColor: Int, density: Float
        ) {
            val headerBg = if (isDark) Color.parseColor("#252538") else Color.parseColor("#F1F5FF")
            val headerH = 32f * density

            val hp = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headerBg }
            canvas.drawRoundRect(RectF(pad * 0.5f, pad * 0.5f, wPx - pad * 0.5f, pad * 0.5f + headerH),
                    12f * density, 12f * density, hp)

            val tP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = abColor; textSize = 12.5f * density; typeface = Typeface.DEFAULT_BOLD
            }
            canvas.drawText("\u5de5\u4f5c\u5f85\u529e", pad, pad * 0.5f + headerH * 0.68f, tP)

            val sP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = tsColor; textSize = 10f * density; textAlign = Paint.Align.RIGHT
            }
            val statText = if (tc == 0) "" else "$dc/$tc"
            canvas.drawText(statText, wPx - pad, pad * 0.5f + headerH * 0.68f, sP)

            // 双行分类标签
            val tagTop = pad * 0.5f + headerH + 6f * density
            val tagH = 20f * density
            for (i in 0..3) {
                val row = i / 2; val col = i % 2
                val lx = pad + col * (cw / 2f + 2f * density)
                val ly = if (row == 0) tagTop else tagTop + tagH + 4f * density
                val lw = cw / 2f - 2f * density

                val bgP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = CAT_COLORS[i]; alpha = if (isDark) 35 else 20
                }
                canvas.drawRoundRect(RectF(lx, ly, lx + lw, ly + tagH), 6f * density, 6f * density, bgP)

                val txt = "${CAT_NAMES[i]} ${catCounts[i]}"
                val txP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = CAT_COLORS[i]; textSize = 10f * density; typeface = Typeface.DEFAULT_BOLD
                }
                canvas.drawText(txt, lx + 6f * density, ly + tagH * 0.7f, txP)
            }

            // 列表
            val listTop = tagTop + tagH * 2 + 10f * density
            val availH = hPx - listTop - 14f * density
            val itemH = (availH / 2.5f).coerceIn(18f * density, 26f * density)

            if (items.isNotEmpty()) {
                val mx = min(items.size, (availH / itemH).toInt().coerceAtLeast(1))
                for (i in 0 until mx) {
                    val (title, _, catKey) = items[i]
                    val y = listTop + itemH * i
                    val ci = CAT_KEYS.indexOf(catKey).coerceIn(0, 3)

                    val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CAT_COLORS[ci] }
                    canvas.drawCircle(pad + 3.5f * density, y + itemH * 0.5f, 3f * density, dotPaint)

                    val txtPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = tpColor; textSize = 10.5f * density
                    }
                    canvas.drawText(trunc(title, txtPaint, cw - 14f * density),
                            pad + 11f * density, y + itemH * 0.72f, txtPaint)
                }
            }

            val ratio = if (tc == 0) 0.0f else dc.toFloat() / tc.toFloat()
            drawProgressBar(canvas, pad, hPx - 10f * density, cw, 5f * density, 3f * density, ratio, pct, agColor, abColor, isDark)
        }

        // ═══════════════════ 迷你版布局 ═══════════════════
        private fun drawMiniLayout(
            canvas: Canvas, isDark: Boolean, wPx: Int, hPx: Int,
            pad: Float, cw: Float, catCounts: IntArray, items: List<Triple<String, Int, String>>,
            pc: Int, pct: Int, tpColor: Int, tsColor: Int, abColor: Int, agColor: Int, density: Float
        ) {
            val headerBg = if (isDark) Color.parseColor("#252538") else Color.parseColor("#F1F5FF")
            val headerH = 30f * density

            val hp = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headerBg }
            canvas.drawRoundRect(RectF(pad * 0.5f, pad * 0.5f, wPx - pad * 0.5f, pad * 0.5f + headerH),
                    12f * density, 12f * density, hp)

            val tP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = abColor; textSize = 12f * density; typeface = Typeface.DEFAULT_BOLD
            }
            canvas.drawText("\u5de5\u4f5c\u5f85\u529e", pad, pad * 0.5f + headerH * 0.68f, tP)

            val sP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = tsColor; textSize = 9.5f * density; textAlign = Paint.Align.RIGHT
            }
            val rightText = if (pc == 0) "\u2713\u5b8c\u6210" else "$pc\u9879\u5f85\u529e"
            canvas.drawText(rightText, wPx - pad, pad * 0.5f + headerH * 0.68f, sP)

            // 四个迷你圆点+数量
            val cy = pad * 0.5f + headerH + 10f * density
            val dotSize = 8f * density
            val sp = cw / 4f

            for (i in 0..3) {
                val dx = pad + sp * i + sp / 2 - dotSize / 2
                val dp = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CAT_COLORS[i] }
                canvas.drawCircle(dx, cy, dotSize / 2f, dp)

                val np = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = tpColor; textSize = 9f * density; typeface = Typeface.DEFAULT_BOLD
                    textAlign = Paint.Align.CENTER
                }
                canvas.drawText("${catCounts[i]}", dx + dotSize / 2 + 6f * density, cy + 3f * density, np)
            }

            // 首条待办文字
            val ty = cy + 16f * density
            if (items.isNotEmpty()) {
                val (title, _, catKey) = items[0]
                val ci = CAT_KEYS.indexOf(catKey).coerceIn(0, 3)

                val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CAT_COLORS[ci] }
                canvas.drawCircle(pad + 3f * density, ty + 4f * density, 2.5f * density, dotPaint)

                val txtPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = tpColor; textSize = 10f * density
                }
                canvas.drawText(trunc(title, txtPaint, cw - 12f * density),
                        pad + 11f * density, ty + 8f * density, txtPaint)

                if (items.size > 1) {
                    val mp = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = tsColor; textSize = 9f * density }
                    canvas.drawText("+${items.size - 1}", wPx - pad, ty + 8f * density, mp)
                }
            } else {
                val ep = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = tsColor; textSize = 10f * density }
                canvas.drawText("\u6682\u65e0\u5f85\u529e", pad + 10f * density, ty + 8f * density, ep)
            }

            drawProgressBar(canvas, pad, hPx - 8f * density, cw, 4f * density, 2f * density,
                    0.0f, 0, agColor, abColor, isDark)
        }

        // ═══════════════════ 进度条 ═══════════════════
        private fun drawProgressBar(
            c: Canvas, x: Float, y: Float, w: Float, barH: Float, radius: Float,
            prog: Float, pct: Int, greenColor: Int, blueColor: Int, isDark: Boolean
        ) {
            val bgColor = if (isDark) Color.parseColor("#374151") else Color.parseColor("#E2E8F0")
            c.drawRoundRect(RectF(x, y, x + w, y + barH), radius, radius,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor })

            if (prog > 0f) {
                val startC = if (pct >= 100) Color.parseColor("#4ADE80") else Color.parseColor("#38BDF8")
                val endC = if (pct >= 100) Color.parseColor("#22C55E") else Color.parseColor("#1D9BF0")
                val barW = (w * prog).coerceAtMost(w)
                val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(x, y, x + barW, y, intArrayOf(startC, endC), null, Shader.TileMode.CLAMP)
                }
                c.drawRoundRect(RectF(x, y, x + barW, y + barH), radius, radius, barPaint)
            }
        }

        // ═══════════════════ 文字截断工具 ═══════════════════
        private fun trunc(text: String, paint: Paint, maxWidth: Float): String {
            if (text.isEmpty() || paint.measureText(text) <= maxWidth) return text
            var end = text.length
            while (end > 1 && paint.measureText(text.substring(0, end) + "..") > maxWidth) end--
            return text.substring(0, end) + ".."
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) updateWidget(context, mgr, id)
    }

    override fun onAppWidgetOptionsChanged(ctx: Context, mgr: AppWidgetManager, id: Int, opts: Bundle) {
        super.onAppWidgetOptionsChanged(ctx, mgr, id, opts)
        updateWidget(ctx, mgr, id)
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        super.onReceive(ctx, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) WidgetSupport.updateAll(ctx)
    }
}
