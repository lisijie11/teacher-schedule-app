import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../models/todo_model.dart';

// Android 原生通道
const _nativeChannel = MethodChannel('com.lisijie.teacher_schedule/schedule_data');
const _widgetChannel = MethodChannel('com.lisijie.teacher_schedule/widget_data');

/// 桌面小组件数据更新服务
///
/// 参照 mikcb 方案：Flutter 写 JSON snapshot → Kotlin 解析 → RemoteViews 渲染
/// 自动刷新：使用 Android WorkManager（每15分钟，低功耗）
class WidgetService {
  static DateTime? _lastUpdateTime;

  /// 初始化自动刷新机制
  /// 通过 WorkManager 实现低功耗后台刷新（每15分钟）
  static void initAutoRefresh() {
    _startGlobalRefresh();
    print('[WidgetService] 自动刷新已启动（WorkManager 每15分钟）');
  }

  /// 启动全局刷新（WorkManager）
  static Future<void> _startGlobalRefresh() async {
    try {
      await _widgetChannel.invokeMethod('startGlobalRefresh');
      print('[WidgetService] WorkManager 全局刷新已启动');
    } catch (e) {
      print('[WidgetService] 启动全局刷新失败: $e');
    }
  }

  /// 停止全局刷新
  static Future<void> stopAutoRefresh() async {
    try {
      await _widgetChannel.invokeMethod('stopGlobalRefresh');
      print('[WidgetService] WorkManager 全局刷新已停止');
    } catch (e) {
      print('[WidgetService] 停止全局刷新失败: $e');
    }
  }

  /// 课程数据变化时调用（带防抖）
  static Future<void> onCourseDataChanged() async {
    final now = DateTime.now();
    if (_lastUpdateTime != null &&
        now.difference(_lastUpdateTime!) < const Duration(seconds: 5)) {
      return;
    }
    _lastUpdateTime = now;
    await updateWidget();
  }

