package com.lisijie.teacher_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.content.Intent
import android.os.Build
import androidx.core.graphics.ColorUtils
import android.widget.RemoteViews
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class ScheduleWidgetV5 : AppWidgetProvider() {

    companion object {
        private const val TAG = "ScheduleWidgetV5"
        private const val PREFS_NAME = "TeacherScheduleWidget"
        private const val USER_INFO_PREFIX = "user_info_"
        private const val COURSES_PREFIX = "courses_"
        private const val SETTINGS_PREFIX = "settings_"

        private fun getWidgetPrefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        /**
         * 更新单个小部件实例
         */
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.schedule_widget_v5)
                val prefs = getWidgetPrefs(context)

                // 1. 获取用户信息
                val userName = prefs.getString("${USER_INFO_PREFIX}name", "李老师") ?: "李老师"
                val facultyName = prefs.getString("${USER_INFO_PREFIX}faculty", "数字媒体与设计学院") ?: "数字媒体与设计学院"
                val userAvatar = prefs.getString("${USER_INFO_PREFIX}avatar", "李") ?: "李"
                val locationMode = prefs.getString("${USER_INFO_PREFIX}location", "佛山大部") ?: "佛山大部"

                // 2. 获取日期和模式信息
                val dateText = prefs.getString("date_text", formatCurrentDate()) ?: formatCurrentDate()
                val modeLabel = prefs.getString("mode_label", "工作日") ?: "工作日"
                val isWorkday = prefs.getBoolean("is_workday", true)

                // 3. 获取课程数据
                val coursesJson = prefs.getString("${COURSES_PREFIX}today", "[]") ?: "[]"
                val courses = parseCourses(coursesJson)

                // 4. 获取个性化设置
                val showLocation = prefs.getBoolean("${SETTINGS_PREFIX}showLocation", true)
                val showFaculty = prefs.getBoolean("${SETTINGS_PREFIX}showFaculty", true)
                val maxCourses = prefs.getInt("${SETTINGS_PREFIX}maxCourses", 3)
                val themeColor = prefs.getInt("${SETTINGS_PREFIX}themeColor", 0xFF6C63FF.toInt())

                // 5. 更新UI
                updateUserInfo(views, userName, facultyName, userAvatar, showFaculty)
                updateDateAndMode(views, dateText, modeLabel, locationMode, showLocation, isWorkday)
                updateCourses(views, courses, maxCourses, themeColor)
                updateSummary(views, courses, modeLabel, locationMode, showLocation)
                updateClickIntent(context, views, appWidgetId)

                // 6. 更新小部件
                appWidgetManager.updateAppWidget(appWidgetId, views)
                
                Log.d(TAG, "小部件更新成功，显示 ${courses.size} 个课程")
            } catch (e: Exception) {
                Log.e(TAG, "更新小部件失败", e)
            }
        }

        /**
         * 格式化当前日期（3月30日）
         */
        private fun formatCurrentDate(): String {
            // 简单实现，实际情况应该使用正确的日期格式
            return "3月30日"
        }

        /**
         * 解析课程JSON数据
         */
        private fun parseCourses(jsonStr: String): List<Course> {
            val courses = mutableListOf<Course>()
            try {
                val jsonArray = JSONArray(jsonStr)
                for (i in 0 until jsonArray.length()) {
                    val json = jsonArray.getJSONObject(i)
                    val course = Course(
                        name = json.getString("name"),
                        time = json.getString("time"),
                        location = json.getString("location"),
                        className = json.getString("class"),
                        status = json.optString("status", "upcoming"),
                        isCurrent = json.optBoolean("isCurrent", false)
                    )
                    courses.add(course)
                }
                // 按时间排序
                courses.sortBy { it.time }
            } catch (e: Exception) {
                Log.w(TAG, "解析课程数据失败", e)
            }
            return courses
        }

        /**
         * 更新用户信息
         */
        private fun updateUserInfo(
            views: RemoteViews,
            userName: String,
            facultyName: String,
            avatar: String,
            showFaculty: Boolean
        ) {
            try {
                views.setTextViewText(R.id.user_name, userName)
                views.setTextViewText(R.id.user_avatar, avatar.take(1)) // 只取第一个字符作为头像
                
                if (showFaculty) {
                    views.setTextViewText(R.id.faculty_name, facultyName)
                    views.setViewVisibility(R.id.faculty_name, RemoteViews.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.faculty_name, RemoteViews.GONE)
                }
            } catch (e: Exception) {
                Log.w(TAG, "更新用户信息失败", e)
            }
        }

        /**
         * 更新日期和模式信息
         */
        private fun updateDateAndMode(
            views: RemoteViews,
            dateText: String,
            modeLabel: String,
            locationMode: String,
            showLocation: Boolean,
            isWorkday: Boolean
        ) {
            try {
                views.setTextViewText(R.id.widget_date, dateText)
                
                val modeText = if (showLocation && locationMode.isNotBlank()) {
                    "$modeLabel·$locationMode"
                } else {
                    modeLabel
                }
                views.setTextViewText(R.id.widget_mode, modeText)
                
                // 可以根据是否是工作日调整颜色
                val chipBackground = if (isWorkday) {
                    R.drawable.chip_bg_v2
                } else {
                    R.drawable.chip_bg_v2 // 可以使用不同的背景
                }
                views.setInt(R.id.widget_mode, "setBackgroundResource", chipBackground)
            } catch (e: Exception) {
                Log.w(TAG, "更新日期和模式失败", e)
            }
        }

        /**
         * 更新课程列表
         */
        private fun updateCourses(
            views: RemoteViews, 
            courses: List<Course>, 
            maxCourses: Int,
            themeColor: Int
        ) {
            try {
                val courseItems = listOf(
                    R.id.course_item_1 to R.id.course_time_1 to R.id.course_name_1 to R.id.course_location_1 to R.id.course_class_1 to R.id.course_status_1,
                    R.id.course_item_2 to R.id.course_time_2 to R.id.course_name_2 to R.id.course_location_2 to R.id.course_class_2 to R.id.course_status_2,
                    R.id.course_item_3 to R.id.course_time_3 to R.id.course_name_3 to R.id.course_location_3 to R.id.course_class_3 to R.id.course_status_3
                )

                // 显示前maxCourses个课程
                val coursesToShow = courses.take(minOf(maxCourses, 3))
                
                courseItems.forEachIndexed { index, item ->
                    val (container, timeId, nameId, locationId, classId, statusId) = item
                    
                    if (index < coursesToShow.size) {
                        val course = coursesToShow[index]
                        
                        // 显示容器
                        views.setViewVisibility(container, RemoteViews.VISIBLE)
                        
                        // 设置课程信息
                        views.setTextViewText(timeId, course.time)
                        views.setTextViewText(nameId, course.name)
                        views.setTextViewText(locationId, course.location)
                        views.setTextViewText(classId, course.className)
                        
                        // 设置状态指示器颜色
                        val statusColor = when (course.status) {
                            "current" -> 0xFF4CAF50.toInt()  // 绿色 - 当前正在进行
                            "upcoming" -> 0xFFFF9800.toInt() // 橙色 - 即将开始
                            "completed" -> 0xFF757575.toInt() // 灰色 - 已完成
                            else -> themeColor
                        }
                        views.setInt(statusId, "setBackgroundColor", statusColor)
                        
                        // 如果当前课程，增加亮度
                        if (course.isCurrent) {
                            val highlightedColor = ColorUtils.blendARGB(statusColor, 0xFFFFFFFF, 0.2f)
                            views.setInt(statusId, "setBackgroundColor", highlightedColor)
                        }
                    } else {
                        // 隐藏未使用的课程项
                        views.setViewVisibility(container, RemoteViews.GONE)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "更新课程列表失败", e)
            }
        }

        /**
         * 更新状态摘要
         */
        private fun updateSummary(
            views: RemoteViews,
            courses: List<Course>,
            modeLabel: String,
            locationMode: String,
            showLocation: Boolean
        ) {
            try {
                val summaryText = when {
                    courses.isEmpty() -> "今天暂无课程安排"
                    courses.size == 1 -> {
                        val nextCourse = courses.first()
                        "下节课 ${nextCourse.name} 在${nextCourse.time}"
                    }
                    else -> {
                        val upcomingCount = courses.count { it.status == "upcoming" }
                        val currentCount = courses.count { it.status == "current" }
                        
                        when {
                            currentCount > 0 -> "有${currentCount}节课正在进行中"
                            upcomingCount > 0 -> "今天还有${upcomingCount}节课"
                            else -> "今天课程已全部结束"
                        }
                    }
                }
                
                views.setTextViewText(R.id.widget_status, summaryText)
            } catch (e: Exception) {
                Log.w(TAG, "更新状态摘要失败", e)
            }
        }

        /**
         * 更新点击事件
         */
        private fun updateClickIntent(
            context: Context,
            views: RemoteViews,
            appWidgetId: Int
        ) {
            try {
                // 1. 点击整个小部件打开应用
                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply { 
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        // 可以添加额外数据，比如直接跳转到今日课程页面
                        putExtra("navigate_to", "today_screen")
                    }
                
                if (launchIntent != null) {
                    val pi = PendingIntent.getActivity(
                        context,
                        appWidgetId,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or 
                        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                            PendingIntent.FLAG_IMMUTABLE else 0)
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pi)
                }

                // 2. 点击用户头像打开设置
                val settingsIntent = Intent(context, context.packageManager
                    .getLaunchIntentForPackage(context.packageName)?.component)
                    .apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        putExtra("navigate_to", "settings_screen")
                    }
                
                val settingsPi = PendingIntent.getActivity(
                    context,
                    appWidgetId * 100 + 1,
                    settingsIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or 
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                        PendingIntent.FLAG_IMMUTABLE else 0)
                )
                views.setOnClickPendingIntent(R.id.user_avatar, settingsPi)
                
            } catch (e: Exception) {
                Log.w(TAG, "设置点击事件失败", e)
            }
        }

        /**
         * 手动触发所有小部件更新
         */
        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = context.packageName?.let { 
                    android.content.ComponentName(it, ScheduleWidgetV5::class.java.name) 
                }
                
                if (componentName != null) {
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                    for (appWidgetId in appWidgetIds) {
                        updateAppWidget(context, appWidgetManager, appWidgetId)
                    }
                    Log.d(TAG, "更新了 ${appWidgetIds.size} 个小部件实例")
                }
            } catch (e: Exception) {
                Log.e(TAG, "更新所有小部件失败", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "小部件更新触发，共有 ${appWidgetIds.size} 个实例")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        Log.d(TAG, "删除了 ${appWidgetIds.size} 个小部件实例")
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "第一个小部件实例已添加")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d(TAG, "最后一个小部件实例已移除")
    }

    /**
     * 课程数据类
     */
    data class Course(
        val name: String,
        val time: String,
        val location: String,
        val className: String,
        val status: String = "upcoming", // upcoming, current, completed
        val isCurrent: Boolean = false
    )
}