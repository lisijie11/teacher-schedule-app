import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'models/schedule_model.dart';
import 'models/todo_model.dart';
import 'models/course_model.dart';
import 'services/notification_service.dart';
import 'services/holiday_service.dart';
import 'services/widget_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

// 小组件通信 Channel
const MethodChannel _widgetChannel = MethodChannel('com.lisijie.teacher_schedule/widget');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化时区
  tz.initializeTimeZones();

  // 初始化 Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderItemAdapter());
  Hive.registerAdapter(TodoItemAdapter());
  Hive.registerAdapter(CourseEntryAdapter());
  await Hive.openBox<ReminderItem>('reminders');
  await Hive.openBox<TodoItem>('todos');
  await Hive.openBox<CourseEntry>('courses');
  await Hive.openBox('settings');

  // 初始化通知服务
  await NotificationService.instance.init();

  // 初始化节假日服务
  await HolidayService.instance.init();

  // 初始化作息时间配置
  await SchedulePresets.init();

  // 初始化小组件自动刷新
  WidgetService.initAutoRefresh();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  // 创建本地认证 box（单人本地使用，无需登录）
  await Hive.openBox('api_auth');
  
  // 创建 API 缓存 box
  await Hive.openBox('api_cache');

  // 设置小组件通信回调
  _setupWidgetChannel();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
      ],
      child: const TeacherScheduleApp(),
    ),
  );
}

/// 设置小组件通信 Channel
void _setupWidgetChannel() {
  _widgetChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'getNextCourse':
        return _getNextCourseData();
      default:
        return null;
    }
  });
}

/// 获取下一节课程数据（供小组件使用）
Map<String, dynamic>? _getNextCourseData() {
  try {
    final box = Hive.box<CourseEntry>('courses');
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final nowMinutes = now.hour * 60 + now.minute;

    // 获取今日课程
    final courses = box.values.where((c) => c.weekday == todayWeekday).toList();
    if (courses.isEmpty) return null;

    // 按开始时间排序
    courses.sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));

    // 查找当前进行中的课程
    for (final course in courses) {
      final startMin = _parseTimeToMinutes(course.startTime);
      final endMin = _parseTimeToMinutes(course.endTime);

      if (nowMinutes >= startMin && nowMinutes < endMin) {
        // 正在上课
        final totalDuration = endMin - startMin;
        final elapsed = nowMinutes - startMin;
        final progress = totalDuration > 0 ? (elapsed * 100 ~/ totalDuration) : 0;
        final remaining = endMin - nowMinutes;
        final remainingHours = remaining ~/ 60;
        final remainingMinutes = remaining % 60;
        final remainingText = remainingHours > 0 ? '${remainingHours}小时${remainingMinutes}分' : '${remainingMinutes}分钟';

        return {
          'name': course.courseName,
          'time': '${course.startTime}-${course.endTime}',
          'location': course.classroom,
          'progress': progress,
          'remainingTime': remainingText,
          'isOngoing': true,
        };
      }
    }

    // 查找下一节课程
    for (final course in courses) {
      final startMin = _parseTimeToMinutes(course.startTime);
      if (nowMinutes < startMin) {
        final diff = startMin - nowMinutes;
        final hours = diff ~/ 60;
        final minutes = diff % 60;
        final diffText = hours > 0 ? '${hours}小时${minutes}分' : '${minutes}分钟';

        return {
          'name': course.courseName,
          'time': '${course.startTime}-${course.endTime}',
          'location': course.classroom,
          'progress': 0,
          'remainingTime': diffText,
          'isOngoing': false,
        };
      }
    }

    return null;
  } catch (e) {
    print('[_getNextCourseData] Error: $e');
    return null;
  }
}

int _parseTimeToMinutes(String time) {
  try {
    final parts = time.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 9;
      final minute = int.tryParse(parts[1]) ?? 0;
      return hour * 60 + minute;
    }
  } catch (e) {
    // ignore
  }
  return 9 * 60;
}

class TeacherScheduleApp extends StatelessWidget {
  const TeacherScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: '教师课表助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const HomeScreen(), // 直接进入主界面，无需登录
    );
  }
}
