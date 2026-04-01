import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/course_model.dart';
import '../models/schedule_model.dart';
import 'package:intl/intl.dart';

/// 日历服务 - 一键将未来一周课程添加到系统日历
/// 使用 device_calendar 直接批量写入，无需逐个弹窗
class CalendarService {
  CalendarService._();

  static final CalendarService instance = CalendarService._();

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  /// 初始化时区数据
  bool _tzInitialized = false;
  void _ensureTzInitialized() {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// 请求日历权限
  Future<bool> requestPermissions() async {
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && (permissionsGranted.data ?? false)) {
      return true;
    }

    permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
    return permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
  }

  /// 获取所有日历列表
  Future<List<Calendar>> getCalendars() async {
    final result = await _deviceCalendarPlugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return [];
    return result.data!.where((cal) => !cal.isReadOnly!).toList();
  }

  /// 获取默认日历（第一个可写的）
  Future<Calendar?> getDefaultCalendar() async {
    final calendars = await getCalendars();
    if (calendars.isEmpty) return null;
    // 优先找"日历"或"个人"相关的默认日历
    final defaultCal = calendars.firstWhere(
      (cal) => cal.name?.contains('日历') == true || cal.isDefault == true,
      orElse: () => calendars.first,
    );
    return defaultCal;
  }

  /// 显示日历选择对话框
  Future<Calendar?> showCalendarPicker(BuildContext context) async {
    final calendars = await getCalendars();
    if (calendars.isEmpty) {
      return null;
    }

    return showModalBottomSheet<Calendar>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CalendarPickerSheet(calendars: calendars),
    );
  }

  /// 添加未来一周所有课程到指定日历
  Future<CalendarAddResult> addNextWeekCoursesTo(
    String calendarId,
    List<CourseEntry> courses,
  ) async {
    if (courses.isEmpty) {
      return CalendarAddResult(added: 0, total: 0, errors: ['没有课程可添加']);
    }

    _ensureTzInitialized();

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
        final matchedCourses = courses.where(
          (c) => c.weekday == weekday && c.periodIndex == period.index,
        ).toList();

        for (final c in matchedCourses) {
          if (c.courseName.isEmpty) continue;
          total++;

          // 构造事件
          final startTz = tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day,
            period.startHour,
            period.startMinute,
          );
          final endTz = tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day,
            period.endHour,
            period.endMinute,
          );

          // 课程标题
          String title = c.courseName;
          if (c.note != null && c.note!.isNotEmpty) {
            title += ' (${c.note})';
          }

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
            calendarId,
            title: title,
            description: notes,
            location: c.classroom.isNotEmpty ? c.classroom : null,
            start: startTz,
            end: endTz,
            allDay: false,
            reminders: [Reminder(minutes: 15)], // 默认提前15分钟提醒
          );

          try {
            final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
            if (result?.isSuccess == true) {
              added++;
            } else {
              errors.add('${c.courseName}: ${result?.errors?.join(", ") ?? "未知错误"}');
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

/// 日历选择底部弹窗
class _CalendarPickerSheet extends StatelessWidget {
  final List<Calendar> calendars;

  const _CalendarPickerSheet({required this.calendars});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖动条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  '选择日历',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${calendars.length} 个日历',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          // 日历列表
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: calendars.length,
            itemBuilder: (context, index) {
              final cal = calendars[index];
              final isDefault = cal.isDefault == true;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  cal.name ?? '未知日历',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: cal.accountName != null
                    ? Text(
                        cal.accountName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      )
                    : null,
                trailing: isDefault
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '默认',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.pop(context, cal),
              );
            },
          ),
          // 底部安全区
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
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