  /// 更新小组件数据（核心逻辑）
  static Future<void> updateWidget() async {
    try {
      final now = DateTime.now();
      final todayWeekday = now.weekday;
      final nowMinutes = now.hour * 60 + now.minute;

      // ── 日期文字 ──
      final weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final dateText = '${now.month}月${now.day}日 ${weekdays[now.weekday]}';

      // ── 作息表 ──
      final periods = SchedulePresets.getPeriodsForWeekday(todayWeekday);
      final box = Hive.box<CourseEntry>('courses');

      // ── 查找当前和下一节有课程的时间段 ──
      ClassPeriod? currentPeriod;
      ClassPeriod? nextPeriod;
      CourseEntry? currentCourse;
      CourseEntry? nextCourse;

      // 遍历所有时间段，找到当前正在上课的时间段
      for (final period in periods) {
        final startMin = period.startHour * 60 + period.startMinute;
        final endMin = period.endHour * 60 + period.endMinute;

        if (nowMinutes >= startMin && nowMinutes < endMin) {
          // 当前时间段
          final course = _getCourseForPeriod(box, todayWeekday, period.index);
          if (course != null && course.courseName.isNotEmpty) {
            currentPeriod = period;
            currentCourse = course;
            break; // 找到了，退出循环
          }
        }
      }

      // 如果当前没有课程，查找下一节有课程的时间段
      if (currentPeriod == null) {
        for (final period in periods) {
          final startMin = period.startHour * 60 + period.startMinute;

          if (nowMinutes < startMin) {
            final course = _getCourseForPeriod(box, todayWeekday, period.index);
            if (course != null && course.courseName.isNotEmpty) {
              nextPeriod = period;
              nextCourse = course;
              break; // 找到了，退出循环
            }
          }
        }
      }

      // ── 构建所有课程列表 ──
      final allCoursesJson = <Map<String, dynamic>>[];
      for (final period in periods) {
        final startMin = period.startHour * 60 + period.startMinute;
        final endMin = period.endHour * 60 + period.endMinute;
        final isActive = currentPeriod != null && currentPeriod.index == period.index;
        final isUpcoming = nextPeriod != null && nextPeriod.index == period.index;
        final isPast = nowMinutes >= endMin;

        final course = _getCourseForPeriod(box, todayWeekday, period.index);
        final name = course?.courseName ?? period.name;
        final loc = (course?.classroom ?? '').isNotEmpty ? course!.classroom : '';

        String status;
        if (isPast) {
          status = 'completed';
        } else if (isActive) {
          status = 'ongoing';
        } else if (isUpcoming) {
          status = 'upcoming';
        } else {
          status = '';
        }

        allCoursesJson.add({
          'id': 'p${period.index}',
          'name': name,
          'location': loc,
          'startTime': period.startTime,
          'endTime': period.endTime,
          'status': status,
        });
      }

      // ── 确定状态 ──
      String state;
      Map<String, dynamic>? highlightCourseJson;
      Map<String, dynamic>? tomorrowCourseJson; // 明天课程信息（今日完成后显示）

      if (currentPeriod != null && currentCourse != null) {
        // 正在上课
        state = 'ongoing';
        final startMin = currentPeriod.startHour * 60 + currentPeriod.startMinute;
        final endMin = currentPeriod.endHour * 60 + currentPeriod.endMinute;
        final elapsed = nowMinutes - startMin;
        final total = endMin - startMin;
        final progress = total > 0 ? ((elapsed * 100) / total).round() : 0;

        highlightCourseJson = {
          'id': 'p${currentPeriod.index}',
          'name': currentCourse.courseName,
          'location': currentCourse.classroom,
          'startTime': currentPeriod.startTime,
          'endTime': currentPeriod.endTime,
          'status': 'ongoing',
          'progress': progress,
          'section': currentPeriod.name,
        };
      } else if (nextPeriod != null && nextCourse != null) {
        // 即将上课
        state = 'upcoming';
        highlightCourseJson = {
          'id': 'p${nextPeriod.index}',
          'name': nextCourse.courseName,
          'location': nextCourse.classroom,
          'startTime': nextPeriod.startTime,
          'endTime': nextPeriod.endTime,
          'status': 'upcoming',
          'progress': 0,
          'section': nextPeriod.name,
        };
      } else if (periods.isNotEmpty && nowMinutes >= (periods.last.endHour * 60 + periods.last.endMinute)) {
        state = 'completed';
        // 获取明天课程信息
        final tomorrowWeekday = todayWeekday == 7 ? 1 : todayWeekday + 1;
        final tomorrowPeriods = SchedulePresets.getPeriodsForWeekday(tomorrowWeekday);
        final tomorrowCourses = <Map<String, dynamic>>[];

        for (final period in tomorrowPeriods) {
          final course = _getCourseForPeriod(box, tomorrowWeekday, period.index);
          if (course != null && course.courseName.isNotEmpty) {
            final timePart = period.index <= 4 ? 'morning' : 'afternoon';
            tomorrowCourses.add({
              'period': period.index,
              'periodName': period.name,
              'courseName': course.courseName,
              'classroom': course.classroom,
              'timePart': timePart,
            });
          }
        }

        // 计算明天日期
        final tomorrowDate = now.add(const Duration(days: 1));
        final weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final weekdayName = weekdays[tomorrowDate.weekday];

        int morningCount = tomorrowCourses.where((c) => c['timePart'] == 'morning').length;
        int afternoonCount = tomorrowCourses.where((c) => c['timePart'] == 'afternoon').length;

        tomorrowCourseJson = {
          'weekday': tomorrowWeekday,
          'weekdayName': weekdayName,
          'month': tomorrowDate.month,
          'day': tomorrowDate.day,
          'totalCount': tomorrowCourses.length,
          'morningCount': morningCount,
          'afternoonCount': afternoonCount,
          'courses': tomorrowCourses,
        };

        highlightCourseJson = null;
      } else {
        state = 'no_course';
        highlightCourseJson = null;
      }

      // ── 构建 4天×8节 色块表格数据（用于 4×4 大号组件）──
      final gridData = <Map<String, dynamic>>[];
      for (int dayOffset = 0; dayOffset < 4; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        final targetWeekday = targetDate.weekday;
        final dayLabel = '${targetDate.month}/${targetDate.day}';
        final weekdayLabel = ['周一','周二','周三','周四','周五','周六','周日'][targetWeekday - 1];
        final isToday = dayOffset == 0;

        // 该天的所有课程（按 weekday 和 periodIndex 查找）
        // periodIndex 是大节次编号 1-4（1=第1-2节, 2=第3-4节, 3=第5-6节, 4=第7-8节）
        final dayCourses = <Map<String, dynamic>>[];
        for (int periodIdx = 1; periodIdx <= 4; periodIdx++) {
          final course = _getCourseForPeriod(box, targetWeekday, periodIdx);
          dayCourses.add({
            'period': periodIdx,
            'name': course?.courseName ?? '',
            'color': course?.colorIndex ?? -1, // -1 表示空课
          });
        }
        gridData.add({
          'date': dayLabel,
          'weekday': weekdayLabel,
          'isToday': isToday,
          'courses': dayCourses,
        });
      }

      // ── 构建 snapshot JSON ──
      final snapshot = {
        'date': dateText,
        'state': state,
        'highlightCourse': highlightCourseJson,
        'tomorrowCourse': tomorrowCourseJson, // 明日课程信息（今日完成后显示）
        'allCourses': allCoursesJson,
        'totalCourseCount': allCoursesJson.length,
        'gridData': gridData,
      };

      final snapshotJson = jsonEncode(snapshot);

      // ── 写入 HomeWidgetPlugin SharedPreferences ──
      try {
        await _widgetChannel.invokeMethod('saveWidgetData', {
          'key': 'snapshot_json',
          'value': snapshotJson,
        });
        print('[WidgetService] snapshot 已写入: $dateText state=$state highlight=${highlightCourseJson?['name']}');
      } catch (e) {
        print('[WidgetService] 写入 snapshot 失败: $e');
      }

      // ── 同步待办事项数据到原生端（供待办小部件使用）──
      await _saveTodoDataToNative();

      // ── 同步作息表 + 课程数据到原生端 ──
      await _saveAllCoursesToNative();

      // ── 触发所有小组件刷新 ──
      await _updateAllWidgets();

      print('[WidgetService] 更新成功: $dateText | state=$state | courses=${allCoursesJson.length}');
    } catch (e, st) {
      print('[WidgetService] 更新失败: $e\n$st');
    }
  }

