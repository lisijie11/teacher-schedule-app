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
 * 待办分类小部件（通用基类）
 * 每个子类只显示一种分类的待办事项
 *
 * 子类：TodoResearchWidget / TodoTeachingWidget / TodoTeacherCompWidget / TodoStudentCompWidget
 */
open class TodoCatWidget(
    private val catKey: String,       // "research" / "teaching" / "teacherComp" / "studentComp"
    private val catName: String,      // "科研课题" / "教改课题" / "教师比赛" / "学生比赛"
    private val catShortName: String, // "科研" / "教改" / "师赛" / "生赛"
    private val catColor: Int,        // 主题色
    private val layoutId: Int,        // R.layout.widget_todo_cat_xxx
    private val configId: Int,        // R.xml.widget_config_todo_xxx
) : AppWidgetProvider() {

    companion object {
        private const val TAG = "TodoCatWidget"
    }

    fun doUpdate(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, layoutId)
        val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
        val dark = WidgetSupport.isDarkMode(context)

        val opts: Bundle = mgr.getAppWidgetOptions(appWidgetId)
        val wDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 260).coerceAtLeast(180)
        val hDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110).coerceAtLeast(80)

        // 读取分类专属数据
        val catJson = prefs.getString("todo_json_$catKey", null)
        val bitmap = drawCatWidget(catJson, dark, wDp, hDp)

        views.setImageViewBitmap(R.id.widget_todo_card, bitmap)
        views.setOnClickPendingIntent(
            R.id.widget_todo_root,
            WidgetSupport.buildLaunchPendingIntent(context, 50000 + appWidgetId, "/todo")
        )
        mgr.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "$catShortName widget updated: ${wDp}x${hDp}dp")
    }

    private fun drawCatWidget(json: String?, dark: Boolean, wDp: Int, hDp: Int): Bitmap {
        val density = 2.75f
        val wPx = (wDp * density).toInt()
        val hPx = (hDp * density).toInt()
        val bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val bgColor       = if (dark) Color.parseColor("#1C1C2E") else Color.WHITE
        val textPrimary   = if (dark) Color.parseColor("#F1F5F9") else Color.parseColor("#0F172A")
        val textSecondary = if (dark) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
        val textMuted     = if (dark) Color.parseColor("#4B5563") else Color.parseColor("#CBD5E1")
        val accentGreen   = Color.parseColor("#22C55E")

        // 圆角背景
        canvas.drawRoundRect(
            RectF(0f, 0f, wPx.toFloat(), hPx.toFloat()),
            20f * density, 20f * density,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
        )

        // 解析 JSON
        var totalCount = 0; var doneCount = 0; var pendingCount = 0; var progress = 0.0
        var daysLeft = -1; var nearestTitle = ""
        val items = mutableListOf<CatTodoItem>()

        if (json != null) {
            try {
                val obj = JSONObject(json)
                totalCount = obj.optInt("totalCount", 0)
                doneCount = obj.optInt("doneCount", 0)
                pendingCount = obj.optInt("pendingCount", 0)
                progress = obj.optDouble("progress", 0.0)
                daysLeft = obj.optInt("daysLeft", -1)
                nearestTitle = obj.optString("nearestTitle", "")

                val itemsArr = obj.optJSONArray("items")
                if (itemsArr != null) {
                    for (i in 0 until min(itemsArr.length(), 10)) {
                        val item = itemsArr.getJSONObject(i)
                        items.add(CatTodoItem(
                            title = item.optString("title", ""),
                            isDone = item.optBoolean("isDone", false),
                            daysLeft = item.optInt("daysLeft", -1),
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
            hDp >= 180 -> drawFullLayout(canvas, dark, wPx, hPx, pad, contentW,
                    items, totalCount, doneCount, pendingCount, percent,
                    textPrimary, textSecondary, textMuted, accentGreen, density,
                    daysLeft, nearestTitle)
            else -> drawCompactLayout(canvas, dark, wPx, hPx, pad, contentW,
                    items, totalCount, doneCount, pendingCount, percent,
                    textPrimary, textSecondary, textMuted, accentGreen, density,
                    daysLeft, nearestTitle)
        }

        return bitmap
    }

    // ═══════════════════ 完整布局（高 ≥ 180dp）═══════════════════
    private fun drawFullLayout(
        canvas: Canvas, isDark: Boolean, wPx: Int, hPx: Int,
        pad: Float, cw: Float, items: List<CatTodoItem>,
        tc: Int, dc: Int, pc: Int, pct: Int,
        tpColor: Int, tsColor: Int, tmColor: Int, agColor: Int, density: Float,
        daysLeft: Int, nearestTitle: String
    ) {
        val headerBg = if (isDark) Color.parseColor("#252538") else Color.parseColor("#F1F5FF")
        val divColor = if (isDark) Color.parseColor("#2D2D45") else Color.parseColor("#E8EEF8")

        // ── 标题栏 ──
        val headerH = 34f * density
        canvas.drawRoundRect(
            RectF(pad * 0.5f, pad * 0.5f, wPx - pad * 0.5f, pad * 0.5f + headerH),
            12f * density, 12f * density,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headerBg }
        )

        // 分类色圆点 + 标题
        val dotX = pad
        val dotY = pad * 0.5f + headerH * 0.5f
        canvas.drawCircle(dotX, dotY, 5f * density,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = catColor })

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = catColor; textSize = 13f * density; typeface = Typeface.DEFAULT_BOLD; isFakeBoldText = true
        }
        canvas.drawText(catName, pad + 13f * density, pad * 0.5f + headerH * 0.68f, titlePaint)

        // 右侧统计
        val statPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = tsColor; textSize = 10.5f * density; textAlign = Paint.Align.RIGHT
        }
        canvas.drawText("$dc/$tc", wPx - pad, pad * 0.5f + headerH * 0.68f, statPaint)

        // ── 待办列表 ──
        val listTop = pad * 0.5f + headerH + 8f * density
        val availH = hPx - listTop - 28f * density
        val itemH = (availH / 4f).coerceIn(20f * density, 30f * density)

        if (items.isEmpty()) {
            val emptyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = tmColor; textSize = 11f * density; textAlign = Paint.Align.CENTER
            }
            canvas.drawText("\u2713 \u6682\u65e0\u5f85\u529e\uff0c\u597d\u597d\u4f11\u606f\uff5e",
                    wPx / 2f, listTop + availH / 2f, emptyPaint)
        } else {
            val maxRows = min(items.size, (availH / itemH).toInt().coerceAtLeast(1))
            for (i in 0 until maxRows) {
                val item = items[i]
                val y = listTop + itemH * i

                // 分类色圆点
                canvas.drawCircle(pad + 4f * density, y + itemH * 0.5f, 3.5f * density,
                        Paint(Paint.ANTI_ALIAS_FLAG).apply { color = catColor })

                // 文字
                val txtPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = tpColor; textSize = 11f * density
                }
                canvas.drawText(trunc(item.title, txtPaint, cw - 16f * density),
                        pad + 13f * density, y + itemH * 0.72f, txtPaint)

                // 截止日期标记
                if (item.daysLeft >= 0 && item.daysLeft <= 7) {
                    val dlColor = if (item.daysLeft <= 3) Color.parseColor("#EF4444") else Color.parseColor("#F59E0B")
                    val dlPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = dlColor; textSize = 8f * density; textAlign = Paint.Align.RIGHT
                    }
                    val dlText = if (item.daysLeft == 0) "\u4eca\u5929" else "${item.daysLeft}\u5929"
                    canvas.drawText(dlText, wPx - pad, y + itemH * 0.72f, dlPaint)
                }

                // 分隔线
                if (i < maxRows - 1) {
                    canvas.drawLine(pad + 12f * density, y + itemH, wPx - pad, y + itemH,
                            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = divColor; strokeWidth = 0.6f * density })
                }
            }
        }

        // ── 倒计时条 ──
        if (daysLeft >= 0 && nearestTitle.isNotEmpty()) {
            val ctTop = hPx - 22f * density - 18f * density
            drawCountdownBar(canvas, pad, ctTop, cw, 18f * density, daysLeft,
                    nearestTitle, isDark, tpColor, tsColor, density, pad)
            val ratio = if (tc == 0) 0.0f else dc.toFloat() / tc.toFloat()
            drawProgressBar(canvas, pad, hPx - 8f * density, cw, 5f * density, 3f * density,
                    ratio, pct, agColor, catColor, isDark)
        } else {
            val ratio = if (tc == 0) 0.0f else dc.toFloat() / tc.toFloat()
            drawProgressBar(canvas, pad, hPx - 14f * density, cw, 6f * density, 4f * density,
                    ratio, pct, agColor, catColor, isDark)
        }
    }

    // ═══════════════════ 紧凑布局（高 < 180dp）═══════════════════
    private fun drawCompactLayout(
        canvas: Canvas, isDark: Boolean, wPx: Int, hPx: Int,
        pad: Float, cw: Float, items: List<CatTodoItem>,
        tc: Int, dc: Int, pc: Int, pct: Int,
        tpColor: Int, tsColor: Int, tmColor: Int, agColor: Int, density: Float,
        daysLeft: Int, nearestTitle: String
    ) {
        val headerBg = if (isDark) Color.parseColor("#252538") else Color.parseColor("#F1F5FF")

        // 标题栏
        val headerH = 30f * density
        canvas.drawRoundRect(
            RectF(pad * 0.5f, pad * 0.5f, wPx - pad * 0.5f, pad * 0.5f + headerH),
            12f * density, 12f * density,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headerBg }
        )

        // 分类色圆点 + 短名
        canvas.drawCircle(pad, pad * 0.5f + headerH * 0.5f, 4.5f * density,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = catColor })

        val tP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = catColor; textSize = 12f * density; typeface = Typeface.DEFAULT_BOLD
        }
        canvas.drawText(catShortName, pad + 12f * density, pad * 0.5f + headerH * 0.68f, tP)

        val sP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = tsColor; textSize = 10f * density; textAlign = Paint.Align.RIGHT
        }
        canvas.drawText("$dc/$tc", wPx - pad, pad * 0.5f + headerH * 0.68f, sP)

        // 列表
        val listTop = pad * 0.5f + headerH + 6f * density
        val availH = hPx - listTop - 14f * density
        val itemH = (availH / 3f).coerceIn(16f * density, 24f * density)

        if (items.isNotEmpty()) {
            val mx = min(items.size, (availH / itemH).toInt().coerceAtLeast(1))
            for (i in 0 until mx) {
                val item = items[i]
                val y = listTop + itemH * i

                canvas.drawCircle(pad + 3.5f * density, y + itemH * 0.5f, 3f * density,
                        Paint(Paint.ANTI_ALIAS_FLAG).apply { color = catColor })

                val txtPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = tpColor; textSize = 10.5f * density
                }
                canvas.drawText(trunc(item.title, txtPaint, cw - 14f * density),
                        pad + 11f * density, y + itemH * 0.72f, txtPaint)
            }
        } else {
            val ep = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = tmColor; textSize = 10f * density; textAlign = Paint.Align.CENTER
            }
            canvas.drawText("\u6682\u65e0\u5f85\u529e", wPx / 2f, listTop + availH / 2f, ep)
        }

        // 进度条
        val ratio = if (tc == 0) 0.0f else dc.toFloat() / tc.toFloat()
        drawProgressBar(canvas, pad, hPx - 10f * density, cw, 5f * density, 3f * density,
                ratio, pct, agColor, catColor, isDark)
    }

    // ═══════════════════ 倒计时条 ═══════════════════
    private fun drawCountdownBar(
        c: Canvas, x: Float, y: Float, w: Float, barH: Float,
        daysLeft: Int, title: String, isDark: Boolean,
        tpColor: Int, tsColor: Int, density: Float, pad: Float
    ) {
        val bgColor = if (isDark) Color.parseColor("#2D1F1F") else Color.parseColor("#FFF7ED")
        c.drawRoundRect(RectF(x, y, x + w, y + barH), 6f * density, 6f * density,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor })

        val cdColor = when {
            daysLeft <= 3 -> Color.parseColor("#EF4444")
            daysLeft <= 7 -> Color.parseColor("#F59E0B")
            else -> catColor
        }

        // 左侧彩色竖条
        val stripeW = 2.5f * density
        c.drawRoundRect(RectF(x + 2f * density, y + 3f * density, x + 2f * density + stripeW, y + barH - 3f * density),
                1.5f * density, 1.5f * density, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = cdColor })

        // ⏰ 图标文字
        val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = cdColor; textSize = 9.5f * density; typeface = Typeface.DEFAULT_BOLD
        }
        val iconX = x + 5.5f * density
        c.drawText("\u23f0", iconX, y + barH * 0.68f, iconPaint)

        // 倒计时数字
        val numText = if (daysLeft == 0) "\u4eca\u5929" else if (daysLeft == 1) "\u660e\u5929" else "$daysLeft\u5929"
        val numPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = cdColor; textSize = 10f * density; typeface = Typeface.DEFAULT_BOLD; isFakeBoldText = true
        }
        val numX = iconX + 14f * density
        c.drawText(numText, numX, y + barH * 0.68f, numPaint)

        // 截止标题
        val titleStartX = numX + 36f * density
        val maxTitleW = w - titleStartX - pad - 8f * density
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = tsColor; textSize = 8.5f * density }
        if (maxTitleW > 20f * density) {
            c.drawText(trunc(title, titlePaint, maxTitleW), titleStartX, y + barH * 0.66f, titlePaint)
        }
    }

    // ═══════════════════ 进度条 ═══════════════════
    private fun drawProgressBar(
        c: Canvas, x: Float, y: Float, w: Float, barH: Float, radius: Float,
        prog: Float, pct: Int, greenColor: Int, accentColor: Int, isDark: Boolean
    ) {
        val bgColor = if (isDark) Color.parseColor("#374151") else Color.parseColor("#E2E8F0")
        c.drawRoundRect(RectF(x, y, x + w, y + barH), radius, radius,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor })

        if (prog > 0f) {
            val startC = if (pct >= 100) Color.parseColor("#4ADE80") else accentColor
            val endC = if (pct >= 100) Color.parseColor("#22C55E") else catColor
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

    // ═══════════════════ 生命周期 ═══════════════════
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) doUpdate(context, mgr, id)
    }

    override fun onAppWidgetOptionsChanged(ctx: Context, mgr: AppWidgetManager, id: Int, opts: Bundle) {
        super.onAppWidgetOptionsChanged(ctx, mgr, id, opts)
        doUpdate(ctx, mgr, id)
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        super.onReceive(ctx, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) WidgetSupport.updateAll(ctx)
    }
}

