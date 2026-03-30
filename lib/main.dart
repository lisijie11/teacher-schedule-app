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
import 'screens/home_page_wrapper.dart';
import 'screens/login_screen.dart';
import 'services/api/index.dart';
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

  // 首先创建API认证box
  await Hive.openBox('api_auth');
  
  // 创建API缓存box
  await Hive.openBox('api_cache');

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
      title: '教师课表助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AppWrapper(),
    );
  }
}

/// 应用包装器，根据登录状态显示不同的页面
class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  _AppWrapperState createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _checkingAuth = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // 检查本地认证状态
    final apiService = ApiServiceManager.instance;
    final hasValidAuth = await apiService.hasValidLocalAuth();
    
    setState(() {
      _isLoggedIn = hasValidAuth;
      _checkingAuth = false;
    });
  }

  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),
              Text(
                '正在检查认证状态...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 根据认证状态显示相应界面
    if (!_isLoggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    } else {
      return HomePageWrapper(onLogout: _onLogout);
    }
  }
}