  /// 获取某天某节次的课程
  static CourseEntry? _getCourseForPeriod(
      Box<CourseEntry> box, int weekday, int periodIndex) {
    try {
      return box.values.firstWhere(
        (c) => c.weekday == weekday && c.periodIndex == periodIndex,
      );
    } catch (_) {
      return null;
    }
  }

  /// 触发 Android 小组件刷新
  static Future<void> _updateAllWidgets() async {
    try {
      await _widgetChannel.invokeMethod('updateWidget', {'widgetName': 'all'});
      print('[WidgetService] 小组件刷新已触发');
    } catch (e) {
      print('[WidgetService] 触发刷新失败: $e');
    }
  }

  /// 手动刷新（设置页面调用）
  static Future<void> refreshWidget() async {
    await updateWidget();
  }

  /// 把作息表 + 全量课程写入原生 SharedPreferences
  static Future<void> _saveAllCoursesToNative() async {
    try {
      final now = DateTime.now();
      final todayWeekday = now.weekday;
      final periods = SchedulePresets.getPeriodsForWeekday(todayWeekday);

      final periodsData = periods.map((p) => {
        'index': p.index,
        'sh': p.startHour,
        'sm': p.startMinute,
        'eh': p.endHour,
        'em': p.endMinute,
        'name': p.name,
        'startTime': p.startTime,
        'endTime': p.endTime,
      }).toList();

      final box = Hive.box<CourseEntry>('courses');
      final coursesData = box.values.map((c) => {
        'weekday': c.weekday,
        'periodIndex': c.periodIndex,
        'courseName': c.courseName,
        'classroom': c.classroom,
      }).toList();

      final json = jsonEncode({
        'weekday': todayWeekday,
        'periods': periodsData,
        'courses': coursesData,
      });

      try {
        await _nativeChannel.invokeMethod('saveScheduleData', {'json': json});
      } catch (_) {}
    } catch (e) {
      print('[WidgetService] 同步失败: $e');
    }
  }

  /// 把待办事项数据写入原生 SharedPreferences（供待办小部件使用）
  static Future<void> _saveTodoDataToNative() async {
    try {
      final todoBox = Hive.box<TodoItem>('todos');
      final allTodos = todoBox.values.toList();
      final pending = allTodos.where((t) => !t.isDone).toList();
      final doneCount = allTodos.where((t) => t.isDone).length;
      final total = allTodos.length;
      final progress = total == 0 ? 0.0 : doneCount / total;

      // 取前5条未完成待办
      final topPending = pending.take(5).map((t) => {
        'title': t.title,
        'priority': t.priority,
      }).toList();

      final json = jsonEncode({
        'totalCount': total,
        'doneCount': doneCount,
        'pendingCount': pending.length,
        'progress': progress,
        'items': topPending,
      });

      await _widgetChannel.invokeMethod('saveWidgetData', {
        'key': 'todo_json',
        'value': json,
      });
      print('[WidgetService] 待办数据已写入: ${pending.length}待办 ${doneCount}完成');
    } catch (e) {
      print('[WidgetService] 写入待办数据失败: $e');
    }
  }
}
