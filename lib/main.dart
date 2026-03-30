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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

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

class TeacherScheduleApp extends StatelessWidget {
  const TeacherScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: '李老师日程',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
