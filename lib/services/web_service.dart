import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../models/course_model.dart';
import '../models/todo_model.dart';
import 'weather_service.dart';

/// 天气数据
class WeatherData {
  final String location;
  final String weatherText;
  final String weatherIcon;
  final int temp;
  final int humidity;
  final String clothingAdvice;
  final String travelAdvice;
  final List<DailyForecast> forecast;
  final List<HourlyForecast> hourlyForecast; // 12小时预报

  WeatherData({
    required this.location,
    required this.weatherText,
    required this.weatherIcon,
    required this.temp,
    required this.humidity,
    required this.clothingAdvice,
    required this.travelAdvice,
    required this.forecast,
    this.hourlyForecast = const [],
  });

  Map<String, dynamic> toJson() => {
    'location': location,
    'weatherText': weatherText,
    'weatherIcon': weatherIcon,
    'temp': temp,
    'humidity': humidity,
    'clothingAdvice': clothingAdvice,
    'travelAdvice': travelAdvice,
    'forecast': forecast.map((f) => f.toJson()).toList(),
    'hourlyForecast': hourlyForecast.map((h) => h.toJson()).toList(),
  };
}

class DailyForecast {
  final String date;
  final String weekday;
  final String weatherIcon;
  final String weatherText;
  final int tempMax;
  final int tempMin;

  DailyForecast({
    required this.date,
    required this.weekday,
    required this.weatherIcon,
    required this.weatherText,
    required this.tempMax,
    required this.tempMin,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'weekday': weekday,
    'weatherIcon': weatherIcon,
    'weatherText': weatherText,
    'tempMax': tempMax,
    'tempMin': tempMin,
  };
}

class HourlyForecast {
  final String time;
  final String weatherIcon;
  final int temp;
  final double precipProbability; // 降水概率 0-100

  HourlyForecast({
    required this.time,
    required this.weatherIcon,
    required this.temp,
    this.precipProbability = 0,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'weatherIcon': weatherIcon,
    'temp': temp,
    'precipProbability': precipProbability,
  };
}

class WebService {
  static final WebService instance = WebService._();

  HttpServer? _server;
  bool _isRunning = false;
  String? _serverUrl;

  // 课程数据
  List<CourseEntry> _courses = [];
  List<TodoItem> _todos = [];

  // 天气数据
  WeatherData? _weather;

  // 用户信息
  String _userName = '';
  String _userAvatarPath = '';
  DateTime _semesterStartDate = DateTime.now(); // 学期起始日，默认当前日期

  // 获取服务器地址
  String? get serverUrl => _serverUrl;
  bool get isRunning => _isRunning;

  WebService._();

