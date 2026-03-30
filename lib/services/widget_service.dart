import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/schedule_model.dart';
import '../services/holiday_service.dart';

class WidgetService {
  static const String _appGroupId = 'com.lisijie.teacher_schedule';
  static const String _widgetName = 'ScheduleWidget';

  static Future<void> updateWidget() async {
    final now = DateTime.now();
    final isWeekday = HolidayService.instance.getTodayIsWeekday();
    final mode = isWeekday ? ScheduleMode.weekday : ScheduleMode.weekend;
    final periods = SchedulePresets.getPeriodsForMode(mode);
    final modeLabel = SchedulePresets.getModeShortLabel(mode);

    // 找下一节课
    ClassPeriod? nextPeriod;
    ClassPeriod? currentPeriod;
    final nowMinutes = now.hour * 60 + now.minute;

    for (final period in periods) {
      final startMin = period.startHour * 60 + period.startMinute;
      final endMin = period.endHour * 60 + period.endMinute;

      if (nowMinutes >= startMin && nowMinutes < endMin) {
        currentPeriod = period;
        break;
      }
      if (nowMinutes < startMin && nextPeriod == null) {
        nextPeriod = period;
      }
    }

    String statusText;
    String timeText;

    if (currentPeriod != null) {
      statusText = '上课中 · ${currentPeriod.name}';
      timeText = '${currentPeriod.startTime} - ${currentPeriod.endTime}';
    } else if (nextPeriod != null) {
      final startMin = nextPeriod.startHour * 60 + nextPeriod.startMinute;
      final diff = startMin - nowMinutes;
      statusText = '下节: ${nextPeriod.name}（${diff}分钟后）';
      timeText = nextPeriod.startTime;
    } else {
      statusText = '今日课程已结束';
      timeText = '明天见 ✨';
    }

    await HomeWidget.saveWidgetData<String>('mode_label', modeLabel);
    await HomeWidget.saveWidgetData<String>('status_text', statusText);
    await HomeWidget.saveWidgetData<String>('time_text', timeText);
    await HomeWidget.saveWidgetData<String>(
        'date_text', _formatDate(now));

    await HomeWidget.updateWidget(
      androidName: _widgetName,
      iOSName: _widgetName,
      qualifiedAndroidName: '$_appGroupId.$_widgetName',
    );
  }

  static String _formatDate(DateTime date) {
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.month}月${date.day}日 ${weekdays[date.weekday]}';
  }
}
