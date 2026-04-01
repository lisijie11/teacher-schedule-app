import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // 通知渠道ID
  static const String _channelIdClass = 'class_reminder';
  static const String _channelIdProgress = 'class_progress';
  static const String _channelIdWeek = 'week_summary';
  
  // 通知ID
  static const int _progressNotificationId = 9999;
  
  // 定时器
  Timer? _progressTimer;

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
    
    // 创建通知渠道
    await _createNotificationChannels();
  }
  
  /// 创建通知渠道
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;
    
    // 课程提醒渠道
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelIdClass,
        '课程提醒',
        description: '上课前提醒通知',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    
    // 课程进度渠道 - 常驻通知
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelIdProgress,
        '课程进度',
        description: '实时显示当前课程进度',
        importance: Importance.low, // 低重要性，不打扰用户
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    
    // 周总结渠道
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelIdWeek,
        '周总结',
        description: '每周课程总结',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // 课程提醒通知详情
  AndroidNotificationDetails get _classDetails =>
      const AndroidNotificationDetails(
        _channelIdClass,
        '课程提醒',
        channelDescription: '上课前提醒通知',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF1D9BF0), // 小米蓝
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ticker: '课程提醒',
        showWhen: true,
        timeoutAfter: 3600000,
        fullScreenIntent: true,
        ongoing: false,
        autoCancel: true,
      );

  /// 显示课程提醒通知
  Future<void> showClassReminder({
    required int id,
    required String title,
    required String body,
    required String courseName,
    required String timeRange,
    required String location,
  }) async {
    // 使用大文本样式显示更多信息
    final bigTextStyle = BigTextStyleInformation(
      '$body\n📍 $location',
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: '📚 $courseName',
    );
    
    final androidDetails = AndroidNotificationDetails(
      _channelIdClass,
      '课程提醒',
      channelDescription: '上课前提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1D9BF0),
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '课程提醒',
      showWhen: true,
      timeoutAfter: 3600000,
      fullScreenIntent: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: bigTextStyle,
      // 添加操作按钮
      actions: [
        const AndroidNotificationAction(
          'dismiss',
          '我知道了',
          showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// 显示/更新课程进度通知（常驻通知栏）
  Future<void> showClassProgress({
    required String courseName,
    required String timeRange,
    required String location,
    required int progressPercent, // 0-100
    required String remainingTime,
    required bool isActive, // 是否正在上课
  }) async {
    // 构建进度条样式
    final progressStyle = AndroidNotificationDetails(
      _channelIdProgress,
      '课程进度',
      channelDescription: '实时显示当前课程进度',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1D9BF0),
      enableVibration: false,
      playSound: false,
      showWhen: false,
      ongoing: true, // 常驻通知
      autoCancel: false, // 不可滑动取消
      onlyAlertOnce: true, // 只提醒一次
      // 进度条
      showProgress: true,
      maxProgress: 100,
      progress: progressPercent,
      indeterminate: false,
      // 使用大文本显示更多信息
      styleInformation: BigTextStyleInformation(
        isActive 
          ? '⏱️ 剩余 $remainingTime  |  📍 $location'
          : '⏱️ 还有 $remainingTime 开始  |  📍 $location',
        htmlFormatBigText: false,
        contentTitle: isActive 
          ? '🔵 正在上课：$courseName'
          : '⏳ 即将开始：$courseName',
        htmlFormatContentTitle: false,
        summaryText: timeRange,
      ),
    );

    await _plugin.show(
      _progressNotificationId,
      isActive ? '🔵 正在上课：$courseName' : '⏳ 即将开始：$courseName',
      isActive 
        ? '⏱️ 剩余 $remainingTime  |  📍 $location'
        : '⏱️ 还有 $remainingTime 开始  |  📍 $location',
      NotificationDetails(android: progressStyle),
    );
  }

  /// 取消课程进度通知
  Future<void> hideClassProgress() async {
    await _plugin.cancel(_progressNotificationId);
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// 启动课程进度跟踪
  void startClassProgressTracking({
    required String courseName,
    required String timeRange,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    _progressTimer?.cancel();
    
    // 立即显示一次
    _updateProgress(courseName, timeRange, location, startTime, endTime);
    
    // 每秒更新一次
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateProgress(courseName, timeRange, location, startTime, endTime);
    });
  }

  /// 更新进度通知
  void _updateProgress(
    String courseName,
    String timeRange,
    String location,
    DateTime startTime,
    DateTime endTime,
  ) {
    final now = DateTime.now();
    final totalDuration = endTime.difference(startTime).inSeconds;
    
    if (now.isBefore(startTime)) {
      // 课程还未开始
      final remaining = startTime.difference(now);
      showClassProgress(
        courseName: courseName,
        timeRange: timeRange,
        location: location,
        progressPercent: 0,
        remainingTime: _formatDuration(remaining),
        isActive: false,
      );
    } else if (now.isAfter(endTime)) {
      // 课程已结束
      hideClassProgress();
    } else {
      // 课程进行中
      final elapsed = now.difference(startTime).inSeconds;
      final remaining = endTime.difference(now);
      final progress = ((elapsed / totalDuration) * 100).round();
      
      showClassProgress(
        courseName: courseName,
        timeRange: timeRange,
        location: location,
        progressPercent: progress.clamp(0, 100),
        remainingTime: _formatDuration(remaining),
        isActive: true,
      );
    }
  }

  /// 格式化持续时间
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}小时${duration.inMinutes % 60}分钟';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '${duration.inSeconds}秒';
    }
  }

  /// 显示周总结通知
  Future<void> showWeekSummary({
    required String title,
    required String body,
  }) async {
    final androidDetails = const AndroidNotificationDetails(
      _channelIdWeek,
      '周总结',
      channelDescription: '每周课程总结',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF22D3EE),
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    await _plugin.show(
      200,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// 安排每周重复的课程提醒
  Future<void> scheduleClassReminders({
    required List<ClassPeriod> periods,
    required List<int> weekdays,
    required int advanceMinutes,
    required String courseName,
    required String location,
  }) async {
    // 取消之前的提醒
    await cancelClassReminders();
    
    int idBase = 100;
    
    for (int day in weekdays) {
      for (int i = 0; i < periods.length; i++) {
        final period = periods[i];
        final notifId = idBase + (day * 10) + i;
        
        // 计算提醒时间
        int totalMinutes = period.startHour * 60 + period.startMinute - advanceMinutes;
        if (totalMinutes < 0) totalMinutes += 24 * 60;
        int notifHour = totalMinutes ~/ 60;
        int notifMinute = totalMinutes % 60;
        
        // 构建提醒标题
        String title;
        if (advanceMinutes > 0) {
          if (advanceMinutes >= 60) {
            final hours = advanceMinutes ~/ 60;
            final mins = advanceMinutes % 60;
            title = mins > 0 
              ? '${period.name} ${hours}小时${mins}分钟后'
              : '${period.name} ${hours}小时后';
          } else {
            title = '${period.name} ${advanceMinutes}分钟后';
          }
        } else {
          title = '${period.name} 开始了';
        }
        
        final body = '${period.startTime} - ${period.endTime}，准备上课 📚';
        
        await _scheduleNotification(
          id: notifId,
          title: title,
          body: body,
          hour: notifHour,
          minute: notifMinute,
          weekday: day,
          courseName: courseName,
          timeRange: '${period.startTime}-${period.endTime}',
          location: location,
        );
      }
    }
  }

  /// 安排单个通知
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
    required String courseName,
    required String timeRange,
    required String location,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelIdClass,
      '课程提醒',
      channelDescription: '上课前提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1D9BF0),
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '课程提醒',
      showWhen: true,
      timeoutAfter: 3600000,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(
        '$body\n📍 $location',
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: '📚 $courseName',
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekday(hour, minute, weekday),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// 取消所有课程提醒
  Future<void> cancelClassReminders() async {
    for (int id = 100; id < 200; id++) {
      await _plugin.cancel(id);
    }
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  智能课程通知系统
  //  与今日面板 (today_screen.dart) 一致：基于 SchedulePresets 作息表
  //  - 上课前30分钟：弹出提醒通知
  //  - 上课中：常驻进度通知（低重要性，不响铃）
  //  - 下课后：自动隐藏
  // ═══════════════════════════════════════════════════════════════════════

  static const int _smartReminderBaseId = 300; // 智能提醒 ID 范围 300-399
  Timer? _smartCheckTimer;
  DateTime? _lastNotifiedPeriod; // 防止重复通知同一节课

  /// 启动智能通知系统
  /// 每分钟检查一次，自动调度上课提醒和进度通知
  void startSmartNotification() {
    _smartCheckTimer?.cancel();
    _checkAndNotify(); // 立即检查一次
    _smartCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndNotify();
    });
    print('[NotificationService] 智能通知系统已启动');
  }

  /// 停止智能通知系统
  void stopSmartNotification() {
    _smartCheckTimer?.cancel();
    _smartCheckTimer = null;
    _lastNotifiedPeriod = null;
    print('[NotificationService] 智能通知系统已停止');
  }

  /// 核心检查逻辑（与今日面板一致）
  void _checkAndNotify() {
    try {
      final now = DateTime.now();
      final todayWeekday = now.weekday;
      final nowMinutes = now.hour * 60 + now.minute;

      // 作息表
      final periods = SchedulePresets.getPeriodsForWeekday(todayWeekday);

      // 计算当前/下一节课（与 today_screen.dart 完全一致）
      ClassPeriod? currentPeriod;
      ClassPeriod? nextPeriod;
      int? minutesToNext;

      for (final period in periods) {
        final startMin = period.startHour * 60 + period.startMinute;
        final endMin = period.endHour * 60 + period.endMinute;
        if (nowMinutes >= startMin && nowMinutes < endMin) {
          currentPeriod = period;
        } else if (nowMinutes < startMin && nextPeriod == null) {
          nextPeriod = period;
          minutesToNext = startMin - nowMinutes;
        }
      }

      // 读取课程数据
      final box = Hive.box<CourseEntry>('courses');
      CourseEntry? getCourse(int periodIndex) {
        try {
          return box.values.firstWhere(
            (c) => c.weekday == todayWeekday && c.periodIndex == periodIndex,
          );
        } catch (_) {
          return null;
        }
      }

      if (currentPeriod != null) {
        // ── 上课中：启动常驻进度通知 ──
        final course = getCourse(currentPeriod.index);
        final courseName = (course?.courseName ?? '').isNotEmpty
            ? course!.courseName : currentPeriod.name;
        final location = (course?.classroom ?? '').isNotEmpty
            ? course!.classroom : '';
        final startTime = DateTime(
          now.year, now.month, now.day,
          currentPeriod.startHour, currentPeriod.startMinute,
        );
        final endTime = DateTime(
          now.year, now.month, now.day,
          currentPeriod.endHour, currentPeriod.endMinute,
        );

        startClassProgressTracking(
          courseName: courseName,
          timeRange: '${currentPeriod.startTime}-${currentPeriod.endTime}',
          location: location,
          startTime: startTime,
          endTime: endTime,
        );
        _lastNotifiedPeriod = DateTime(now.year, now.month, now.day, currentPeriod.startHour);
      } else {
        // ── 不在上课：隐藏进度通知 ──
        hideClassProgress();

        // ── 上课前30分钟：发送提醒 ──
        if (nextPeriod != null && minutesToNext != null && minutesToNext <= 30) {
          final notifKey = DateTime(now.year, now.month, now.day, nextPeriod.startHour);
          // 防止重复通知
          if (_lastNotifiedPeriod != notifKey) {
            final course = getCourse(nextPeriod.index);
            final courseName = (course?.courseName ?? '').isNotEmpty
                ? course!.courseName : nextPeriod.name;
            final location = (course?.classroom ?? '').isNotEmpty
                ? course!.classroom : '';

            _showSmartReminder(
              period: nextPeriod,
              courseName: courseName,
              location: location,
              minutesLeft: minutesToNext,
            );
            _lastNotifiedPeriod = notifKey;
          }
        }
      }
    } catch (e) {
      print('[NotificationService] 智能通知检查失败: $e');
    }
  }

  /// 发送智能上课提醒
  Future<void> _showSmartReminder({
    required ClassPeriod period,
    required String courseName,
    required String location,
    required int minutesLeft,
  }) async {
    final id = _smartReminderBaseId + period.index;
    final timeStr = '${period.startTime} - ${period.endTime}';

    String title;
    if (minutesLeft <= 0) {
      title = '📚 $courseName 开始了';
    } else if (minutesLeft >= 60) {
      final h = minutesLeft ~/ 60;
      final m = minutesLeft % 60;
      title = m > 0 ? '⏰ ${courseName} ${h}小时${m}分钟后开始' : '⏰ ${courseName} ${h}小时后开始';
    } else {
      title = '⏰ ${courseName} ${minutesLeft}分钟后开始';
    }

    final body = '$timeStr，准备上课 📚';
    final locText = location.isNotEmpty ? '📍 $location' : '';

    final bigTextStyle = BigTextStyleInformation(
      '$body\n$locText',
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: '📍 ${location.isNotEmpty ? location : "未设置教室"}',
    );

    final androidDetails = AndroidNotificationDetails(
      _channelIdClass,
      '课程提醒',
      channelDescription: '上课前提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1D9BF0),
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '课程提醒',
      showWhen: true,
      timeoutAfter: 1800000, // 30分钟后自动消失
      fullScreenIntent: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: bigTextStyle,
      actions: [
        const AndroidNotificationAction(
          'dismiss', '我知道了', showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(id, title, '$body\n$locText',
        NotificationDetails(android: androidDetails));
    print('[NotificationService] 智能提醒: $title (剩余$minutesLeft分钟)');
  }

  /// 取消智能通知（所有 300-399 范围）
  Future<void> cancelSmartReminders() async {
    for (int id = _smartReminderBaseId; id < _smartReminderBaseId + 100; id++) {
      await _plugin.cancel(id);
    }
  }

  /// 获取下次提醒时间
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

  /// 安排周总结通知
  Future<void> scheduleWeekSummary() async {
    final courseCount = await _getWeekCourseCount();

    final title = '📊 本周课程小结';
    final body = courseCount > 0
        ? '本周共${courseCount}节课，您辛苦了！好好休息~'
        : '本周暂无课程安排，注意休息！';

    await _scheduleWeekSummary(
      id: 200,
      title: title,
      body: body,
      hour: 17,
      minute: 0,
      weekday: 5, // 周五
    );
  }

  /// 安排周总结通知
  Future<void> _scheduleWeekSummary({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
  }) async {
    final androidDetails = const AndroidNotificationDetails(
      _channelIdWeek,
      '周总结',
      channelDescription: '每周课程总结',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF22D3EE),
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekday(hour, minute, weekday),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// 获取本周课程数量
  Future<int> _getWeekCourseCount() async {
    try {
      final box = Hive.box('courses');
      return box.length;
    } catch (e) {
      return 0;
    }
  }
}
