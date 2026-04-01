package com.lisijie.teacher_schedule

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import android.app.PendingIntent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

// ─── 数据模型 ────────────────────────────────────────────────────────────────

data class WidgetCourseInfo(
    val id: String,
    val name: String,
    val location: String,
    val startTime: String,
    val endTime: String,
    val status: String,  // "ongoing" / "upcoming" / "completed"
    val progress: Int = 0,
    val section: String = "",
)

data class WidgetSnapshot(
    val date: String,
    val state: String,           // "ongoing" / "upcoming" / "completed" / "no_course"
    val highlightCourse: WidgetCourseInfo?,
    val tomorrowCourse: TomorrowCourseInfo?,  // 明日课程信息
    val allCourses: List<WidgetCourseInfo>,
    val totalCourseCount: Int,
    val gridData: List<GridDayInfo>,
)

data class TomorrowCourseInfo(
    val weekday: Int,           // 1-7
    val weekdayName: String,     // "周一"
    val month: Int,             // 3
    val day: Int,               // 2
    val totalCount: Int,        // 总课程数
    val morningCount: Int,      // 上午课程数
    val afternoonCount: Int,    // 下午课程数
    val courses: List<TomorrowCourseDetail>,
)

data class TomorrowCourseDetail(
    val period: Int,            // 1-8
    val periodName: String,     // "第1-2节"
    val courseName: String,
    val classroom: String,
    val timePart: String,      // "morning" / "afternoon"
)

data class GridDayInfo(
    val date: String,        // "4/1"
    val weekday: String,     // "周三"
    val isToday: Boolean,
    val courses: List<GridCellInfo>,
)

data class GridCellInfo(
    val period: Int,         // 1-8
    val name: String,        // 课程名
    val color: Int,          // 颜色索引 (-1=空)
)

data class WidgetSizeProfile(
    val widthDp: Int,
    val heightDp: Int,
) {
    val isNarrow: Boolean get() = widthDp < 130
    val isShort: Boolean get() = heightDp < 150
    val isTall: Boolean get() = heightDp > 250
    val isWide: Boolean get() = widthDp > heightDp + 36
}

// ─── 工具对象 ────────────────────────────────────────────────────────────────

object WidgetSupport {
    private const val TAG = "WidgetSupport"
    private const val PREFS_NAME = "HomeWidgetPlugin"