// ═══════════════════ 4 个子类 ═══════════════════

class TodoResearchWidget : TodoCatWidget(
    catKey = "research",
    catName = "\u79d1\u7814\u8bfe\u9898",
    catShortName = "\u79d1\u7814",
    catColor = Color.parseColor("#6C63FF"),
    layoutId = R.layout.widget_todo_cat_research,
    configId = R.xml.widget_config_todo_research,
) {
    companion object {
        private var _instance = TodoResearchWidget()
        fun updateWidget(context: Context, mgr: AppWidgetManager, id: Int) {
            _instance.doUpdate(context, mgr, id)
        }
    }
}

class TodoTeachingWidget : TodoCatWidget(
    catKey = "teaching",
    catName = "\u6559\u6539\u8bfe\u9898",
    catShortName = "\u6559\u6539",
    catColor = Color.parseColor("#07C160"),
    layoutId = R.layout.widget_todo_cat_teaching,
    configId = R.xml.widget_config_todo_teaching,
) {
    companion object {
        private var _instance = TodoTeachingWidget()
        fun updateWidget(context: Context, mgr: AppWidgetManager, id: Int) {
            _instance.doUpdate(context, mgr, id)
        }
    }
}

class TodoTeacherCompWidget : TodoCatWidget(
    catKey = "teacherComp",
    catName = "\u6559\u5e08\u6bd4\u8d5b",
    catShortName = "\u5e08\u8d5b",
    catColor = Color.parseColor("#FF7043"),
    layoutId = R.layout.widget_todo_cat_teacher_comp,
    configId = R.xml.widget_config_todo_teacher_comp,
) {
    companion object {
        private var _instance = TodoTeacherCompWidget()
        fun updateWidget(context: Context, mgr: AppWidgetManager, id: Int) {
            _instance.doUpdate(context, mgr, id)
        }
    }
}

class TodoStudentCompWidget : TodoCatWidget(
    catKey = "studentComp",
    catName = "\u5b66\u751f\u6bd4\u8d5b",
    catShortName = "\u751f\u8d5b",
    catColor = Color.parseColor("#1D9BF0"),
    layoutId = R.layout.widget_todo_cat_student_comp,
    configId = R.xml.widget_config_todo_student_comp,
) {
    companion object {
        private var _instance = TodoStudentCompWidget()
        fun updateWidget(context: Context, mgr: AppWidgetManager, id: Int) {
            _instance.doUpdate(context, mgr, id)
        }
    }
}

// 待办项数据类
data class CatTodoItem(
    val title: String,
    val isDone: Boolean,
    val daysLeft: Int,
)