  /// 获取设备 IP 地址
  Future<String?> getLocalIp() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      return wifiIP;
    } catch (e) {
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      } catch (_) {}
      return null;
    }
  }

  /// 启动 Web 服务
  Future<bool> startServer() async {
    if (_isRunning) return true;

    try {
      final ip = await getLocalIp();
      if (ip == null) {
        print('[WebService] 无法获取设备 IP');
        return false;
      }

      // 读取用户设置的常用地点，并更新天气
      await _loadUserLocation();

      final router = Router();

      // 主页
      router.get('/', (Request request) {
        return Response.ok(
          _generateWebPage(),
          headers: {'Content-Type': 'text/html; charset=utf-8'},
        );
      });

      // API: 获取课程数据
      router.get('/api/courses', (Request request) {
        return Response.ok(
          jsonEncode(_courses.map((c) => {
            'id': c.id,
            'weekday': c.weekday,
            'periodIndex': c.periodIndex,
            'courseName': c.courseName,
            'classroom': c.classroom,
            'note': c.note,
            'colorIndex': c.colorIndex,
            'startTime': c.startTime,
            'endTime': c.endTime,
          }).toList()),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // API: 获取待办数据
      router.get('/api/todos', (Request request) {
        return Response.ok(
          jsonEncode(_todos.map((t) => {
            'id': t.id,
            'title': t.title,
            'isDone': t.isDone,
            'priority': t.priority,
            'createdAt': t.createdAt.toIso8601String(),
          }).toList()),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // API: 获取今日课程
      router.get('/api/today', (Request request) {
        final todayWeekday = DateTime.now().weekday;
        final todayCourses = _courses.where((c) => c.weekday == todayWeekday).toList();
        todayCourses.sort((a, b) => a.startTime.compareTo(b.startTime));
        return Response.ok(
          jsonEncode(todayCourses.map((c) => {
            'id': c.id,
            'weekday': c.weekday,
            'periodIndex': c.periodIndex,
            'courseName': c.courseName,
            'classroom': c.classroom,
            'note': c.note,
            'colorIndex': c.colorIndex,
            'startTime': c.startTime,
            'endTime': c.endTime,
          }).toList()),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // API: 获取用户头像
      router.get('/api/avatar', (Request request) async {
        if (_userAvatarPath.isNotEmpty) {
          final file = File(_userAvatarPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            return Response.ok(
              bytes,
              headers: {'Content-Type': 'image/png'},
            );
          }
        }
        return Response.notFound('Avatar not found');
      });

      // API: 获取天气数据
      router.get('/api/weather', (Request request) {
        if (_weather != null) {
          return Response.ok(
            jsonEncode(_weather!.toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return Response.ok(
          jsonEncode({}),
          headers: {'Content-Type': 'application/json'},
        );
      });

      final handler = const Pipeline()
          .addMiddleware(_corsHeaders())
          .addHandler(router.call);

      int? boundPort;
      for (final port in [8080, 8081, 8082, 8083, 8084]) {
        try {
          _server = await shelf_io.serve(handler, ip, port);
          boundPort = port;
          break;
        } catch (e) {
          continue;
        }
      }

      if (_server == null || boundPort == null) {
        print('[WebService] 无法绑定到可用端口');
        return false;
      }

      _serverUrl = 'http://$ip:$boundPort';
      _isRunning = true;
      print('[WebService] 服务器启动: $_serverUrl');
      return true;
    } catch (e) {
      print('[WebService] 启动失败: $e');
      return false;
    }
  }

  /// 停止 Web 服务
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
    _serverUrl = null;
    print('[WebService] 服务器已停止');
  }

  /// 更新课程和待办数据
  void updateData(List<CourseEntry> courses, List<TodoItem> todos) {
    _courses = courses;
    _todos = todos;
  }

  /// 更新天气数据
  void updateWeather(WeatherData weather) {
    _weather = weather;
  }

  /// 更新用户信息
  void updateUserInfo(String name, String avatarPath) {
    _userName = name;
    _userAvatarPath = avatarPath;
    // 同步读取学期起始日
    _loadSemesterStartDate();
  }

  /// 从 Hive settings 读取学期起始日
  void _loadSemesterStartDate() {
    try {
      final box = Hive.box('settings');
      final dateStr = box.get('semesterStartDate', defaultValue: '');
      if (dateStr.isNotEmpty) {
        _semesterStartDate = DateTime.parse(dateStr);
      } else {
        // 智能推断学期起始日
        final now = DateTime.now();
        if (now.month >= 9) {
          // 9-12月：秋季学期，起始日为当年9月1日
          _semesterStartDate = DateTime(now.year, 9, 1);
        } else if (now.month >= 3) {
          // 3-8月：春季学期，起始日为当年3月1日
          _semesterStartDate = DateTime(now.year, 3, 1);
        } else {
          // 1-2月：上一年秋季学期
          _semesterStartDate = DateTime(now.year - 1, 9, 1);
        }
      }
    } catch (e) {
      print('[WebService] 读取学期起始日失败: $e');
      _semesterStartDate = DateTime.now();
    }
  }

  /// 从 Hive settings 读取用户常用地点，并更新天气
  Future<void> _loadUserLocation() async {
    try {
      final box = Hive.box('settings');
      final userLocation = box.get('userLocation', defaultValue: '');

      if (userLocation.isNotEmpty && userLocation != '待定') {
        print('[WebService] 读取用户常用地点: $userLocation');
        // 使用用户设置的常用地点更新天气
        await WeatherService.instance.fetchWeather(location: userLocation);
      } else {
        print('[WebService] 用户未设置常用地点，使用默认天气');
      }
    } catch (e) {
      print('[WebService] 读取用户常用地点失败: $e');
    }
  }

  /// CORS 中间件
  Middleware _corsHeaders() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeadersMap);
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeadersMap);
      };
    };
  }

  static const _corsHeadersMap = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };

  /// 生成 Web 页面（重构版）
  String _generateWebPage() {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final todayName = weekdayNames[todayWeekday];
    final todayStr = '${now.month}月${now.day}日';
    final todayCourses = _courses.where((c) => c.weekday == todayWeekday).toList();
    todayCourses.sort((a, b) => a.startTime.compareTo(b.startTime));

    // ========== 统计信息计算 ==========
    final totalWeeklyCourses = _courses.length;
    int finishedTodayCount = 0;
    int pendingTodayCount = 0;
    for (final course in todayCourses) {
      final progress = _calculateProgress(course.startTime, course.endTime);
      if (progress >= 100) finishedTodayCount++;
      else if (progress < 0) pendingTodayCount++;
    }
    final activeTodayCount = todayCourses.length - finishedTodayCount - pendingTodayCount;
    // 已上课时：本周已过去的课 + 今天已完成的
    int completedTotal = 0;
    for (int d = 1; d < todayWeekday; d++) {
      completedTotal += _courses.where((c) => c.weekday == d).length;
    }
    completedTotal += finishedTodayCount;
    final remainingTotal = totalWeeklyCourses - completedTotal - activeTodayCount;

    // ========== 计算当前是第几周 ==========
    // 使用用户设置的学期起始日
    final semesterStart = _semesterStartDate;
    final daysSinceStart = now.difference(semesterStart).inDays;
    // 周一为一周起始，调整偏移
    final startWeekday = semesterStart.weekday; // 1=周一
    final adjustedDays = daysSinceStart + (startWeekday - 1);
    final weekNumber = (adjustedDays / 7).floor() + 1;

    // 读取学期总周数
    int totalWeeks = 20;
    try {
      final box = Hive.box('settings');
      totalWeeks = box.get('totalWeeks', defaultValue: 20);
    } catch (_) {}
    final isSemesterOver = weekNumber > totalWeeks;

    // ========== 构建 7×4 课程网格（含天气行） ==========
    String scheduleGridHtml = '';

    // 构建天气行数据：按 weekday(1-7) 映射天气（本周7天）
    Map<int, DailyForecast?> weatherMap = {};
    if (_weather != null && _weather!.forecast.isNotEmpty) {
      // 策略：forecast 数据从今天开始排列（weather_service 的逻辑）
      // 本周每天对应 forecast 的偏移量
      final monday = now.subtract(Duration(days: now.weekday - 1));
      for (int i = 0; i < 7; i++) {
        final dayDate = monday.add(Duration(days: i));
        final dayOffset = dayDate.difference(now).inDays;
        // 计算在 forecast 数组中的索引
        int forecastIndex = dayOffset;
        // 如果是过去的日期（dayOffset < 0），用第0个；如果超出范围，用最后一个
        if (forecastIndex < 0) forecastIndex = 0;
        if (forecastIndex >= _weather!.forecast.length) {
          forecastIndex = _weather!.forecast.length - 1;
        }
        if (forecastIndex >= 0 && forecastIndex < _weather!.forecast.length) {
          weatherMap[dayDate.weekday] = _weather!.forecast[forecastIndex];
        }
      }
    }

    for (int day = 1; day <= 7; day++) {
      scheduleGridHtml += '<div class="schedule-col ${day == todayWeekday ? 'today' : ''}">';
      scheduleGridHtml += '<div class="col-header">${weekdayNames[day]}</div>';

      // 天气行（增强版：图标 + 温度范围 + 天气描述）
      final dayWeather = weatherMap[day];
      if (dayWeather != null) {
        scheduleGridHtml += '''
          <div class="weather-row" title="${_escapeAttr(dayWeather.weatherText)} ${dayWeather.tempMin}°~${dayWeather.tempMax}°">
            <span class="weather-icon">${dayWeather.weatherIcon}</span>
            <span class="weather-info">
              <span class="weather-temp">${dayWeather.tempMin}~${dayWeather.tempMax}°</span>
              <span class="weather-desc">${dayWeather.weatherText}</span>
            </span>
          </div>
        ''';
      } else if (_weather != null) {
        scheduleGridHtml += '<div class="weather-row weather-empty"><span class="weather-icon">--</span><span class="weather-temp">--</span></div>';
      } else {
        scheduleGridHtml += '<div class="weather-row"></div>';
      }

      for (int period = 1; period <= 4; period++) {
        final course = _courses.where((c) => c.weekday == day && c.periodIndex == period).firstOrNull;
        if (course != null) {
          final colorHex = '#${course.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
          final textColor = _getContrastColor(course.color);
          final periodName = _getPeriodName(course.periodIndex);
          scheduleGridHtml += '''
            <div class="grid-cell course"
                 style="--cell-color: $colorHex; --text-color: $textColor;"
                 data-course-name="${_escapeAttr(course.courseName)}"
                 data-course-time="${course.startTime}-${course.endTime}"
                 data-course-room="${_escapeAttr(course.classroom)}"
                 data-course-period="$periodName"
                 data-course-weekday="${weekdayNames[day]}"
                 data-course-note="${_escapeAttr(course.note ?? '')}">
              <span class="cell-name">${course.courseName}</span>
              ${course.classroom.isNotEmpty ? '<span class="cell-room">${course.classroom}</span>' : ''}
            </div>
          ''';
        } else {
          scheduleGridHtml += '<div class="grid-cell empty"></div>';
        }
      }
      scheduleGridHtml += '</div>';
    }

    // ========== 构建今日课程 ==========
    String todayCoursesHtml = '';
    if (todayCourses.isEmpty) {
      todayCoursesHtml = '''
        <div class="module-empty">
          <span class="empty-icon">🎉</span>
          <span class="empty-text">今日无课</span>
        </div>
      ''';
    } else {
      for (final course in todayCourses) {
        final progress = _calculateProgress(course.startTime, course.endTime);
        final isActive = progress >= 0 && progress < 100;
        final isFinished = progress >= 100;
        final isPending = progress < 0;
        final colorHex = '#${course.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        final periodName = _getPeriodName(course.periodIndex);

        // 状态标签
        String statusLabel = '';
        if (isActive) {
          statusLabel = '<span class="live-badge active"><span class="status-dot active"></span>上课中</span>';
        } else if (isFinished) {
          statusLabel = '<span class="live-badge finished"><span class="status-dot finished"></span>已结束</span>';
        } else {
          statusLabel = '<span class="live-badge pending"><span class="status-dot pending"></span>即将上课</span>';
        }

        todayCoursesHtml += '''
          <div class="today-item ${isActive ? 'active' : ''} ${isFinished ? 'finished' : ''}"
               style="--accent: $colorHex"
               data-course-note="${_escapeAttr(course.note ?? '')}"
               data-course-room-detail="${_escapeAttr(course.classroom)}"
               data-course-progress="$progress">
            <div class="item-content">
              <div class="item-left">
                <div class="item-name">$statusLabel ${course.courseName}</div>
                <div class="item-room">${course.classroom.isEmpty ? '-' : course.classroom}</div>
              </div>
              <div class="item-right">
                <span class="item-period">$periodName</span>
                <span class="item-time">${course.startTime}-${course.endTime}</span>
              </div>
            </div>
            <div class="item-expandable">
              <div class="expand-note">${(course.note?.isNotEmpty ?? false) ? course.note : '暂无备注'}</div>
              <div class="expand-location">📍 ${course.classroom.isEmpty ? '未指定教室' : course.classroom}</div>
              ${isActive ? '''
                <div class="expand-progress">
                  <div class="progress-track"><div class="progress-fill" style="width:${progress}%"></div></div>
                  <span class="progress-num">$progress%</span>
                </div>
                <div class="expand-remaining">⏱️ 剩余 ${_getRemainingTime(course.endTime)}</div>
              ''' : ''}
            </div>
            ${isActive ? '''
              <div class="item-progress-bar">
                <div class="progress-track"><div class="progress-fill" style="width:${progress}%"></div></div>
                <span class="progress-num">$progress%</span>
              </div>
              <div class="item-remaining">剩余 ${_getRemainingTime(course.endTime)}</div>
            ''' : ''}
          </div>
        ''';
      }
    }

    // ========== 构建待办事项 ==========
    final pendingTodos = _todos.where((t) => !t.isDone).take(4).toList();
    final completedTodos = _todos.where((t) => t.isDone).take(2).toList();
    String todosHtml = '';

    if (pendingTodos.isEmpty && completedTodos.isEmpty) {
      todosHtml = '''
        <div class="module-empty">
          <span class="empty-icon">✨</span>
          <span class="empty-text">暂无待办</span>
        </div>
      ''';
    } else {
      for (final todo in pendingTodos) {
        String priorityClass = '';
        String priorityIcon = '';
        if (todo.priority == 2) { priorityClass = 'urgent'; priorityIcon = '🔴'; }
        else if (todo.priority == 1) { priorityClass = 'important'; priorityIcon = '⚡'; }
        todosHtml += '''
          <div class="todo-item $priorityClass" data-todo-id="${todo.id}">
            <div class="todo-check"><span class="check-icon"></span></div>
            <span class="todo-text">$priorityIcon${todo.title}</span>
          </div>
        ''';
      }
      if (completedTodos.isNotEmpty) {
        todosHtml += '<div class="todo-section-title">已完成</div>';
        for (final todo in completedTodos) {
          todosHtml += '''
            <div class="todo-item done" data-todo-id="${todo.id}">
              <div class="todo-check checked"><span class="check-icon">✓</span></div>
              <span class="todo-text">${todo.title}</span>
            </div>
          ''';
        }
      }
    }

    // 状态判断
    String currentStatus = '休息中';
    String statusIcon = '🌙';
    String nextCourseName = '';
    final activeCourse = _getCurrentCourse(todayCourses);
    if (activeCourse != null) {
      currentStatus = '上课中';
      statusIcon = '📚';
      nextCourseName = activeCourse.courseName;
    } else {
      final nextCourse = _getNextCourse(todayCourses);
      if (nextCourse != null) {
        currentStatus = '下一节';
        statusIcon = '⏰';
        nextCourseName = nextCourse.courseName;
      }
    }

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>教师课表助手</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #007AFF;
      --primary-light: #5AC8FA;
      --accent: #5856D6;
      --success: #34C759;
      --warning: #FF9500;
      --danger: #FF3B30;
      --text-primary: #1C1C1E;
      --text-secondary: #8E8E93;
      --text-hint: #AEAEB2;
      --bg-primary: #F2F2F7;
      --bg-card: #FFFFFF;
      --bg-secondary: #E5E5EA;
      --border: #E5E5EA;
      --shadow: 0 2px 12px rgba(0,0,0,0.06);
      --radius: 16px;
      --radius-sm: 10px;
    }

    [data-theme="dark"] {
      --text-primary: #FFFFFF;
      --text-secondary: #AEAEB2;
      --text-hint: #636366;
      --bg-primary: #000000;
      --bg-card: #1C1C1E;
      --bg-secondary: #2C2C2E;
      --border: #38383A;
      --shadow: 0 2px 12px rgba(0,0,0,0.3);
    }

    * { margin: 0; padding: 0; box-sizing: border-box; }

    html, body {
      height: 100%;
    }

    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background: var(--bg-primary);
      color: var(--text-primary);
      transition: background 0.3s, color 0.3s;
    }

    /* ===== 页面加载动画 ===== */
    .main-container {
      max-width: 1400px;
      margin: 0 auto;
      padding: 16px 16px 24px;
      display: flex;
      flex-direction: column;
      gap: 16px;
      animation: pageLoadIn 0.6s ease-out both;
    }

    @keyframes pageLoadIn {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    /* ===== 顶部状态栏 ===== */
    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 20px;
      background: var(--bg-card);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      transition: all 0.3s ease;
    }

    .topbar:hover {
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    }

    .topbar-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .topbar-avatar {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      object-fit: cover;
      border: 2px solid var(--primary);
    }

    .topbar-avatar-placeholder {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: var(--bg-secondary);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
    }

    .topbar-user-info {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .topbar-username {
      font-size: 16px;
      font-weight: 600;
      color: var(--text-primary);
    }

    .topbar-date {
      font-size: 13px;
      color: var(--text-secondary);
    }

    .topbar-time {
      font-size: 20px;
      font-weight: 700;
      color: var(--primary);
      font-variant-numeric: tabular-nums;
      margin-right: 12px;
    }

    /* 时间冒号闪烁 */
    .time-colon {
      animation: colonBlink 1s step-end infinite;
    }

    @keyframes colonBlink {
      0%, 49% { opacity: 1; }
      50%, 100% { opacity: 0.3; }
    }

    .topbar-center {
      flex: 1;
      text-align: center;
    }

    /* 统计信息条 */
    .stats-bar {
      font-size: 12px;
      color: var(--text-secondary);
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      flex-wrap: wrap;
      line-height: 1.6;
    }

    .stat-num {
      font-weight: 700;
      color: var(--primary);
    }

    .topbar-status {
      font-size: 15px;
      color: var(--text-secondary);
    }

    .topbar-right {
      display: flex;
      align-items: center;
    }

    .theme-toggle {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: var(--bg-secondary);
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      transition: transform 0.2s;
      -webkit-tap-highlight-color: transparent;
      touch-action: manipulation;
      user-select: none;
      -webkit-user-select: none;
    }

    .theme-toggle:hover { transform: scale(1.1); }
    .theme-toggle:active { transform: scale(0.95); }


    /* ===== 主内容布局 ===== */
    .top-row {
      display: grid;
      grid-template-columns: 280px 1fr;
      gap: 16px;
      min-height: 400px;
    }

    /* 左侧模块容器 */
    .left-modules {
      display: grid;
      grid-template-rows: 1fr 1fr;
      gap: 16px;
    }

    /* 通用卡片 - 增加悬浮效果 */
    .card {
      background: var(--bg-card);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
    }

    .card:hover {
      box-shadow: 0 8px 30px rgba(0,0,0,0.12);
      transform: translateY(-2px);
    }

    .card::after {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      border-radius: var(--radius);
      border: 2px solid transparent;
      transition: border-color 0.3s;
      pointer-events: none;
    }

    .card:hover::after {
      border-color: var(--primary);
      opacity: 0.3;
    }

    .card-header {
      padding: 14px 16px;
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      gap: 10px;
      flex-shrink: 0;
      background: var(--bg-card);
    }

    .card-icon {
      width: 28px;
      height: 28px;
      background: linear-gradient(135deg, var(--primary), var(--primary-light));
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
    }

    .card-title {
      font-size: 15px;
      font-weight: 600;
    }

    /* ===== 诗词区域（今日诗词API） ===== */
    .schedule-quote {
      font-size: 14px;
      margin-left: auto;
      cursor: pointer;
      transition: opacity 0.3s ease;
      position: relative;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      display: inline-block;
      align-items: center;
      gap: 4px;
      user-select: none;
      -webkit-user-select: none;
      white-space: nowrap;
      max-width: 280px;
      overflow: hidden;
      vertical-align: middle;
    }

    /* 诗词内容容器——用于实现 marquee 滚动效果 */
    .schedule-quote .quote-content {
      display: inline-block;
      animation: marqueeScroll 10s linear infinite;
    }

    /* Marquee 跑马灯效果：文字从右向左平滑滚入 */
    @keyframes marqueeScroll {
      0% { transform: translateX(100%); }
      100% { transform: translateX(-100%); }
    }

    .schedule-quote:hover {
      filter: brightness(1.15);
    }

    .schedule-quote:hover .quote-content {
      animation-play-state: paused; /* 悬停时暂停滚动 */
    }

    .schedule-quote.loading {
      opacity: 0.7;
    }

    .quote-refresh-icon {
      opacity: 1;
      transform: rotate(180deg);
    }

    .quote-refresh-icon {
      font-size: 11px;
      opacity: 0;
      transition: all 0.3s ease;
      -webkit-text-fill-color: initial;
      color: #667eea;
    }

    .schedule-quote.loading .quote-refresh-icon {
      display: none;
    }

    @keyframes quoteSpin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }

    .schedule-quote.fetching .quote-refresh-icon {
      animation: quoteSpin 0.8s linear infinite;
      display: inline-block;
      opacity: 1 !important;
    }

    .card-body {
      padding: 12px;
      flex: 1;
      overflow-y: auto;
      min-height: 0;
    }

    /* 今日课程卡片 */
    .today-card .card-body { display: flex; flex-direction: column; gap: 10px; }

    /* 今日课程项 */
    .today-item {
      background: var(--bg-secondary);
      border-radius: var(--radius-sm);
      padding: 10px 14px;
      position: relative;
      border-left: 4px solid var(--accent);
      display: flex;
      flex-direction: column;
      gap: 4px;
      transition: all 0.2s ease;
      cursor: pointer;
    }

    .today-item:hover {
      background: var(--bg-hover);
      transform: translateX(4px);
    }

    .today-item.active {
      background: linear-gradient(135deg, var(--accent) 0%, var(--primary) 100%);
      color: white;
    }

    .today-item.active:hover {
      transform: scale(1.02);
    }

    /* 课程状态指示点 */
    .status-dot {
      display: inline-block;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      margin-right: 6px;
      vertical-align: middle;
    }

    .status-dot.pending { background: #3B82F6; }
    .status-dot.active { background: #F59E0B; animation: dotPulse 1.5s infinite; }
    .status-dot.finished { background: #10B981; }

    @keyframes dotPulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.7; transform: scale(1.3); }
    }

    /* 上课状态标签 */
    .live-badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 10px;
      font-size: 11px;
      font-weight: 600;
      margin-bottom: 4px;
    }

    .live-badge.active {
      background: rgba(245, 158, 11, 0.3);
      color: #F59E0B;
      animation: pulse 2s infinite;
    }

    .live-badge.finished {
      background: rgba(16, 185, 129, 0.2);
      color: #10B981;
    }

    .live-badge.pending {
      background: rgba(59, 130, 246, 0.2);
      color: #3B82F6;
    }

    .today-item.finished {
      opacity: 0.6;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.6; }
    }

    /* 今日课程项 - 新布局：左内容右时间 */
    .item-content { display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; }
    .item-left { flex: 1; min-width: 0; }
    .item-right { display: flex; flex-direction: column; align-items: flex-end; gap: 2px; flex-shrink: 0; }
    .item-period { font-size: 12px; font-weight: 600; opacity: 0.8; }
    .item-time { font-size: 11px; opacity: 0.8; }
    .item-name { font-size: 14px; font-weight: 600; }
    .item-room { font-size: 12px; opacity: 0.7; margin-top: 2px; }
    .item-progress-bar { display: flex; align-items: center; gap: 8px; margin-top: 8px; }
    .progress-track { flex: 1; height: 4px; background: rgba(255,255,255,0.3); border-radius: 2px; }
    .progress-fill {
      height: 100%;
      background: white;
      border-radius: 2px;
      transition: width 0.5s;
      position: relative;
      overflow: hidden;
    }

    .progress-fill::after {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent);
      animation: shimmer 1.5s infinite;
    }

    @keyframes shimmer {
      0% { transform: translateX(-100%); }
      100% { transform: translateX(100%); }
    }

    .progress-num { font-size: 12px; font-weight: 600; min-width: 35px; text-align: right; }
    .item-remaining { font-size: 11px; opacity: 0.8; margin-top: 2px; }

    /* ===== 今日课程展开详情 ===== */
    .item-expandable {
      max-height: 0;
      overflow: hidden;
      transition: max-height 0.35s cubic-bezier(0.4, 0, 0.2, 1),
                  opacity 0.25s ease,
                  padding 0.35s ease;
      opacity: 0;
      padding: 0;
    }

    .today-item.expanded .item-expandable {
      max-height: 200px;
      opacity: 1;
      padding: 8px 0 4px;
    }

    .expand-note {
      font-size: 12px;
      color: var(--text-secondary);
      line-height: 1.5;
      padding: 6px 10px;
      background: var(--bg-secondary);
      border-radius: 6px;
      margin-bottom: 6px;
    }

    .expand-location {
      font-size: 13px;
      font-weight: 600;
      color: var(--primary);
      margin-bottom: 6px;
    }

    .expand-progress {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-top: 6px;
    }

    .expand-progress .progress-track {
      flex: 1;
      height: 6px;
      background: var(--bg-secondary);
      border-radius: 3px;
    }

    .expand-progress .progress-fill {
      background: linear-gradient(90deg, var(--primary), var(--primary-light));
      height: 100%;
      border-radius: 3px;
      transition: width 0.5s;
    }

    .expand-remaining {
      font-size: 11px;
      color: var(--warning);
      margin-top: 4px;
    }

    /* ===== 待办卡片 ===== */
    .todo-card .card-body { display: flex; flex-direction: column; gap: 8px; }

    /* 待办项 - 增加交互（点击划线） */
    .todo-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      background: var(--bg-secondary);
      border-radius: var(--radius-sm);
      transition: all 0.25s ease;
      cursor: pointer;
    }

    .todo-item:hover {
      background: var(--bg-hover);
      transform: translateX(4px);
    }

    .todo-item.urgent { border-left: 4px solid var(--danger); }
    .todo-item.important { border-left: 4px solid var(--warning); }
    .todo-item.done {
      opacity: 0.55;
    }
    .todo-item.done .todo-text {
      text-decoration: line-through;
      color: var(--text-hint);
    }

    .todo-check {
      width: 20px;
      height: 20px;
      border: 2px solid var(--border);
      border-radius: 50%;
      flex-shrink: 0;
      transition: all 0.25s ease;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
    }

    .todo-check.checked {
      background: var(--success);
      border-color: var(--success);
    }

    .check-icon {
      font-size: 11px;
      color: transparent;
      font-weight: 700;
      transition: color 0.2s ease;
    }

    .todo-item.done .check-icon {
      color: white;
    }

    .todo-check:hover {
      border-color: var(--primary);
      transform: scale(1.15);
    }

    .todo-text { font-size: 13px; flex: 1; transition: all 0.25s ease; }
    .todo-section-title { font-size: 11px; color: var(--text-hint); padding: 4px 0; }

    /* ===== 课表卡片 ===== */
    .schedule-card {
      display: flex;
      flex-direction: column;
    }

    .schedule-grid {
      display: grid;
      grid-template-columns: repeat(7, 1fr);
      gap: 6px;
      padding: 12px;
      flex: 1;
      min-height: 360px;
    }

    .schedule-col {
      display: flex;
      flex-direction: column;
      gap: 6px;
      /* 斑马纹背景 - 非常淡的奇偶列差异 */
    }

    .schedule-col:nth-child(odd) {
      background: transparent;
    }

    .schedule-col:nth-child(even) {
      background: rgba(128, 128, 128, 0.02);
      border-radius: 8px;
      padding: 2px;
    }

    [data-theme="dark"] .schedule-col:nth-child(even) {
      background: rgba(255, 255, 255, 0.01);
    }

    .schedule-col.today .col-header {
      color: var(--primary);
      font-weight: 600;
    }

    .col-header {
      text-align: center;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-secondary);
      padding: 8px 0;
    }

    /* ===== 天气行（在课表 header 下方，增强版） ===== */
    .weather-row {
      font-size: 11px;
      color: var(--text-secondary);
      padding: 5px 2px;
      text-align: center;
      border-bottom: 1px dashed var(--border);
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 2px;
      min-height: 40px;
      justify-content: center;
      border-radius: 8px;
      background: rgba(29, 155, 240, 0.04);
      transition: all 0.2s ease;
      overflow: hidden;
    }

    .weather-row:hover {
      background: rgba(29, 155, 240, 0.08);
    }

    [data-theme="dark"] .weather-row {
      background: rgba(56, 189, 248, 0.06);
    }

    [data-theme="dark"] .weather-row:hover {
      background: rgba(56, 189, 248, 0.1);
    }

    .weather-icon {
      font-size: 16px;
      line-height: 1;
    }

    .weather-info {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 1px;
      width: 100%;
    }

    .weather-temp {
      font-size: 11px;
      font-weight: 600;
      color: var(--text-primary);
      letter-spacing: 0;
    }

    .weather-desc {
      font-size: 9px;
      color: var(--text-tertiary);
      max-width: 100%;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      padding: 0 2px;
    }

    .weather-empty {
      opacity: 0.4;
      font-style: italic;
    }

    /* ===== 周数标签 ===== */
    .week-badge {
      display: inline-flex;
      align-items: center;
      font-size: 12px;
      font-weight: 600;
      color: #fff;
      background: linear-gradient(135deg, var(--primary), #38BDF8);
      padding: 2px 10px;
      border-radius: 12px;
      margin-left: 8px;
      vertical-align: middle;
      letter-spacing: 0.5px;
      box-shadow: 0 2px 6px rgba(29, 155, 240, 0.25);
    }

    /* 学期已结束标签 */
    .week-badge.week-over {
      background: linear-gradient(135deg, #E53935, #FF6B6B);
      box-shadow: 0 2px 6px rgba(229, 57, 53, 0.3);
      animation: pulse-over 2s ease-in-out infinite;
    }

    @keyframes pulse-over {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.75; }
    }

    /* ===== 学期结束遮罩 ===== */
    .semester-over-overlay {
      position: relative;
      margin: 8px 12px;
      border-radius: var(--radius);
      background: linear-gradient(135deg, rgba(229,57,53,0.06), rgba(255,107,107,0.04));
      border: 2px dashed rgba(229,57,53,0.25);
      padding: 24px 16px;
      text-align: center;
    }

    [data-theme="dark"] .semester-over-overlay {
      background: linear-gradient(135deg, rgba(229,57,53,0.1), rgba(255,107,107,0.05));
      border-color: rgba(229,57,53,0.3);
    }

    .semester-over-content {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
    }

    .semester-over-icon {
      font-size: 32px;
      line-height: 1;
    }

    .semester-over-text {
      font-size: 17px;
      font-weight: 700;
      color: #E53935;
      letter-spacing: 2px;
    }

    .semester-over-sub {
      font-size: 12px;
      color: var(--text-tertiary);
    }

    .grid-cell {
      flex: 1;
      border-radius: var(--radius-sm);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 8px 4px;
      text-align: center;
      min-height: 60px;
      transition: all 0.2s ease;
      cursor: pointer;
      position: relative;
    }

    .grid-cell:hover {
      transform: scale(1.05);
      z-index: 10;
    }

    .grid-cell.empty {
      background: var(--bg-secondary);
      border: 1px dashed var(--border);
    }

    .grid-cell.empty:hover {
      background: var(--bg-hover);
      border-color: var(--primary);
    }

    .grid-cell.course {
      background: var(--cell-color);
      color: var(--text-color);
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }

    .grid-cell.course:hover {
      box-shadow: 0 4px 16px rgba(0,0,0,0.2);
    }

    /* ===== 课程格子 tooltip（CSS伪元素实现）===== */
    .grid-cell.course[data-course-name]:hover::after {
      content: attr(data-course-name) "\\a" attr(data-course-time) "\\a" attr(data-course-room);
      position: absolute;
      bottom: calc(100% + 8px);
      left: 50%;
      transform: translateX(-50%) translateY(5px);
      background: var(--text-primary);
      color: var(--bg-card);
      padding: 8px 12px;
      border-radius: 8px;
      font-size: 11px;
      white-space: pre-wrap;
      line-height: 1.6;
      z-index: 200;
      box-shadow: 0 4px 16px rgba(0,0,0,0.2);
      text-align: center;
      min-width: 120px;
      pointer-events: none;
      opacity: 1;
      visibility: visible;
      transition: all 0.2s ease;
      font-weight: normal;
    }

    .grid-cell.course:hover::before {
      content: '';
      position: absolute;
      bottom: calc(100% + 2px);
      left: 50%;
      transform: translateX(-50%);
      border: 6px solid transparent;
      border-top-color: var(--text-primary);
      z-index: 201;
      pointer-events: none;
    }

    .cell-name {
      font-size: 12px;
      font-weight: 600;
      line-height: 1.3;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    .cell-room {
      font-size: 10px;
      opacity: 0.8;
      margin-top: 3px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 100%;
    }

    /* ===== 模态框（课程详情弹窗） ===== */
    .modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(4px);
      -webkit-backdrop-filter: blur(4px);
      z-index: 9999;
      display: flex;
      align-items: center;
      justify-content: center;
      opacity: 0;
      visibility: hidden;
      transition: all 0.3s ease;
      padding: 20px;
    }

    .modal-overlay.show {
      opacity: 1;
      visibility: visible;
    }

    .modal-box {
      background: var(--bg-card);
      border-radius: 20px;
      padding: 32px;
      max-width: 380px;
      width: 100%;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      transform: scale(0.9) translateY(20px);
      transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
      text-align: center;
    }

    .modal-overlay.show .modal-box {
      transform: scale(1) translateY(0);
    }

    .modal-course-name {
      font-size: 22px;
      font-weight: 700;
      color: var(--text-primary);
      margin-bottom: 16px;
      line-height: 1.3;
    }

    .modal-info-row {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 8px 0;
      font-size: 14px;
      color: var(--text-secondary);
    }

    .modal-info-label {
      font-size: 13px;
      font-weight: 500;
      color: var(--text-hint);
      min-width: 60px;
      text-align: right;
    }

    .modal-info-value {
      font-weight: 600;
      color: var(--text-primary);
      text-align: left;
    }

    .modal-close-btn {
      margin-top: 24px;
      padding: 10px 36px;
      border: none;
      border-radius: 12px;
      background: linear-gradient(135deg, var(--primary), var(--accent));
      color: white;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
    }

    .modal-close-btn:hover {
      transform: scale(1.05);
      box-shadow: 0 4px 16px rgba(0,122,255,0.35);
    }

    .modal-close-btn:active {
      transform: scale(0.97);
    }

    /* ===== 空状态 ===== */
    .module-empty {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      min-height: 80px;
      gap: 6px;
    }

    .empty-icon { font-size: 28px; }
    .empty-text { font-size: 12px; color: var(--text-hint); }

    /* ===== 快捷键提示 ===== */
    .shortcut-hint {
      text-align: center;
      font-size: 11px;
      color: var(--text-hint);
      padding: 8px 0 4px;
      letter-spacing: 0.3px;
    }

    .shortcut-hint kbd {
      display: inline-block;
      padding: 1px 6px;
      background: var(--bg-secondary);
      border-radius: 4px;
      font-family: inherit;
      font-size: 10px;
      font-weight: 600;
      border: 1px solid var(--border);
      margin: 0 2px;
    }

    /* ===== 平板适配 ===== */
    @media (min-width: 768px) and (max-width: 1024px) {
      .top-row {
        grid-template-columns: 240px 1fr;
        gap: 16px;
      }

      .card-body {
        padding: 12px;
      }

      .cell-name {
        font-size: 12px;
      }
    }

    /* ===== 响应式 - 手机 ===== */
    @media (max-width: 767px) {
      .main-container {
        padding: 56px 12px 16px;
        gap: 12px;
      }

      .topbar {
        flex-wrap: wrap;
        gap: 10px;
        padding: 12px 14px;
      }

      .topbar-left {
        order: 1;
      }

      .topbar-right {
        order: 2;
      }

      .topbar-center {
        order: 3;
        flex-basis: 100%;
        text-align: left;
      }

      .topbar-avatar {
        width: 38px;
        height: 38px;
      }

      .topbar-avatar-placeholder {
        width: 38px;
        height: 38px;
        font-size: 18px;
      }

      .topbar-username {
        font-size: 14px;
      }

      .topbar-date {
        font-size: 12px;
      }

      .topbar-time {
        font-size: 18px;
      }

      .top-row {
        grid-template-columns: 1fr;
        grid-template-rows: auto 1fr;
        gap: 12px;
      }

      .left-modules {
        display: grid;
        grid-template-columns: 1fr 1fr;
        grid-template-rows: auto;
        gap: 12px;
      }

      .today-card .card-body {
        gap: 12px;
      }

      .today-item {
        padding: 12px 14px;
      }

      .schedule-grid {
        min-height: 250px;
        gap: 8px;
      }

      .grid-cell {
        min-height: 55px;
        padding: 6px 4px;
      }

      .cell-name {
        font-size: 11px;
      }

      .cell-room {
        font-size: 9px;
      }

      .schedule-quote {
        font-size: 12px;
        max-width: 160px;
      }

      .stats-bar {
        font-size: 11px;
        justify-content: center;
      }

      /* 手机端隐藏 tooltip */
      .grid-cell.course:hover::after,
      .grid-cell.course:hover::before {
        display: none;
      }
    }

    /* ===== 大屏优化 ===== */
    @media (min-width: 1200px) {
      .top-row {
        grid-template-columns: 320px 1fr;
      }
    }

    /* ===== 动画 ===== */
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    @keyframes fadeInLeft {
      from { opacity: 0; transform: translateX(-20px); }
      to { opacity: 1; transform: translateX(0); }
    }

    @keyframes fadeInRight {
      from { opacity: 0; transform: translateX(20px); }
      to { opacity: 1; transform: translateX(0); }
    }

    @keyframes scaleIn {
      from { opacity: 0; transform: scale(0.9); }
      to { opacity: 1; transform: scale(1); }
    }

    .card { animation: fadeIn 0.4s ease; }
    .card:nth-child(1) { animation-delay: 0.1s; }
    .card:nth-child(2) { animation-delay: 0.2s; }
    .topbar { animation: fadeIn 0.3s ease; }

    /* 课表格子入场动画 */
    .schedule-col:nth-child(1) { animation: fadeInLeft 0.4s ease 0.1s both; }
    .schedule-col:nth-child(2) { animation: fadeInLeft 0.4s ease 0.15s both; }
    .schedule-col:nth-child(3) { animation: fadeInLeft 0.4s ease 0.2s both; }
    .schedule-col:nth-child(4) { animation: fadeInLeft 0.4s ease 0.25s both; }
    .schedule-col:nth-child(5) { animation: fadeInLeft 0.4s ease 0.3s both; }
    .schedule-col:nth-child(6) { animation: fadeInLeft 0.4s ease 0.35s both; }
    .schedule-col:nth-child(7) { animation: fadeInLeft 0.4s ease 0.4s both; }

    /* 今日课程入场动画 */
    .today-item { animation: fadeIn 0.3s ease both; }
    .today-item:nth-child(1) { animation-delay: 0.1s; }
    .today-item:nth-child(2) { animation-delay: 0.15s; }
    .today-item:nth-child(3) { animation-delay: 0.2s; }
    .today-item:nth-child(4) { animation-delay: 0.25s; }

    /* 待办事项入场动画 */
    .todo-item { animation: fadeIn 0.3s ease both; }
    .todo-item:nth-child(1) { animation-delay: 0.1s; }
    .todo-item:nth-child(2) { animation-delay: 0.15s; }
    .todo-item:nth-child(3) { animation-delay: 0.2s; }
    .todo-item:nth-child(4) { animation-delay: 0.25s; }
  </style>
</head>
<body>
  <div class="main-container">
    <!-- 顶部状态栏 -->
    <div class="topbar">
      <div class="topbar-left">
        ${_userAvatarPath.isNotEmpty ? '<img class="topbar-avatar" src="/api/avatar" alt="avatar">' : '<div class="topbar-avatar-placeholder">👤</div>'}
        <div class="topbar-user-info">
          <span class="topbar-username">${_userName.isNotEmpty ? _userName : '教师'}</span>
          <span class="topbar-date">$todayStr $todayName${_weather != null && _weather!.location.isNotEmpty ? ' · 📍 ${_weather!.location}' : ''}</span>
        </div>
      </div>
      <div class="topbar-center">
        <div class="stats-bar">
          📚 本周 <span class="stat-num">$totalWeeklyCourses</span> 节 ·
          今日 <span class="stat-num">${todayCourses.length}</span> 节 ·
          已上 <span class="stat-num">$completedTotal</span> 节
        </div>
        <div class="topbar-status">$statusIcon ${currentStatus}${nextCourseName.isNotEmpty ? ' $nextCourseName' : ''}</div>
      </div>
      <div class="topbar-right">
        <span class="topbar-time" id="liveTime">--:<span class="time-colon">:</span>--</span>
        <button class="theme-toggle" id="themeBtn" onclick="toggleTheme()" ontouchend="toggleTheme();event.preventDefault();" title="切换主题">🌓</button>
      </div>
    </div>

    <!-- 第一行：左侧模块 + 课表 -->
    <div class="top-row">
      <!-- 左侧两个模块 -->
      <div class="left-modules">
        <!-- 今日课程 -->
        <div class="card today-card">
          <div class="card-header">
            <div class="card-icon">📚</div>
            <span class="card-title">今日课程</span>
          </div>
          <div class="card-body">
            $todayCoursesHtml
          </div>
        </div>

        <!-- 待办事项 -->
        <div class="card todo-card">
          <div class="card-header">
            <div class="card-icon">✅</div>
            <span class="card-title">待办事项</span>
          </div>
          <div class="card-body">
            $todosHtml
          </div>
        </div>
      </div>

      <!-- 本周课表 -->
      <div class="card schedule-card">
        <div class="card-header">
          <span class="card-title">📅 本周课程表 <span class="week-badge ${isSemesterOver ? 'week-over' : ''}">${isSemesterOver ? '已结束' : '第$weekNumber/$totalWeeks 周'}</span></span>
          <span class="schedule-quote" id="quoteText" onclick="fetchPoem()" ontouchend="fetchPoem();event.preventDefault();" title="点击刷新诗词"><span class="quote-content">📜 正在寻找今日诗词...<span class="quote-refresh-icon">🔄</span></span></span>
        </div>
        <div class="schedule-grid">
          $scheduleGridHtml
        </div>
        ${isSemesterOver ? '''
        <div class="semester-over-overlay">
          <div class="semester-over-content">
            <span class="semester-over-icon">🎓</span>
            <span class="semester-over-text">本学期已结束</span>
            <span class="semester-over-sub">课程提醒已暂停，请到 APP 设置新学期</span>
          </div>
        </div>
        ''' : ''}
      </div>
    </div>

  </div>

  <!-- 课程详情模态框 -->
  <div class="modal-overlay" id="courseModal" onclick="closeModal(event)">
    <div class="modal-box" onclick="event.stopPropagation()">
      <div class="modal-course-name" id="modalCourseName">课程名称</div>
      <div class="modal-info-row">
        <span class="modal-info-label">🕐 时间</span>
        <span class="modal-info-value" id="modalTime">--</span>
      </div>
      <div class="modal-info-row">
        <span class="modal-info-label">📍 地点</span>
        <span class="modal-info-value" id="modalRoom">--</span>
      </div>
      <div class="modal-info-row">
        <span class="modal-info-label">📝 备注</span>
        <span class="modal-info-value" id="modalNote">--</span>
      </div>
      <div class="modal-info-row">
        <span class="modal-info-label">📅 节次</span>
        <span class="modal-info-value" id="modalPeriod">--</span>
      </div>
      <button class="modal-close-btn" onclick="closeModal()">知道了</button>
    </div>
  </div>

  <script>
    // ========================================
    // 1. 涟漪点击效果
    // ========================================
    document.addEventListener('DOMContentLoaded', () => {
      const style = document.createElement('style');
      style.textContent = \`
        .ripple {
          position: absolute;
          border-radius: 50%;
          background: rgba(29, 155, 240, 0.3);
          transform: scale(0);
          animation: ripple-effect 0.6s ease-out;
          pointer-events: none;
        }
        @keyframes ripple-effect {
          to {
            transform: scale(4);
            opacity: 0;
          }
        }
      \`;
      document.head.appendChild(style);

      document.querySelectorAll('.card, .today-item, .todo-item, .grid-cell').forEach(el => {
        el.style.position = 'relative';
        el.style.overflow = 'hidden';
        el.addEventListener('click', function(e) {
          const ripple = document.createElement('span');
          ripple.className = 'ripple';
          const rect = this.getBoundingClientRect();
          const size = Math.max(rect.width, rect.height);
          ripple.style.width = ripple.style.height = size + 'px';
          ripple.style.left = (e.clientX - rect.left - size / 2) + 'px';
          ripple.style.top = (e.clientY - rect.top - size / 2) + 'px';
          this.appendChild(ripple);
          setTimeout(() => ripple.remove(), 600);
        });
      });

      // 初始加载诗词
      fetchPoem();

      // 每5分钟自动刷新一首新诗
      setInterval(fetchPoem, 300000);
    });

    // ========================================
    // 2. 今日诗词 API
    // ========================================
    function fetchPoem() {
      const el = document.getElementById('quoteText');
      if (!el) return;

      el.classList.add('fetching');

      fetch('https://v1.jinrishici.com/one.json')
        .then(res => res.json())
        .then(data => {
          if (data.content && data.origin && data.author) {
            const text = '📜 ' + data.content + ' ——' + data.author + '《' + data.origin + '》';
            // 设置到 .quote-content 内部，保留 marquee 滚动容器
            let contentEl = el.querySelector('.quote-content');
            if (!contentEl) {
              contentEl = document.createElement('span');
              contentEl.className = 'quote-content';
              el.appendChild(contentEl);
            }
            contentEl.textContent = text;
          } else {
            showFallbackPoem(el);
          }
          el.classList.remove('loading', 'fetching');
        })
        .catch(() => {
          showFallbackPoem(el);
          el.classList.remove('fetching');
        });
    }

    function showFallbackPoem(el) {
      let contentEl = el.querySelector('.quote-content');
      if (!contentEl) {
        contentEl = document.createElement('span');
        contentEl.className = 'quote-content';
        el.appendChild(contentEl);
      }
      contentEl.textContent = '📜 春蚕到死丝方尽，蜡炬成灰泪始干 ——李商隐《无题》';
      el.classList.remove('loading', 'fetching');
    }

    // ========================================
    // 3. 实时时钟（带冒号闪烁）
    // ========================================
    function updateTime() {
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const seconds = String(now.getSeconds()).padStart(2, '0');
      const timeEl = document.getElementById('liveTime');
      if (timeEl) {
        timeEl.innerHTML = hours + ':<span class="time-colon">:</span>' + minutes;
      }
    }
    updateTime();
    setInterval(updateTime, 1000);

    // ========================================
    // 4. 深浅模式切换
    // ========================================
    function toggleTheme() {
      const html = document.documentElement;
      const currentTheme = html.getAttribute('data-theme');
      if (currentTheme === 'dark') {
        html.removeAttribute('data-theme');
        localStorage.setItem('theme', 'light');
      } else {
        html.setAttribute('data-theme', 'dark');
        localStorage.setItem('theme', 'dark');
      }
    }

    // 读取保存的主题
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark');
    }

    // ========================================
    // 5. 课程格子弹出详情模态框
    // ========================================
    document.querySelectorAll('.grid-cell.course').forEach(cell => {
      cell.addEventListener('click', function(e) {
        e.stopPropagation();
        const name = this.dataset.courseName || '未知课程';
        const time = this.dataset.courseTime || '--';
        const room = this.dataset.courseRoom || '未指定';
        const note = this.dataset.courseNote || '暂无备注';
        const period = (this.dataset.coursePeriod || '') + ' ' + (this.dataset.courseWeekday || '');

        document.getElementById('modalCourseName').textContent = name;
        document.getElementById('modalTime').textContent = time;
        document.getElementById('modalRoom').textContent = room;
        document.getElementById('modalNote').textContent = note;
        document.getElementById('modalPeriod').textContent = period.trim();

        openModal();
      });
    });

    function openModal() {
      document.getElementById('courseModal').classList.add('show');
    }

    function closeModal(e) {
      if (e && e.target !== e.currentTarget) return;
      document.getElementById('courseModal').classList.remove('show');
    }

    // ========================================
    // 6. 今日课程项点击展开/收起详情
    // ========================================
    document.querySelectorAll('.today-item').forEach(item => {
      item.addEventListener('click', function(e) {
        this.classList.toggle('expanded');
      });
    });

    // ========================================
    // 7. 待办事项点击划线效果
    // ========================================
    document.querySelectorAll('.todo-item:not(.done)').forEach(item => {
      item.addEventListener('click', function(e) {
        e.stopPropagation();
        this.classList.toggle('done');
        const checkEl = this.querySelector('.todo-check');
        if (checkEl) checkEl.classList.toggle('checked');
      });
    });

    // ========================================
    // 8. 键盘快捷键（仅 T 切换主题，其余用触摸操作）
    // ========================================
    document.addEventListener('keydown', function(e) {
      // 忽略输入框中的按键
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

      if (e.key.toLowerCase() === 't') {
        toggleTheme();
      }
    });
  </script>
</body>
</html>
''';
  }

  /// HTML 属性转义，防 XSS
  String _escapeAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// 计算课程进度
  /// 返回值：负数=未开始，0-99=上课中，100=已结束
  int _calculateProgress(String startTime, String endTime) {
    try {
      final now = DateTime.now();
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      final start = DateTime(now.year, now.month, now.day,
          int.parse(startParts[0]), int.parse(startParts[1]));
      final end = DateTime(now.year, now.month, now.day,
          int.parse(endParts[0]), int.parse(endParts[1]));

      if (now.isBefore(start)) return -1;  // 未开始
      if (now.isAfter(end)) return 100;    // 已结束

      final total = end.difference(start).inMinutes;
      final elapsed = now.difference(start).inMinutes;
      return ((elapsed / total) * 100).round();
    } catch (e) {
      return -1;
    }
  }

  /// 获取剩余时间
  String _getRemainingTime(String endTime) {
    try {
      final now = DateTime.now();
      final endParts = endTime.split(':');
      final end = DateTime(now.year, now.month, now.day,
          int.parse(endParts[0]), int.parse(endParts[1]));

      if (now.isAfter(end)) return '已下课';

      final diff = end.difference(now);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      if (hours > 0) return '${hours}h${minutes}m';
      return '${minutes}分钟';
    } catch (e) {
      return '';
    }
  }

  /// 获取当前课程
  CourseEntry? _getCurrentCourse(List<CourseEntry> courses) {
    for (final course in courses) {
      final progress = _calculateProgress(course.startTime, course.endTime);
      if (progress > 0 && progress < 100) return course;
    }
    return null;
  }

  /// 获取下一节课
  CourseEntry? _getNextCourse(List<CourseEntry> courses) {
    final now = DateTime.now();
    for (final course in courses) {
      final startParts = course.startTime.split(':');
      final start = DateTime(now.year, now.month, now.day,
          int.parse(startParts[0]), int.parse(startParts[1]));
      if (start.isAfter(now)) return course;
    }
    return null;
  }

  /// 获取对比色（白或黑）
  String _getContrastColor(dynamic color) {
    final r = (color.value >> 16) & 0xFF;
    final g = (color.value >> 8) & 0xFF;
    final b = color.value & 0xFF;
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? '#1C1C1E' : '#FFFFFF';
  }

  /// 获取节次名称
  String _getPeriodName(int period) {
    switch (period) {
      case 1: return '第1-2节';
      case 2: return '第3-4节';
      case 3: return '第5-6节';
      case 4: return '第7-8节';
      default: return '第$period节';
    }
  }
}