    fun readSnapshot(context: Context): WidgetSnapshot? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString("snapshot_json", null) ?: return null
        return try {
            parseSnapshot(JSONObject(json))
        } catch (e: Exception) {
            Log.e(TAG, "解析 snapshot 失败", e)
            null
        }
    }

    fun sizeProfile(mgr: AppWidgetManager, id: Int): WidgetSizeProfile {
        val opts: Bundle = mgr.getAppWidgetOptions(id)
        val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0).coerceAtLeast(110)
        val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0).coerceAtLeast(110)
        return WidgetSizeProfile(w, h)
    }

    fun setTextSizeSp(views: RemoteViews, viewId: Int, sizeSp: Float) {
        views.setTextViewTextSize(viewId, TypedValue.COMPLEX_UNIT_SP, sizeSp)
    }

    fun updateAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val pairs = listOf(
            ScheduleWidget::class.java,
            ScheduleWidgetMedium::class.java,
            ScheduleWidgetLarge::class.java,
        )
        for (cls in pairs) {
            val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
            for (id in ids) {
                when (cls) {
                    ScheduleWidget::class.java -> ScheduleWidget.updateWidget(context, mgr, id)
                    ScheduleWidgetMedium::class.java -> ScheduleWidgetMedium.updateWidget(context, mgr, id)
                    ScheduleWidgetLarge::class.java -> ScheduleWidgetLarge.updateWidget(context, mgr, id)
                }
            }
        }
    }

    fun buildLaunchPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun isDarkMode(ctx: Context): Boolean = try {
        val id = ctx.resources.getIdentifier("config_night_mode", "integer", "android")
        if (id != 0) ctx.resources.getInteger(id) == 1 else false
    } catch (_: Exception) { false }

    // 主课程名
    fun heroCourseName(snapshot: WidgetSnapshot): String {
        return when {
            snapshot.highlightCourse != null -> snapshot.highlightCourse.name
            snapshot.state == "completed" && snapshot.tomorrowCourse != null -> {
                // 明日有课，显示第一条课程名
                val first = snapshot.tomorrowCourse.courses.firstOrNull()
                first?.courseName ?: "明天有课"
            }
            snapshot.state == "completed" -> "今天课程已结束"
            else -> "今天没有课程"
        }
    }

    // 主时间
    fun heroTimeText(snapshot: WidgetSnapshot): String {
        val c = snapshot.highlightCourse
        return when {
            c != null && c.startTime.isNotBlank() && c.endTime.isNotBlank() ->
                "${c.startTime} - ${c.endTime}"
            snapshot.state == "completed" && snapshot.tomorrowCourse != null -> {
                // 显示明天上下午课程数
                val t = snapshot.tomorrowCourse
                val parts = mutableListOf<String>()
                if (t.morningCount > 0) parts.add("上午${t.morningCount}节")
                if (t.afternoonCount > 0) parts.add("下午${t.afternoonCount}节")
                if (parts.isEmpty()) "明天有课" else parts.joinToString(" · ")
            }
            snapshot.state == "completed" -> "接下来没有课程"
            else -> "留一点时间给自己"
        }
    }

    // 主地点
    fun heroLocationText(snapshot: WidgetSnapshot): String {
        val c = snapshot.highlightCourse
        return when {
            c != null && c.location.isNotBlank() -> c.location
            snapshot.totalCourseCount > 0 -> "今日共 ${snapshot.totalCourseCount} 节"
            else -> ""
        }
    }

    // footer 文字
    fun footerText(snapshot: WidgetSnapshot): String {
        return if (snapshot.state == "completed" && snapshot.tomorrowCourse != null) {
            // 今日完成，显示明天日期和课程数
            val t = snapshot.tomorrowCourse
            "明日 ${t.weekdayName} ${t.month}月${t.day}日 · 共${t.totalCount}节"
        } else if (snapshot.totalCourseCount > 0) {
            "今日 ${snapshot.totalCourseCount} 节课"
        } else {
            "课表助手"
        }
    }

    // 状态文字
    fun statusText(state: String, tomorrowCourse: TomorrowCourseInfo?): String = when (state) {
        "ongoing" -> "正在上课"
        "upcoming" -> "下一节课"
        "completed" -> if (tomorrowCourse != null) "明日课程预告" else "今日已结束"
        else -> "今日无课"
    }

    // 去掉高亮课程后的列表
    fun secondaryCourses(snapshot: WidgetSnapshot, limit: Int): List<WidgetCourseInfo> {
        val highlightId = snapshot.highlightCourse?.id
        val courses = if (highlightId == null) {
            snapshot.allCourses
        } else {
            snapshot.allCourses.filterNot { it.id == highlightId }
        }
        return courses.take(limit)
    }

    // ─── JSON 解析 ────────────────────────────────────────────────────────

    private fun parseSnapshot(json: JSONObject): WidgetSnapshot {
        val allCourses = parseCourses(json.optJSONArray("allCourses"))
        val highlight = json.optJSONObject("highlightCourse")?.let(::parseCourse)
        val tomorrowCourse = json.optJSONObject("tomorrowCourse")?.let(::parseTomorrowCourse)
        val gridData = parseGridData(json.optJSONArray("gridData"))
        return WidgetSnapshot(
            date = json.optString("date", ""),
            state = json.optString("state", "no_course"),
            highlightCourse = highlight,
            tomorrowCourse = tomorrowCourse,
            allCourses = allCourses,
            totalCourseCount = json.optInt("totalCourseCount", allCourses.size),
            gridData = gridData,
        )
    }

    private fun parseTomorrowCourse(json: JSONObject): TomorrowCourseInfo {
        val coursesArray = json.optJSONArray("courses")
        val courses = buildList {
            if (coursesArray != null) {
                for (i in 0 until coursesArray.length()) {
                    val c = coursesArray.getJSONObject(i)
                    add(TomorrowCourseDetail(
                        period = c.optInt("period", i + 1),
                        periodName = c.optString("periodName", ""),
                        courseName = c.optString("courseName", ""),
                        classroom = c.optString("classroom", ""),
                        timePart = c.optString("timePart", "morning"),
                    ))
                }
            }
        }
        return TomorrowCourseInfo(
            weekday = json.optInt("weekday", 1),
            weekdayName = json.optString("weekdayName", "周一"),
            month = json.optInt("month", 1),
            day = json.optInt("day", 1),
            totalCount = json.optInt("totalCount", courses.size),
            morningCount = json.optInt("morningCount", 0),
            afternoonCount = json.optInt("afternoonCount", 0),
            courses = courses,
        )
    }

    private fun parseGridData(json: JSONArray?): List<GridDayInfo> {
        if (json == null) return emptyList()
        return buildList {
            for (i in 0 until json.length()) {
                val dayJson = json.getJSONObject(i)
                val courses = dayJson.optJSONArray("courses")
                val cellList = buildList {
                    if (courses != null) {
                        for (j in 0 until courses.length()) {
                            val cell = courses.getJSONObject(j)
                            add(GridCellInfo(
                                period = cell.optInt("period", j + 1),
                                name = cell.optString("name", ""),
                                color = cell.optInt("color", -1),
                            ))
                        }
                    }
                }
                add(GridDayInfo(
                    date = dayJson.optString("date", ""),
                    weekday = dayJson.optString("weekday", ""),
                    isToday = dayJson.optBoolean("isToday", false),
                    courses = cellList,
                ))
            }
        }
    }

    private fun parseCourses(json: JSONArray?): List<WidgetCourseInfo> {
        if (json == null) return emptyList()
        return buildList {
            for (i in 0 until json.length()) {
                add(parseCourse(json.getJSONObject(i)))
            }
        }
    }

    private fun parseCourse(json: JSONObject): WidgetCourseInfo {
        return WidgetCourseInfo(
            id = json.optString("id", ""),
            name = json.optString("name", ""),
            location = json.optString("location", ""),
            startTime = json.optString("startTime", ""),
            endTime = json.optString("endTime", ""),
            status = json.optString("status", ""),
            progress = json.optInt("progress", 0),
            section = json.optString("section", ""),
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  小号 2×2 — 对标 mikcb TodayCompactWidgetProvider
// ═══════════════════════════════════════════════════════════════════════════
class ScheduleWidget : AppWidgetProvider() {
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

    companion object {
        private const val TAG = "ScheduleWidget"

        fun updateWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_today_small)
            val snapshot = WidgetSupport.readSnapshot(context)
            val profile = WidgetSupport.sizeProfile(mgr, appWidgetId)
            val dark = WidgetSupport.isDarkMode(context)
            val state = snapshot?.state ?: "no_course"

            // ── 背景 ──
            views.setInt(
                R.id.widget_small_card, "setBackgroundResource",
                if (dark) R.drawable.widget_card_bg_dark else R.drawable.widget_card_bg
            )

            // ── 日期 ──
            val dateText = snapshot?.date ?: "课表助手"
            views.setTextViewText(R.id.widget_small_date, dateText)

            // ── 状态标签 ──
            views.setTextViewText(R.id.widget_small_status, WidgetSupport.statusText(state, snapshot?.tomorrowCourse))
            views.setInt(
                R.id.widget_small_status, "setBackgroundResource",
                when (state) {
                    "ongoing" -> R.drawable.widget_status_chip
                    "upcoming" -> R.drawable.widget_status_chip_upcoming
                    else -> R.drawable.widget_status_chip_dim
                }
            )
            views.setTextColor(R.id.widget_small_status, Color.WHITE)

            // ── 课程名 ──
            views.setTextViewText(
                R.id.widget_small_course_name,
                when {
                    snapshot == null -> "点击打开应用"
                    else -> WidgetSupport.heroCourseName(snapshot)
                }
            )

            // ── 时间 ──
            views.setTextViewText(
                R.id.widget_small_time,
                when {
                    snapshot == null -> ""
                    else -> WidgetSupport.heroTimeText(snapshot)
                }
            )

            // ── 地点 ──
            views.setTextViewText(
                R.id.widget_small_location,
                when {
                    snapshot == null -> ""
                    else -> WidgetSupport.heroLocationText(snapshot)
                }
            )

            // ── 文字颜色 ──
            val primary = if (dark) Color.parseColor("#F1F5F9") else Color.parseColor("#0F172A")
            val secondary = if (dark) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
            val tertiary = if (dark) Color.parseColor("#64748B") else Color.parseColor("#94A3B8")
            views.setTextColor(R.id.widget_small_date, secondary)
            views.setTextColor(R.id.widget_small_course_name, primary)
            views.setTextColor(R.id.widget_small_time, primary)
            views.setTextColor(R.id.widget_small_location, tertiary)

            // ── 动态字号 ──
            WidgetSupport.setTextSizeSp(
                views, R.id.widget_small_course_name,
                when {
                    profile.isShort -> 16f
                    profile.isWide -> 19f
                    else -> 18f
                }
            )
            WidgetSupport.setTextSizeSp(
                views, R.id.widget_small_time,
                if (profile.isNarrow || profile.isShort) 11f else 12f
            )

            // ── 点击事件 ──
            views.setOnClickPendingIntent(
                R.id.widget_small_root,
                WidgetSupport.buildLaunchPendingIntent(context, 10000 + appWidgetId)
            )

            mgr.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "small widget updated: state=$state course=${snapshot?.highlightCourse?.name}")
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  中号 4×2 — 对标 mikcb TodayMediumWidgetProvider
// ═══════════════════════════════════════════════════════════════════════════
class ScheduleWidgetMedium : AppWidgetProvider() {
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

    companion object {
        private const val TAG = "ScheduleWidgetMedium"

        fun updateWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_today_medium)
            val snapshot = WidgetSupport.readSnapshot(context)
            val profile = WidgetSupport.sizeProfile(mgr, appWidgetId)
            val dark = WidgetSupport.isDarkMode(context)
            val state = snapshot?.state ?: "no_course"

            // ── 背景 ──
            views.setInt(
                R.id.widget_medium_card, "setBackgroundResource",
                if (dark) R.drawable.widget_card_bg_dark else R.drawable.widget_card_bg
            )

            // ── 日期 ──
            views.setTextViewText(R.id.widget_medium_date, snapshot?.date ?: "课表助手")

            // ── 状态标签 ──
            views.setTextViewText(R.id.widget_medium_status, WidgetSupport.statusText(state, snapshot?.tomorrowCourse))
            views.setInt(
                R.id.widget_medium_status, "setBackgroundResource",
                when (state) {
                    "ongoing" -> R.drawable.widget_status_chip
                    "upcoming" -> R.drawable.widget_status_chip_upcoming
                    else -> R.drawable.widget_status_chip_dim
                }
            )
            views.setTextColor(R.id.widget_medium_status, Color.WHITE)

            // ── 课程名 ──
            views.setTextViewText(
                R.id.widget_medium_course_name,
                when {
                    snapshot == null -> "今日无课"
                    else -> WidgetSupport.heroCourseName(snapshot)
                }
            )

            // ── 时间 ──
            views.setTextViewText(
                R.id.widget_medium_time,
                when {
                    snapshot == null -> "稍后打开应用同步"
                    else -> WidgetSupport.heroTimeText(snapshot)
                }
            )

            // ── 地点 ──
            views.setTextViewText(
                R.id.widget_medium_location,
                when {
                    snapshot == null -> ""
                    else -> WidgetSupport.heroLocationText(snapshot)
                }
            )

            // ── 节次 ──
            val highlight = snapshot?.highlightCourse
            views.setTextViewText(
                R.id.widget_medium_section,
                highlight?.section ?: ""
            )

            // ── 进度条 ──
            val progress = highlight?.progress ?: 0
            views.setProgressBar(R.id.widget_medium_progress, 100, progress.coerceIn(0, 100), false)

            // ── 文字颜色 ──
            val primary = if (dark) Color.parseColor("#F1F5F9") else Color.parseColor("#0F172A")
            val secondary = if (dark) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
            val tertiary = if (dark) Color.parseColor("#64748B") else Color.parseColor("#94A3B8")
            views.setTextColor(R.id.widget_medium_date, secondary)
            views.setTextColor(R.id.widget_medium_course_name, primary)
            views.setTextColor(R.id.widget_medium_time, primary)
            views.setTextColor(R.id.widget_medium_location, secondary)
            views.setTextColor(R.id.widget_medium_section, secondary)

            // ── 动态字号 ──
            WidgetSupport.setTextSizeSp(
                views, R.id.widget_medium_course_name,
                if (profile.isShort) 17f else 19f
            )
            WidgetSupport.setTextSizeSp(
                views, R.id.widget_medium_time,
                if (profile.isShort) 11f else 13f
            )
            WidgetSupport.setTextSizeSp(
                views, R.id.widget_medium_section,
                if (profile.isShort) 11f else 13f
            )
            WidgetSupport.setTextSizeSp(
                views, R.id.widget_medium_location,
                if (profile.isShort) 10f else 12f
            )

            // ── 点击事件 ──
            views.setOnClickPendingIntent(
                R.id.widget_medium_root,
                WidgetSupport.buildLaunchPendingIntent(context, 20000 + appWidgetId)
            )

            mgr.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "medium widget updated: state=$state")
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  大号 4×4 — 对标 mikcb TodayLargeWidgetProvider
// ═══════════════════════════════════════════════════════════════════════════
class ScheduleWidgetLarge : AppWidgetProvider() {
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

    companion object {
        private const val TAG = "ScheduleWidgetLarge"

        // 课程颜色表（与 Flutter CourseEntry.palette 对应）
        private val COURSE_COLORS = intArrayOf(
            Color.parseColor("#6C63FF"), // 紫蓝
            Color.parseColor("#5B8AF5"), // 天蓝
            Color.parseColor("#07C160"), // 绿
            Color.parseColor("#FF7043"), // 橙
            Color.parseColor("#FF4081"), // 玫红
            Color.parseColor("#26C6DA"), // 青
            Color.parseColor("#9C27B0"), // 紫
            Color.parseColor("#FFB300"), // 金
        )

        // 节次标签（1-8节，4个时间段）
        private val PERIOD_LABELS = arrayOf("1-2", "3-4", "5-6", "7-8")
        private val PERIOD_MAP = intArrayOf(0, 0, 0, 1, 1, 2, 2, 3, 3) // period 1→0, 2→0, 3→1...

        fun updateWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_today_large)
            val snapshot = WidgetSupport.readSnapshot(context)
            val dark = WidgetSupport.isDarkMode(context)
            val opts: Bundle = mgr.getAppWidgetOptions(appWidgetId)
            val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250).coerceAtLeast(200)
            val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 250).coerceAtLeast(200)

            // Canvas 绘制
            val bitmap = drawGridWidget(w, h, snapshot, dark)
            views.setImageViewBitmap(R.id.widget_large_card, bitmap)

            // 点击事件
            views.setOnClickPendingIntent(
                R.id.widget_large_root,
                WidgetSupport.buildLaunchPendingIntent(context, 30000 + appWidgetId)
            )

            mgr.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "large widget updated: gridData=${snapshot?.gridData?.size ?: 0} days")
        }

        private fun drawGridWidget(
            widthDp: Int, heightDp: Int,
            snapshot: WidgetSnapshot?, dark: Boolean
        ): Bitmap {
            val density = 2.5f // 使用较高 DPI 确保清晰
            val wPx = (widthDp * density).toInt()
            val hPx = (heightDp * density).toInt()
            val bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            // 颜色
            val bgColor = if (dark) Color.parseColor("#1E1E2E") else Color.parseColor("#FFFFFF")
            val headerBg = if (dark) Color.parseColor("#2A2A3C") else Color.parseColor("#F1F5F9")
            val textPrimary = if (dark) Color.parseColor("#E2E8F0") else Color.parseColor("#0F172A")
            val textSecondary = if (dark) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
            val textMuted = if (dark) Color.parseColor("#64748B") else Color.parseColor("#CBD5E1")
            val gridLineColor = if (dark) Color.parseColor("#374151") else Color.parseColor("#E2E8F0")
            val todayHighlight = if (dark) Color.parseColor("#1D9BF0") else Color.parseColor("#1D9BF0")
            val emptyCellColor = Color.TRANSPARENT

            // 圆角背景
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
            val cornerRadius = 20f * density
            val rect = RectF(0f, 0f, wPx.toFloat(), hPx.toFloat())
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, bgPaint)

            // 内边距
            val padLeft = 10f * density
            val padRight = 10f * density
            val padTop = 10f * density
            val padBottom = 10f * density
            val contentW = wPx - padLeft - padRight
            val contentH = hPx - padTop - padBottom

            // 表头行：节次标签列 + 4天日期
            val dayCount = 4
            val periodCount = 4 // 4个大节次（1-2, 3-4, 5-6, 7-8）
            val periodColWidth = 32f * density // 节次标签列宽度
            val dayColWidth = (contentW - periodColWidth) / dayCount
            val headerHeight = 36f * density

            // 绘制表头背景
            val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headerBg }
            val headerRect = RectF(padLeft, padTop, padLeft + contentW, padTop + headerHeight)
            canvas.drawRoundRect(headerRect, 12f * density, 12f * density, headerPaint)

            // 表头文字
            val headerTextSize = 10f * density
            val headerBoldPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textSecondary
                textSize = headerTextSize
                typeface = Typeface.DEFAULT_BOLD
                textAlign = Paint.Align.CENTER
            }
            val headerNormalPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textMuted
                textSize = headerTextSize
                typeface = Typeface.DEFAULT
                textAlign = Paint.Align.CENTER
            }

            // 左上角空白
            // 表头：节次标签
            canvas.drawText("节次", padLeft + periodColWidth / 2, padTop + headerHeight / 2 - 3f * density, headerNormalPaint)

            // 表头：4天的日期
            val gridData = snapshot?.gridData
            for (i in 0 until dayCount) {
                val cx = padLeft + periodColWidth + dayColWidth * i + dayColWidth / 2
                val cy = padTop + headerHeight / 2

                if (gridData != null && gridData.size > i) {
                    val day = gridData[i]
                    // 今天高亮
                    val paint = if (day.isToday) {
                        headerBoldPaint.apply { color = todayHighlight }
                    } else {
                        headerBoldPaint.apply { color = textSecondary }
                    }
                    canvas.drawText(day.weekday, cx, cy - 6f * density, paint)
                    val subPaint = headerNormalPaint.apply {
                        color = if (day.isToday) todayHighlight else textMuted
                    }
                    canvas.drawText(day.date, cx, cy + 10f * density, subPaint)
                } else {
                    canvas.drawText("周${"一二三四五六日"[i]}", cx, cy - 6f * density, headerBoldPaint)
                    canvas.drawText("", cx, cy + 10f * density, headerNormalPaint)
                }
            }

            // 网格区域
            val gridTop = padTop + headerHeight
            val gridHeight = contentH - headerHeight
            val rowHeight = gridHeight / periodCount
            val cellGap = 1.5f * density // 色块间距

            val labelTextSize = 8f * density
            val labelTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textMuted
                textSize = labelTextSize
                typeface = Typeface.DEFAULT
                textAlign = Paint.Align.CENTER
            }

            val courseTextSize = 8.5f * density
            val courseTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = courseTextSize
                typeface = Typeface.DEFAULT_BOLD
                textAlign = Paint.Align.CENTER
            }
            val courseTextSubPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = courseTextSize * 0.85f
                typeface = Typeface.DEFAULT
                textAlign = Paint.Align.CENTER
            }

            val colorPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            val roundCell = 6f * density

            for (row in 0 until periodCount) {
                val rowY = gridTop + rowHeight * row

                // 节次标签
                canvas.drawText(
                    PERIOD_LABELS[row],
                    padLeft + periodColWidth / 2,
                    rowY + rowHeight / 2 + 3f * density,
                    labelTextPaint
                )

                for (col in 0 until dayCount) {
                    val cellX = padLeft + periodColWidth + dayColWidth * col
                    val cellY = rowY + cellGap
                    val cellW = dayColWidth - cellGap * 2
                    val cellH = rowHeight - cellGap * 2

                    // 获取该格子对应的课程（两个小节合并显示）
                    val period1 = row * 2 + 1 // 1, 3, 5, 7
                    val period2 = row * 2 + 2 // 2, 4, 6, 8
                    var courseName = ""
                    var courseColor = -1

                    if (gridData != null && gridData.size > col) {
                        val dayCourses = gridData[col].courses
                        for (cell in dayCourses) {
                            if (cell.period == period1 || cell.period == period2) {
                                if (cell.name.isNotEmpty()) {
                                    courseName = cell.name
                                    courseColor = cell.color
                                    break
                                }
                            }
                        }
                    }

                    if (courseColor >= 0 && courseName.isNotEmpty()) {
                        // 绘制色块
                        val color = COURSE_COLORS[courseColor % COURSE_COLORS.size]
                        colorPaint.color = color
                        val cellRect = RectF(cellX, cellY, cellX + cellW, cellY + cellH)
                        canvas.drawRoundRect(cellRect, roundCell, roundCell, colorPaint)

                        // 课程名（截断显示）
                        val maxChars = (cellW / (courseTextSize * 0.6)).toInt().coerceAtMost(6)
                        val displayName = if (courseName.length > maxChars) {
                            courseName.substring(0, maxChars) + ".."
                        } else {
                            courseName
                        }

                        // 文字阴影增加可读性
                        courseTextPaint.setShadowLayer(1f, 0f, 0f, Color.parseColor("#40000000"))
                        canvas.drawText(
                            displayName,
                            cellX + cellW / 2,
                            cellY + cellH / 2 + 3f * density,
                            courseTextPaint
                        )
                        courseTextPaint.setShadowLayer(0f, 0f, 0f, Color.TRANSPARENT)
                    } else {
                        // 空课不绘制（保持背景色）
                    }
                }
            }

            // 底部图例（如果空间够）
            val legendY = padTop + contentH + 2f * density
            if (legendY < hPx - 5f * density) {
                val legendPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = textMuted
                    textSize = 7f * density
                    textAlign = Paint.Align.CENTER
                }
                canvas.drawText(
                    snapshot?.date ?: "课表助手",
                    wPx / 2f,
                    legendY + 6f * density,
                    legendPaint
                )
            }

            return bitmap
        }
    }
}
