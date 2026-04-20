import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'models/schedule_model.dart';
import 'models/todo_model.dart';
import 'models/course_model.dart';
import 'services/notification_service.dart';
import 'services/holiday_service.dart';
import 'services/widget_service.dart';
import 'services/location_service.dart';
import 'services/weather_service.dart';
import 'screens/home_screen.dart';
import 'screens/todo_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';
import 'package:hive_flutter/hive_flutter.dart';

// 小组件通信 Channel
const MethodChannel _widgetChannel = MethodChannel('com.lisijie.teacher_schedule/widget');
// 小组件路由 Channel
const MethodChannel _routeChannel = MethodChannel('com.lisijie.teacher_schedule/widget_route');

// 应用版本号（与 pubspec.yaml 和 build.gradle 保持一致）
const String appVersion = '2.8.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 SharedPreferences（存储应用版本号）
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_version', appVersion);

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

  // 小白条沉浸式设置
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // 状态栏透明
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,  // 状态栏图标深色
      statusBarBrightness: Brightness.light,     // 浅色状态栏背景
      // 导航栏透明
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 启用边缘到边缘布局
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // 创建本地认证 box（单人本地使用，无需登录）
  await Hive.openBox('api_auth');
  
  // 创建 API 缓存 box
  await Hive.openBox('api_cache');

  // 设置小组件通信回调
  _setupWidgetChannel();

  // 检查是否首次启动
  final settings = Hive.box('settings');
  final isFirstLaunch = settings.get('firstLaunchDone', defaultValue: false) != true;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
      ],
      child: TeacherScheduleApp(isFirstLaunch: isFirstLaunch),
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

class TeacherScheduleApp extends StatefulWidget {
  final bool isFirstLaunch;

  const TeacherScheduleApp({super.key, this.isFirstLaunch = false});

  @override
  State<TeacherScheduleApp> createState() => _TeacherScheduleAppState();
}

class _TeacherScheduleAppState extends State<TeacherScheduleApp> with WidgetsBindingObserver {
  // 全局路由通知器，通知 HomeScreen 切换 Tab
  final _routeNotifier = ValueNotifier<int>(0);
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.isFirstLaunch;
    WidgetsBinding.instance.addObserver(this);
    // 延迟一帧后检查（确保 HomeScreen 已创建并注册 PageController）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_showOnboarding) {
        _checkWidgetRoute();
        _autoUpdateLocation();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 每次应用回到前台，都检查路由（处理 widget 从后台拉起的情况）
    if (state == AppLifecycleState.resumed) {
      _checkWidgetRoute();
      _autoUpdateLocation();
    }
  }

  /// 自动更新位置（后台启动时）
  Future<void> _autoUpdateLocation() async {
    try {
      final settings = Hive.box('settings');
      final autoLocation = settings.get('autoLocation', defaultValue: true);

      if (!autoLocation) return;

      String userLocation = settings.get('userLocation', defaultValue: '');

      // 检查是否是无效位置
      final invalidLocations = [
        'downtown core',
        'unknown',
        'localhost',
        'linping',
        'zhejiang',
        'hangzhou',
      ];
      final isInvalid = userLocation.isEmpty ||
                        userLocation == '待定' ||
                        userLocation == '定位中...' ||
                        invalidLocations.any((invalid) =>
                          userLocation.toLowerCase().contains(invalid.toLowerCase()));

      // 如果用户没有设置过位置，或者位置是无效值，则自动定位
      if (isInvalid) {
        print('[AutoLocation] 检测到无效位置: "$userLocation"，开始自动定位...');
        final city = await LocationService.instance.getCurrentCity(forceRefresh: true);

        if (city != null && city.isNotEmpty) {
          userLocation = city;
          await settings.put('userLocation', userLocation);
          print('[AutoLocation] 自动定位成功: $userLocation');

          // 更新天气数据
          await WeatherService.instance.fetchWeather(location: userLocation);

          // 更新小组件
          await WidgetService.updateWidget();
        }
      }
    } catch (e) {
      print('[AutoLocation] 自动定位失败: $e');
    }
  }

  /// 检查小组件路由，点击不同小组件进入对应页面
  Future<void> _checkWidgetRoute() async {
    try {
      final route = await _routeChannel.invokeMethod<String>('getRoute');
      if (route != null && route.isNotEmpty && mounted) {
        final newIndex = _routeToIndex(route);
        _routeNotifier.value = newIndex;
        print('[WidgetRoute] 路由: $route -> Tab $newIndex');
      }
    } catch (e) {
      print('[WidgetRoute] 检查路由失败: $e');
    }
  }

  int _routeToIndex(String route) {
    switch (route) {
      case "/schedule": return 1;
      case "/todo":     return 2;
      default:           return 0;  // /today
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: '教师课表助手',
      debugShowCheckedModeBanner: false,
      // 本地化支持（DatePicker 等组件需要）
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文
        Locale('en', 'US'), // 英文
      ],
      locale: const Locale('zh', 'CN'), // 默认中文
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: _showOnboarding
          ? _OnboardingWrapper(
              onComplete: () {
                setState(() {
                  _showOnboarding = false;
                });
                // 引导完成后执行初始化
                _checkWidgetRoute();
                _autoUpdateLocation();
              },
            )
          : HomeScreen(
              initialIndex: 0,
              routeNotifier: _routeNotifier,
            ),
    );
  }
}

/// 引导页面包装器
class _OnboardingWrapper extends StatelessWidget {
  final VoidCallback onComplete;

  const _OnboardingWrapper({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          key: const ValueKey('onboarding'),
        ),
        settings: const RouteSettings(name: 'onboarding'),
      ),
      onPopPage: (route, result) {
        if (!route.didPop(null)) {
          return false;
        }
        onComplete();
        return true;
      },
    );
  }
}
