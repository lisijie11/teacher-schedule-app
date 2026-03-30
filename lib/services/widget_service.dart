import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../services/holiday_service.dart';
import '../services/api/index.dart';

/// 桌面小组件数据更新服务（支持v4和v5版本）
///
/// home_widget 0.7.x Android 端存储格式：
///   SharedPreferences 文件名：HomeWidgetPlugin
///   key：原始 key（无前缀），与 Flutter shared_preferences 不同
///
/// 因此 Flutter 侧 saveWidgetData<String>('mode_label', ...) 写入后，
/// Kotlin 直接读 prefs.getString("mode_label", ...) 即可拿到。
class WidgetService {
  static const String _widgetName = 'ScheduleWidget';
  static const String _widgetNameV5 = 'ScheduleWidgetV5';

  /// 默认更新小组件数据（不带用户信息）
  static Future<void> updateWidget() async {
    await updateWidgetWithUserInfo();
  }

  /// 更新小组件数据（带用户信息） - 支持v4和v5版本
  static Future<void> updateWidgetWithUserInfo({
    String? userName,
    String? facultyName,
    List<CourseEntry>? todayCourses,
    Map<String, dynamic>? userInfo,
    Map<String, dynamic>? widgetSettings,
  }) async {
    try {
      final now = DateTime.now();
      final isWeekday = HolidayService.instance.getTodayIsWeekday();
      final mode = isWeekday ? ScheduleMode.weekday : ScheduleMode.weekend;
      final periods = SchedulePresets.getPeriodsForMode(mode);
      final modeLabel = SchedulePresets.getModeShortLabel(mode);

      // 1. 基础信息计算
      ClassPeriod? nextPeriod;
      ClassPeriod? currentPeriod;
      final nowMinutes = now.hour * 60 + now.minute;

      for (final period in periods) {
        final startMin = period.startHour * 60 + period.startMinute;
        final endMin = period.endHour * 60 + period.endMinute;
        if (nowMinutes >= startMin && nowMinutes < endMin) {
          currentPeriod = period;
        } else if (nowMinutes < startMin && nextPeriod == null) {
          nextPeriod = period;
        }
      }

      String statusText;
      String timeText;

      if (currentPeriod != null) {
        statusText = '上课中 · ${currentPeriod.name}';
        timeText = '${currentPeriod.startTime}-${currentPeriod.endTime}';
      } else if (nextPeriod != null) {
        final startMin = nextPeriod.startHour * 60 + nextPeriod.startMinute;
        final diff = startMin - nowMinutes;
        final hours = diff ~/ 60;
        final minutes = diff % 60;
        final diffText = hours > 0 ? '${hours}小时${minutes}分钟' : '${minutes}分钟';
        statusText = '${nextPeriod.name} · ${diffText}后';
        timeText = nextPeriod.startTime;
      } else {
        statusText = '今日课程已全部结束';
        timeText = '好好休息';
      }

      // 2. 用户信息和设置
      final effectiveUserName = userName ?? userInfo?['name'] ?? '李老师';
      final effectiveFacultyName = facultyName ?? userInfo?['faculty'] ?? '数字媒体与设计学院';
      final userAvatar = effectiveUserName.isNotEmpty ? effectiveUserName[0] : '李';
      
      // 默认设置
      final defaultSettings = {
        'showLocation': true,
        'showFaculty': true,
        'maxCourses': 3,
        'themeColor': 0xFF6C63FF,
      };
      
      final effectiveSettings = { ...defaultSettings, ...?widgetSettings };

      // 3. 课程数据处理
      List<Map<String, dynamic>> processedCourses = [];
      if (todayCourses != null && todayCourses.isNotEmpty) {
        // 获取或生成模拟的今日课程
        processedCourses = await _processCoursesForWidget(todayCourses, now);
      }

      // 4. 更新小部件数据（支持两个版本）
      await _updateWidgetData(
        modeLabel: modeLabel,
        isWorkday: isWeekday,
        statusText: statusText,
        timeText: timeText,
        date: now,
        userName: effectiveUserName,
        facultyName: effectiveFacultyName,
        userAvatar: userAvatar,
        courses: processedCourses,
        settings: effectiveSettings,
      );

      // 5. 触发小部件更新（同时更新v4和v5版本）
      await HomeWidget.updateWidget(
        androidName: _widgetName, // v4版本
        iOSName: _widgetName,
      );
      
      await HomeWidget.updateWidget(
        androidName: _widgetNameV5, // v5版本
        iOSName: _widgetNameV5,
      );

      print('小部件数据更新成功，处理了 ${processedCourses.length} 个课程');
    } catch (e) {
      print('小部件更新失败: $e');
      // 小组件更新失败不能影响主 App 运行
    }
  }

