import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';

/// 小组件数据通道 - 用于与 Kotlin 端通信
const _widgetChannel = MethodChannel('com.lisijie.teacher_schedule/widget_data');

/// 通知颜色常量 - 与 APP 主题一致
class _NotificationColors {
  // 澎湃OS3 经典蓝
  static const Color primaryBlue = Color(0xFF1D9BF0);
  static const Color primaryBlueLight = Color(0xFF38BDF8);

  // 成功/进度
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);

  // 文字色
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8E8E93);
}

/// 通知图标样式
enum NotificationIconStyle {
  course,    // 课程提醒
  progress,  // 进度通知
  summary,   // 周总结
}

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

  /// 构建澎湃OS3风格的通知详情
  /// 简洁白净风格，无 emoji 混乱感
  AndroidNotificationDetails _buildHyperOSDetails({
    required String channelId,
    required String channelName,
    required String description,
    required Importance importance,
    required Priority priority,
    required NotificationIconStyle iconStyle,
    String? title,
    String? body,
    String? subText,
    bool ongoing = false,
    bool autoCancel = true,
    int? timeoutAfter,
    bool fullScreenIntent = false,
    bool enableVibration = true,
    bool playSound = true,
    AndroidNotificationCategory? category,
    List<AndroidNotificationAction>? actions,
    StyleInformation? styleInformation,
    bool showProgress = false,
    int maxProgress = 100,
    int progress = 0,
    bool isActive = true,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: description,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      color: _NotificationColors.primaryBlue,
      // 澎湃OS3 风格：白色/浅色背景（系统会根据主题适配）
      styleInformation: styleInformation ??
          BigTextStyleInformation(
            body ?? '',
            htmlFormatBigText: false,
            contentTitle: title,
            htmlFormatContentTitle: false,
            summaryText: subText,
          ),
      // 行为设置
      enableVibration: enableVibration,
      playSound: playSound,
      showWhen: true,
      timeoutAfter: timeoutAfter,
      fullScreenIntent: fullScreenIntent,
      ongoing: ongoing,
      autoCancel: autoCancel,
      onlyAlertOnce: true,
      category: category,
      visibility: NotificationVisibility.public,
      ticker: channelName,
      // 进度条（用于常驻进度通知）
      showProgress: showProgress,
      maxProgress: maxProgress,
      progress: progress,
      indeterminate: false,
      // 操作按钮
      actions: actions,
    );
  }

  /// 显示课程提醒通知
  Future<void> showClassReminder({
    required int id,
    required String title,
    required String body,
    required String courseName,
    required String timeRange,
    required String location,
  }) async {
    // 澎湃OS3 风格：大文本 + 白色背景
    final bigTextStyle = BigTextStyleInformation(
      location.isNotEmpty ? '$body\n$location' : body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: timeRange,
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdClass,
      channelName: '课程提醒',
      description: '上课前提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      iconStyle: NotificationIconStyle.course,
      title: title,
      body: body,
      subText: timeRange,
      fullScreenIntent: true,
      timeoutAfter: 3600000,
      category: AndroidNotificationCategory.alarm,
      styleInformation: bigTextStyle,
      actions: [
        const AndroidNotificationAction(
          'dismiss',
          '我知道了',
          showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(id, title, body,
        NotificationDetails(android: androidDetails));
  }

  /// 显示/更新课程进度通知（常驻通知栏）
  /// 澎湃OS3 风格：纯净白色 + 蓝色进度条 + 简洁文字
  Future<void> showClassProgress({
    required String courseName,
    required String timeRange,
    required String location,
    required int progressPercent,
    required String remainingTime,
    required bool isActive,
  }) async {
    // 澎湃OS3 风格通知内容
    final contentTitle = isActive
        ? '正在上课 · $courseName'
        : '即将开始 · $courseName';
    final contentBody = location.isNotEmpty
        ? '$remainingTime · $location'
        : remainingTime;

    final bigTextStyle = BigTextStyleInformation(
      contentBody,
      htmlFormatBigText: false,
      contentTitle: contentTitle,
      htmlFormatContentTitle: false,
      summaryText: timeRange,
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdProgress,
      channelName: '课程进度',
      description: '实时显示当前课程进度',
      importance: Importance.low,
      priority: Priority.low,
      iconStyle: NotificationIconStyle.progress,
      title: contentTitle,
      body: contentBody,
      subText: timeRange,
      ongoing: true,
      autoCancel: false,
      enableVibration: false,
      playSound: false,
      showProgress: true,
      maxProgress: 100,
      progress: progressPercent,
      isActive: isActive,
      styleInformation: bigTextStyle,
    );

    await _plugin.show(
      _progressNotificationId,
      contentTitle,
      contentBody,
      NotificationDetails(android: androidDetails),
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
        remainingTime: '还有 ${_formatDuration(remaining)}',
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
        remainingTime: '剩余 ${_formatDuration(remaining)}',
        isActive: true,
      );
    }
  }

  /// 格式化持续时间
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h${duration.inMinutes % 60}m';
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
    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdWeek,
      channelName: '周总结',
      description: '每周课程总结',
      importance: Importance.high,
      priority: Priority.high,
      iconStyle: NotificationIconStyle.summary,
      title: title,
      body: body,
      category: AndroidNotificationCategory.reminder,
    );

    await _plugin.show(200, title, body,
        NotificationDetails(android: androidDetails));
  }

  /// 安排每周重复的课程提醒（双模式：Flutter定时 + 原生AlarmManager）
  /// 使用原生 AlarmManager 确保即使应用被杀死也能触发
  Future<void> scheduleClassReminders({
    required List<ClassPeriod> periods,
    required List<int> weekdays,
    required int advanceMinutes,
    required String courseName,
    required String location,
  }) async {
    // 检查学期是否已结束，如果超过总周数则不发送提醒
    if (_isSemesterOver()) {
      print('[NotificationService] 学期已结束，跳过课程提醒');
      return;
    }

    // 取消之前的提醒
    await cancelClassReminders();

    int idBase = 100;

    // 构建课程数据 JSON，用于原生调度
    final coursesData = <Map<String, dynamic>>[];

    for (int day in weekdays) {
      for (int i = 0; i < periods.length; i++) {
        final period = periods[i];
        final notifId = idBase + (day * 10) + i;

        // 计算提醒时间
        int totalMinutes = period.startHour * 60 + period.startMinute - advanceMinutes;
        if (totalMinutes < 0) totalMinutes += 24 * 60;
        int notifHour = totalMinutes ~/ 60;
        int notifMinute = totalMinutes % 60;

        // 构建提醒标题（澎湃OS3风格：简洁无 emoji）
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

        final body = '${period.startTime} - ${period.endTime}，准备上课';
        final locationText = location.isNotEmpty ? location : '';

        await _scheduleNotification(
          id: notifId,
          title: title,
          body: body,
          hour: notifHour,
          minute: notifMinute,
          weekday: day,
          courseName: courseName,
          timeRange: '${period.startTime}-${period.endTime}',
          location: locationText,
        );

        // 添加到课程数据（用于原生调度）
        coursesData.add({
          'weekday': day,
          'periodIndex': i,
          'courseName': courseName,
          'classroom': location,
          'startTime': period.startTime,
          'endTime': period.endTime,
          'notificationId': notifId,
        });
      }
    }

    // 使用原生 AlarmManager 调度精确提醒
    await _scheduleNativeReminders(coursesData, advanceMinutes);
  }

  /// 使用原生 AlarmManager 调度精确提醒
  /// 即使应用被杀死也能触发
  Future<void> _scheduleNativeReminders(
    List<Map<String, dynamic>> coursesData,
    int advanceMinutes,
  ) async {
    try {
      // 将课程数据转换为 JSON
      final coursesJson = jsonEncode({'courses': coursesData});

      // 调用原生方法调度提醒
      await _widgetChannel.invokeMethod('scheduleClassReminders', {
        'coursesJson': coursesJson,
        'advanceMinutes': advanceMinutes,
      });

      // 同时保存到 SharedPreferences 用于开机恢复
      await _widgetChannel.invokeMethod('saveWidgetData', {
        'key': 'reminder_courses_json',
        'value': coursesJson,
      });
      await _widgetChannel.invokeMethod('saveWidgetInt', {
        'key': 'reminder_advance_minutes',
        'value': advanceMinutes,
      });

      print('[NotificationService] 原生闹钟调度完成');
    } catch (e) {
      print('[NotificationService] 原生闹钟调度失败: $e');
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
    final bigTextStyle = BigTextStyleInformation(
      location.isNotEmpty ? '$body\n$location' : body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: timeRange,
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdClass,
      channelName: '课程提醒',
      description: '上课前提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      iconStyle: NotificationIconStyle.course,
      title: title,
      body: body,
      subText: timeRange,
      fullScreenIntent: true,
      timeoutAfter: 3600000,
      category: AndroidNotificationCategory.alarm,
      styleInformation: bigTextStyle,
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

  /// 检查学期是否已结束（当前周数 > 学期总周数）
  bool _isSemesterOver() {
    try {
      final settings = Hive.box('settings');
      final semesterStartStr = settings.get('semesterStartDate', defaultValue: '');
      if (semesterStartStr.isEmpty) return false;
      final semesterStart = DateTime.parse(semesterStartStr);
      final totalWeeks = settings.get('totalWeeks', defaultValue: 20);

      final now = DateTime.now();
      final daysSinceStart = now.difference(semesterStart).inDays;
      final startWeekday = semesterStart.weekday; // 1=周一
      final adjustedDays = daysSinceStart + (startWeekday - 1);
      final weekNumber = (adjustedDays / 7).floor() + 1;

      return weekNumber > totalWeeks;
    } catch (_) {
      return false;
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

  // 明日课程提醒相关
  static const int _tomorrowReminderId = 500; // 明日提醒通知 ID
  String? _lastTomorrowReminderDate; // 上次发送明日提醒的日期，防止重复

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

        // ── 今日课程结束后：提醒明天课程 ──
        _checkTomorrowClasses(box, periods);
      }
    } catch (e) {
      print('[NotificationService] 智能通知检查失败: $e');
    }
  }

  /// 发送智能上课提醒
  /// 澎湃OS3 风格：简洁白净，无 emoji 混乱感
  Future<void> _showSmartReminder({
    required ClassPeriod period,
    required String courseName,
    required String location,
    required int minutesLeft,
  }) async {
    final id = _smartReminderBaseId + period.index;
    final timeStr = '${period.startTime} - ${period.endTime}';

    // 澎湃OS3 风格标题：简洁无 emoji
    String title;
    if (minutesLeft <= 0) {
      title = '$courseName 开始了';
    } else if (minutesLeft >= 60) {
      final h = minutesLeft ~/ 60;
      final m = minutesLeft % 60;
      title = m > 0
          ? '$courseName ${h}小时${m}分钟后开始'
          : '$courseName ${h}小时后开始';
    } else {
      title = '$courseName ${minutesLeft}分钟后开始';
    }

    final body = '$timeStr，准备上课';
    final locationText = location.isNotEmpty ? location : '';

    final bigTextStyle = BigTextStyleInformation(
      locationText.isNotEmpty ? '$body\n$locationText' : body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: timeStr,
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdClass,
      channelName: '课程提醒',
      description: '上课前提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      iconStyle: NotificationIconStyle.course,
      title: title,
      body: body,
      subText: timeStr,
      fullScreenIntent: true,
      timeoutAfter: 1800000,
      category: AndroidNotificationCategory.alarm,
      styleInformation: bigTextStyle,
      actions: [
        const AndroidNotificationAction(
          'dismiss', '我知道了', showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(id, title, body,
        NotificationDetails(android: androidDetails));
    print('[NotificationService] 智能提醒: $title (剩余$minutesLeft分钟)');
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  今日课程结束后提醒明天课程
  //  当检测到今天最后一节课已结束（超过30分钟），自动提醒明天课程
  // ═══════════════════════════════════════════════════════════════════════

  /// 检查并发送明日课程提醒
  /// 在今天最后一节课结束后30分钟自动触发
  Future<void> _checkTomorrowClasses(
    Box<CourseEntry> todayBox,
    List<ClassPeriod> periods,
  ) async {
    try {
      final now = DateTime.now();
      final todayDate = '${now.year}-${now.month}-${now.day}';

      // 防止同一天重复发送
      if (_lastTomorrowReminderDate == todayDate) return;

      // 获取今天的作息表最后一节课结束时间
      if (periods.isEmpty) return;
      final lastPeriod = periods.last;
      final lastEndMinutes = lastPeriod.endHour * 60 + lastPeriod.endMinute;
      final currentMinutes = now.hour * 60 + now.minute;

      // 判断今天最后一节课是否已结束超过30分钟
      // (最后一节课结束后30分钟~2小时内触发)
      final minutesAfterEnd = currentMinutes - lastEndMinutes;
      if (minutesAfterEnd < 30 || minutesAfterEnd > 120) return;

      // 计算明天是周几
      final tomorrowWeekday = now.weekday == 7 ? 1 : now.weekday + 1;

      // 获取明天的课程
      final tomorrowPeriods = SchedulePresets.getPeriodsForWeekday(tomorrowWeekday);
      final tomorrowCourses = <CourseEntry>[];

      for (final period in tomorrowPeriods) {
        try {
          final course = todayBox.values.firstWhere(
            (c) => c.weekday == tomorrowWeekday && c.periodIndex == period.index,
          );
          tomorrowCourses.add(course);
        } catch (_) {
          // 没有这门课
        }
      }

      // 如果明天有课，发送提醒
      if (tomorrowCourses.isEmpty) return;

      // 标记已发送
      _lastTomorrowReminderDate = todayDate;

      // 构建通知内容
      await _showTomorrowReminder(
        weekday: tomorrowWeekday,
        courses: tomorrowCourses,
        periods: tomorrowPeriods,
      );

      print('[NotificationService] 明日课程提醒已发送: 共${tomorrowCourses.length}节课');
    } catch (e) {
      print('[NotificationService] 明日课程提醒失败: $e');
    }
  }

  /// 发送明日课程提醒通知
  /// 澎湃OS3 风格：简洁白净，无 emoji
  Future<void> _showTomorrowReminder({
    required int weekday,
    required List<CourseEntry> courses,
    required List<ClassPeriod> periods,
  }) async {
    // 计算明天日期
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final dateStr = '${tomorrow.month}月${tomorrow.day}日';

    // 构建课程列表文本
    final courseList = <String>[];
    for (final course in courses) {
      final periodName = periods
          .firstWhere((p) => p.index == course.periodIndex, orElse: () => periods.first)
          .name;
      final location = course.classroom.isNotEmpty ? ' · ${course.classroom}' : '';
      courseList.add('${course.courseName} $periodName$location');
    }
    final courseText = courseList.join('\n');

    // 计算课程数量摘要
    final summaryText = '共${courses.length}节课';

    // 构建通知内容
    const title = '明日课程预告';
    final body = '$dateStr · $summaryText';

    // 详细文本
    final bigText = '明天 ($dateStr) 有以下课程：\n\n$courseText\n\n记得提前做好准备！';

    final bigTextStyle = BigTextStyleInformation(
      bigText,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: body,
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdClass,
      channelName: '明日提醒',
      description: '今日课程结束后提醒明天课程',
      importance: Importance.high,
      priority: Priority.high,
      iconStyle: NotificationIconStyle.course,
      title: title,
      body: body,
      subText: summaryText,
      fullScreenIntent: true,
      timeoutAfter: 3600000, // 1小时后自动消失
      category: AndroidNotificationCategory.reminder,
      styleInformation: bigTextStyle,
      actions: [
        const AndroidNotificationAction(
          'dismiss', '我知道了', showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(
      _tomorrowReminderId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// 取消明日提醒
  Future<void> cancelTomorrowReminder() async {
    await _plugin.cancel(_tomorrowReminderId);
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

    // 澎湃OS3 风格标题
    final title = '本周课程小结';
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
    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdWeek,
      channelName: '周总结',
      description: '每周课程总结',
      importance: Importance.high,
      priority: Priority.high,
      iconStyle: NotificationIconStyle.summary,
      title: title,
      body: body,
      category: AndroidNotificationCategory.reminder,
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

  // ═══════════════════════════════════════════════════════════════════════
  //  测试通知方法 - 与超级岛配合使用
  //  统一白色/纯净风格
  // ═══════════════════════════════════════════════════════════════════════

  /// 测试通知ID基础值
  static const int _testNotificationIdBase = 9000;

  /// 课程提醒测试通知（带进度条样式）
  Future<void> showCourseReminderTest() async {
    // 模拟课程进行中
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 15));
    final endTime = now.add(const Duration(minutes: 30));

    final totalDuration = endTime.difference(startTime).inSeconds;
    final elapsed = now.difference(startTime).inSeconds;
    final progress = ((elapsed / totalDuration) * 100).round();

    // 澎湃OS3纯净风格：白色 + 蓝色
    const title = '正在上课 · 高等数学';
    const body = '剩余 30 分钟 · A301';

    final bigTextStyle = BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: '08:30 - 10:05',
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdProgress,
      channelName: '课程进度',
      description: '实时显示当前课程进度',
      importance: Importance.low,
      priority: Priority.low,
      iconStyle: NotificationIconStyle.progress,
      title: title,
      body: body,
      subText: '08:30 - 10:05',
      ongoing: true,
      autoCancel: false,
      enableVibration: false,
      playSound: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      styleInformation: bigTextStyle,
    );

    await _plugin.show(_testNotificationIdBase + 1, title, body,
        NotificationDetails(android: androidDetails));

    // 30秒后自动取消
    Future.delayed(const Duration(seconds: 30), () {
      _plugin.cancel(_testNotificationIdBase + 1);
    });
  }

  /// 倒计时测试通知（带进度条样式）
  Future<void> showCountdownTest() async {
    const title = '下课倒计时 · 剩余 45 分钟';
    const body = '请做好准备';

    final bigTextStyle = BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: '倒计时提醒',
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdProgress,
      channelName: '课程进度',
      description: '倒计时提醒',
      importance: Importance.low,
      priority: Priority.low,
      iconStyle: NotificationIconStyle.progress,
      title: title,
      body: body,
      subText: '倒计时提醒',
      ongoing: true,
      autoCancel: false,
      enableVibration: false,
      playSound: false,
      showProgress: true,
      maxProgress: 100,
      progress: 75, // 75% 进度
      styleInformation: bigTextStyle,
    );

    await _plugin.show(_testNotificationIdBase + 2, title, body,
        NotificationDetails(android: androidDetails));

    // 30秒后自动取消
    Future.delayed(const Duration(seconds: 30), () {
      _plugin.cancel(_testNotificationIdBase + 2);
    });
  }

  /// 会议提醒测试通知
  Future<void> showMeetingReminderTest({
    required String title,
    required String body,
  }) async {
    final bigTextStyle = BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: '会议提醒',
    );

    final androidDetails = _buildHyperOSDetails(
      channelId: _channelIdClass,
      channelName: '课程提醒',
      description: '会议提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      iconStyle: NotificationIconStyle.course,
      title: title,
      body: body,
      subText: '会议提醒',
      fullScreenIntent: true,
      timeoutAfter: 60000,
      category: AndroidNotificationCategory.reminder,
      styleInformation: bigTextStyle,
      actions: [
        const AndroidNotificationAction(
          'dismiss', '我知道了', showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(_testNotificationIdBase + 3, title, body,
        NotificationDetails(android: androidDetails));

    // 30秒后自动取消
    Future.delayed(const Duration(seconds: 30), () {
      _plugin.cancel(_testNotificationIdBase + 3);
    });
  }

  /// 取消所有测试通知
  Future<void> cancelTestNotifications() async {
    await _plugin.cancel(_testNotificationIdBase + 1);
    await _plugin.cancel(_testNotificationIdBase + 2);
    await _plugin.cancel(_testNotificationIdBase + 3);
  }
}
