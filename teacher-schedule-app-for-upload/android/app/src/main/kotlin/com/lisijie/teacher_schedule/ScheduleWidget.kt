package com.lisijie.teacher_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

class ScheduleWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
    }

    companion object {
        /**
         * home_widget 0.7.x 在 Android 端的存储行为：
         *   - SharedPreferences 文件名：HomeWidgetPlugin
         *   - key 格式：直接使用传入的 key，无前缀（与 Flutter shared_preferences 的 "flutter." 前缀不同）
         * 因此这里直接读 "HomeWidgetPlugin" 文件里的原始 key。
         */
        private const val PREFS_NAME = "HomeWidgetPlugin"

        private fun getWidgetPrefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget)

            // ---- 安全读取数据（任意字段失败不崩溃）----
            val prefs = try {
                getWidgetPrefs(context)
            } catch (_: Exception) { null }

            val modeLabel  = prefs?.getString("mode_label",  null) ?: "工作日"
            val statusText = prefs?.getString("status_text", null) ?: "点击查看课表"
            val timeText   = prefs?.getString("time_text",   null) ?: "--:--"
            val dateText   = prefs?.getString("date_text",   null) ?: ""

            // ---- 填充视图 ----
            try { views.setTextViewText(R.id.widget_date,   dateText)   } catch (_: Exception) {}
            try { views.setTextViewText(R.id.widget_mode,   modeLabel)  } catch (_: Exception) {}
            try { views.setTextViewText(R.id.widget_status, statusText) } catch (_: Exception) {}
            try { views.setTextViewText(R.id.widget_time,   timeText)   } catch (_: Exception) {}

            // ---- 点击打开 App（每个实例用独立 requestCode 避免 PendingIntent 复用问题）----
            try {
                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) }
                if (launchIntent != null) {
                    val pi = PendingIntent.getActivity(
                        context,
                        appWidgetId,           // 每个实例用不同 requestCode
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pi)
                }
            } catch (_: Exception) {}

            // ---- 更新 ----
            try {
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {}
        }
    }
}
