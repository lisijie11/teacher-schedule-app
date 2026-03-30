package com.lisijie.teacher_schedule

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

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

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)

            val modeLabel = widgetData.getString("mode_label", "工作日") ?: "工作日"
            val statusText = widgetData.getString("status_text", "加载中...") ?: "加载中..."
            val timeText = widgetData.getString("time_text", "--:--") ?: "--:--"
            val dateText = widgetData.getString("date_text", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.schedule_widget)
            views.setTextViewText(R.id.widget_date, dateText)
            views.setTextViewText(R.id.widget_mode, modeLabel)
            views.setTextViewText(R.id.widget_status, statusText)
            views.setTextViewText(R.id.widget_time, timeText)

            // 点击小组件打开 App
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_date, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
