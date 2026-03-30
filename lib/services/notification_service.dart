import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'teacher_schedule_channel';
  static const String _channelName = '课程提醒';
  static const String _channelDesc = '李老师日程提醒通知';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    // 请求通知权限（Android 13+）
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 创建通知渠道
  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF6C63FF),
        enableVibration: true,
        playSound: true,
      );

  // 立即发送通知
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: _androidDetails),
    );
  }

  // 安排每周重复通知（工作日 or 周末）
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays, // 1=周一,...,7=周日
  }) async {
    for (int i = 0; i < weekdays.length; i++) {
      final day = weekdays[i];
      final notifId = id * 10 + i;
      
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        _nextInstanceOfWeekday(hour, minute, day),
        NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // 取消通知
  Future<void> cancel(int id) async {
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(id * 10 + i);
    }
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfWeekday(int hour, int minute, int weekday) {
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != weekday ||
        scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // 根据作息安排所有课程提醒
  Future<void> scheduleAllClassReminders({
    required List<Map<String, dynamic>> periods,
    required List<int> weekdays,
    required int advanceMinutes,
    required bool isWeekday,
  }) async {
    // 先取消旧的
    for (int i = 100; i < 200; i++) {
      await _plugin.cancel(i);
    }

    int idBase = isWeekday ? 100 : 150;

    for (int i = 0; i < periods.length; i++) {
      final period = periods[i];
      int hour = period['hour'] as int;
      int minute = period['minute'] as int;

      // 计算提前时间
      int totalMinutes = hour * 60 + minute - advanceMinutes;
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      int notifHour = totalMinutes ~/ 60;
      int notifMinute = totalMinutes % 60;

      final String title = advanceMinutes > 0
          ? '${period['name']} 还有${advanceMinutes}分钟'
          : '${period['name']} 开始了';
      final String body =
          '${period['startTime']} - ${period['endTime']}，准备上课 📚';

      await scheduleWeeklyNotification(
        id: idBase + i,
        title: title,
        body: body,
        hour: notifHour,
        minute: notifMinute,
        weekdays: weekdays,
      );
    }
  }
}