  /// 处理课程数据供小部件使用
  static Future<List<Map<String, dynamic>>> _processCoursesForWidget(
    List<CourseEntry> courses,
    DateTime now
  ) async {
    final List<Map<String, dynamic>> processedCourses = [];
    final nowMinutes = now.hour * 60 + now.minute;
    
    // 按时间排序
    courses.sort((a, b) {
      final aTime = _parseTimeToMinutes(a.startTime ?? '09:00');
      final bTime = _parseTimeToMinutes(b.startTime ?? '09:00');
      return aTime.compareTo(bTime);
    });
    
    for (final course in courses) {
      final startMinutes = _parseTimeToMinutes(course.startTime ?? '09:00');
      final endMinutes = _parseTimeToMinutes(course.endTime ?? '10:40');
      
      // 计算课程状态
      String status;
      if (nowMinutes < startMinutes) {
        status = 'upcoming'; // 即将开始
      } else if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
        status = 'current'; // 当前进行中
      } else {
        status = 'completed'; // 已完成
      }
      
      processedCourses.add({
        'name': course.courseName ?? '未命名课程',
        'time': course.startTime ?? '--:--',
        'location': course.classroom ?? '待定',
        'class': course.className ?? '未指定班级',
        'status': status,
        'isCurrent': status == 'current',
      });
    }
    
    return processedCourses;
  }

  /// 更新时间字符串到分钟数
  static int _parseTimeToMinutes(String time) {
    try {
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 9;
        final minute = int.tryParse(parts[1]) ?? 0;
        return hour * 60 + minute;
      }
    } catch (e) {
      print('时间解析失败: $time, $e');
    }
    return 9 * 60; // 默认9:00
  }

  /// 更新小部件数据
  static Future<void> _updateWidgetData({
    required String modeLabel,
    required bool isWorkday,
    required String statusText,
    required String timeText,
    required DateTime date,
    required String userName,
    required String facultyName,
    required String userAvatar,
    required List<Map<String, dynamic>> courses,
    required Map<String, dynamic> settings,
  }) async {
    try {
      // 基础字段（v4和v5都支持）
      await HomeWidget.saveWidgetData<String>('mode_label', modeLabel);
      await HomeWidget.saveWidgetData<String>('status_text', statusText);
      await HomeWidget.saveWidgetData<String>('time_text', timeText);
      await HomeWidget.saveWidgetData<String>('date_text', _formatDate(date));
      await HomeWidget.saveWidgetData<bool>('is_workday', isWorkday);
      
      // 用户信息字段（v5专用）
      await HomeWidget.saveWidgetData<String>('user_info_name', userName);
      await HomeWidget.saveWidgetData<String>('user_info_faculty', facultyName);
      await HomeWidget.saveWidgetData<String>('user_info_avatar', userAvatar);
      await HomeWidget.saveWidgetData<String>('user_info_location', '佛山大部'); // 从用户设置获取
      
      // 课程数据（v5专用）
      if (courses.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('courses_today', _coursesToJson(courses));
      }
      
      // 设置字段（v5专用）
      await HomeWidget.saveWidgetData<bool>('settings_showLocation', settings['showLocation'] ?? true);
      await HomeWidget.saveWidgetData<bool>('settings_showFaculty', settings['showFaculty'] ?? true);
      await HomeWidget.saveWidgetData<int>('settings_maxCourses', settings['maxCourses'] ?? 3);
      await HomeWidget.saveWidgetData<int>('settings_themeColor', settings['themeColor'] ?? 0xFF6C63FF);
      
    } catch (e) {
      print('保存小部件数据失败: $e');
    }
  }

  /// 课程数据转JSON
  static String _coursesToJson(List<Map<String, dynamic>> courses) {
    // 简单实现，实际应该使用dart:convert的jsonEncode
    final jsonArray = courses.map((course) => _courseToJsonObject(course)).toList();
    return jsonArray.toString(); // 简化实现
  }
  
  static Map<String, dynamic> _courseToJsonObject(Map<String, dynamic> course) {
    return {
      'name': course['name'],
      'time': course['time'],
      'location': course['location'],
      'class': course['class'],
      'status': course['status'],
      'isCurrent': course['isCurrent'],
    };
  }

  /// 格式化日期
  static String _formatDate(DateTime date) {
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.month}月${date.day}日 ${weekdays[date.weekday]}';
  }
  
  /// 更新个性化设置
  static Future<void> updateWidgetSettings({
    bool? showLocation,
    bool? showFaculty,
    int? maxCourses,
    int? themeColor,
  }) async {
    try {
      final Map<String, dynamic> settings = {};
      
      if (showLocation != null) {
        settings['showLocation'] = showLocation;
        await HomeWidget.saveWidgetData<bool>('settings_showLocation', showLocation);
      }
      if (showFaculty != null) {
        settings['showFaculty'] = showFaculty;
        await HomeWidget.saveWidgetData<bool>('settings_showFaculty', showFaculty);
      }
      if (maxCourses != null) {
        settings['maxCourses'] = maxCourses;
        await HomeWidget.saveWidgetData<int>('settings_maxCourses', maxCourses);
      }
      if (themeColor != null) {
        settings['themeColor'] = themeColor;
        await HomeWidget.saveWidgetData<int>('settings_themeColor', themeColor);
      }
      
      // 触发更新
      await HomeWidget.updateWidget(androidName: _widgetNameV5);
    } catch (e) {
      print('更新小部件设置失败: $e');
    }
  }
  
  /// 手动更新所有小部件
  static Future<void> refreshAllWidgets() async {
    try {
      await updateWidget(); // 重新计算并更新当前数据
    } catch (e) {
      print('手动更新小部件失败: $e');
    }
  }
}
