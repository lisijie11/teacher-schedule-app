import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../models/schedule_model.dart';
import 'package:intl/intl.dart';

/// 日历服务 - 一键将未来一周课程添加到系统日历
class CalendarService {
  CalendarService._();

  static final CalendarService instance = CalendarService._();

  /// 添加未来一周所有课程到日历
  /// 返回添加结果（成功数量，总课程数）
  Future<CalendarAddResult> addNextWeekCourses(List<CourseEntry> courses) async {
    if (courses.isEmpty) {
      return CalendarAddResult(added: 0, total: 0, errors: ['没有课程可添加']);
    }

    final now = DateTime.now();
    // 从今天开始，往后7天
    final weekDates = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    );

    int added = 0;
    int total = 0;
    final List<String> errors = [];

    for (final date in weekDates) {
      final weekday = date.weekday; // 1=周一，7=周日
      final periods = SchedulePresets.getPeriodsForWeekday(weekday);

      for (final period in periods) {
        // 找到该天该节次的课程
        final course = courses.where(
          (c) => c.weekday == weekday && c.periodIndex == period.index,
        ).toList();

        for (final c in course) {
          if (c.courseName.isEmpty) continue;
          total++;

          final startDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            period.startHour,
            period.startMinute,
          );
          final endDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            period.endHour,
            period.endMinute,
          );

          // 构造事件标题
          String title = c.courseName;
          if (c.note != null && c.note!.isNotEmpty) {
            title += ' (${c.note})';
          }

          // 地点
          final location = c.classroom.isNotEmpty ? c.classroom : null;

          // 课程描述
          final dateStr = DateFormat('M月d日').format(date);
          final weekdayStr = SchedulePresets.getModeShortLabel(weekday);
          final desc = '$weekdayStr $dateStr ${period.name}';
          final notes = [
            desc,
            if (c.note != null && c.note!.isNotEmpty) '班级：${c.note}',
            '上课时间：${period.startTime} - ${period.endTime}',
            if (c.classroom.isNotEmpty) '上课地点：${c.classroom}',
            '——由教师课表助手自动添加',
          ].join('\n');

          final event = Event(
            title: title,
            description: notes,
            location: location,
            startDate: startDateTime,
            endDate: endDateTime,
            allDay: false,
          );

          try {
            final success = await Add2Calendar.addEvent2Cal(event);
            if (success) {
              added++;
            }
          } catch (e) {
            errors.add('${c.courseName}: $e');
          }
        }
      }
    }

    return CalendarAddResult(
      added: added,
      total: total,
      errors: errors,
    );
  }

  /// 获取未来一周的课程统计信息
  String getNextWeekSummary(List<CourseEntry> courses) {
    if (courses.isEmpty) return '暂无课程';

    final now = DateTime.now();
    int total = 0;
    int withCourse = 0;

    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final weekday = date.weekday;
      final periods = SchedulePresets.getPeriodsForWeekday(weekday);
      total += periods.length;

      for (final period in periods) {
        final hasCourse = courses.any(
          (c) => c.weekday == weekday && c.periodIndex == period.index && c.courseName.isNotEmpty,
        );
        if (hasCourse) withCourse++;
      }
    }

    return '未来7天共 ${total}节，已有 ${withCourse}节 课程';
  }
}

/// 日历添加结果
class CalendarAddResult {
  final int added;
  final int total;
  final List<String> errors;

  CalendarAddResult({
    required this.added,
    required this.total,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  String get message {
    if (total == 0) return '没有找到可添加的课程';
    if (added == total) return '已成功添加 $added 节课程到日历 ✅';
    if (added == 0) return '添加失败，请检查日历权限';
    return '已添加 $added/$total 节课程到日历';
  }
}
