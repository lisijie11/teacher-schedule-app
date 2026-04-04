import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/course_model.dart';
import '../models/schedule_model.dart';
import 'package:intl/intl.dart';

/// 日历服务 - 一键将未来一周课程添加到系统日历
///
/// **设计思路（手机日程逻辑）**：
/// 手机日历的核心价值是「提醒」和「占位」，而非精确的时间块。
/// 如果依赖 SchedulePresets 作息时间写入 start/end，一旦用户 Hive 中
/// 残留旧版脏数据，就会出现"晚上上课"的荒谬时间。
///
/// 因此采用**全天事件 + 描述中写明具体时间**的模式：
/// - 事件设为 allDay=true → 日历中显示为当天待办，不会出现在错误时间段
/// - 具体时间写在 description 里 + 备注/提醒中
/// - 仍然保留提前15分钟的系统提醒（allDay 事件也支持 reminder）
/// - 用户打开事件详情能看到完整信息：第几节课、几点到几点、哪里上课
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
      useSafeArea: true, // 确保安全区生效
      isScrollControlled: true, // 允许控制高度
      builder: (context) => _CalendarPickerSheet(calendars: calendars),
    );
  }

  /// 添加未来一周所有课程到指定日历
  ///
  /// **按天合并**：同一天的所有课程合并为 **1 个全天事件**
  /// - 标题：「📚 周X 课程 (N节)」
  /// - 描述中按时间顺序列出每节课：第几节、课程名、时间、地点
  /// - allDay = true → 不依赖作息时间的正确性
  /// - reminder 提前15分钟（提醒当天第一节课）
  Future<CalendarAddResult> addNextWeekCoursesTo(
    String calendarId,
    List<CourseEntry> courses,
  ) async {
    if (courses.isEmpty) {
      return CalendarAddResult(added: 0, total: 0, errors: ['没有课程可添加']);
    }

    _ensureTzInitialized();
    await SchedulePresets.init();

    final now = DateTime.now();
    final weekDates = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    );

    int added = 0;
    int totalCourses = 0;
    final List<String> errors = [];

    for (final date in weekDates) {
      final weekday = date.weekday;
      final periods = SchedulePresets.getPeriodsForWeekday(weekday);
      final weekdayStr = getWeekdayName(weekday);
      final dateStr = DateFormat('M月d日').format(date);

      // 收集当天有课的节次（已按 periods 顺序排列）
      final dayCourses = <_DayCourseEntry>[];
      for (final period in periods) {
        final matched = courses.where(
          (c) => c.weekday == weekday && c.periodIndex == period.index && c.courseName.isNotEmpty,
        ).toList();
        for (final c in matched) {
          dayCourses.add(_DayCourseEntry(period: period, course: c));
          totalCourses++;
        }
      }

      if (dayCourses.isEmpty) continue; // 当天没课，跳过

      // ===== 当天只创建 1 个全天事件 =====
      final nextDay = date.add(const Duration(days: 1));
      final eventStart = tz.TZDateTime(tz.local, date.year, date.month, date.day);
      final eventEnd = tz.TZDateTime(tz.local, nextDay.year, nextDay.month, nextDay.day);

      // 标题：周X 课程
      final courseNames = dayCourses.map((dc) => dc.course.courseName).join('、');
      final title = '$weekdayStr: $courseNames';

      // 描述：简洁的时间列表
      final descLines = <String>[];
      for (final dc in dayCourses) {
        final p = dc.period;
        final c = dc.course;
        descLines.add('${c.courseName}  ${p.startTime}-${p.endTime}');
      }
      final description = descLines.join('\n');

      // 取第一节课的地点作为事件地点（日历卡片上显示）
      final location = dayCourses.first.course.classroom.isNotEmpty
          ? dayCourses.first.course.classroom
          : null;

      final event = Event(
        calendarId,
        title: title,
        description: description,
        location: location,
        start: eventStart,
        end: eventEnd,
        allDay: true,
        reminders: [Reminder(minutes: 15)],
      );

      try {
        final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
        if (result?.isSuccess == true) {
          added++;
        } else {
          errors.add('$weekdayStr: ${result?.errors?.join(", ") ?? "未知错误"}');
        }
      } catch (e) {
        errors.add('$weekdayStr: $e');
      }
    }

    return CalendarAddResult(
      added: added,
      total: totalCourses,
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
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
            ...calendars.map((cal) {
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
            }),
            // 底部安全区
            SizedBox(height: bottomPadding + 16),
          ],
        ),
      ),
    );
  }
}

/// 当天课程条目（节次 + 课程信息的组合）
class _DayCourseEntry {
  final ClassPeriod period;
  final CourseEntry course;
  _DayCourseEntry({required this.period, required this.course});
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
    if (added == total && added <= 7) return '已成功将 $added 天课程写入日历 ✅';
    if (added == total) return '已成功将 $added 天（共 $total 节课）写入日历 ✅';
    if (added == 0) return '添加失败，请检查日历权限';
    return '已添加 $added 天课程到日历';
  }
}
