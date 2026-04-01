import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/course_model.dart';
import '../models/todo_model.dart';

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

  /// 生成 Web 页面
  String _generateWebPage() {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final todayName = weekdayNames[todayWeekday];
    final todayStr = '${now.month}月${now.day}日';
    final todayCourses = _courses.where((c) => c.weekday == todayWeekday).toList();
    todayCourses.sort((a, b) => a.startTime.compareTo(b.startTime));

    // 构建 7×4 课程网格
    String scheduleGridHtml = '';
    for (int day = 1; day <= 7; day++) {
      scheduleGridHtml += '<div class="schedule-col ${day == todayWeekday ? 'today' : ''}">';
      scheduleGridHtml += '<div class="col-header">${weekdayNames[day]}</div>';
      for (int period = 1; period <= 4; period++) {
        final course = _courses.where((c) => c.weekday == day && c.periodIndex == period).firstOrNull;
        if (course != null) {
          final colorHex = '#${course.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
          final textColor = _getContrastColor(course.color);
          scheduleGridHtml += '''
            <div class="grid-cell course" style="--cell-color: $colorHex; --text-color: $textColor">
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

    // 构建今日课程
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
          <div class="today-item ${isActive ? 'active' : ''} ${isFinished ? 'finished' : ''}" style="--accent: $colorHex">
            <div class="item-content">
              <div class="item-left">
                <div class="item-name">$statusLabel</div>
                <div class="item-room">${course.classroom.isEmpty ? '-' : course.classroom}</div>
              </div>
              <div class="item-right">
                <span class="item-period">$periodName</span>
                <span class="item-time">${course.startTime}-${course.endTime}</span>
              </div>
            </div>
            ${isActive ? '''
              <div class="item-progress">
                <div class="progress-track"><div class="progress-fill" style="width:${progress}%"></div></div>
                <span class="progress-num">$progress%</span>
              </div>
              <div class="item-remaining">剩余 ${_getRemainingTime(course.endTime)}</div>
            ''' : ''}
          </div>
        ''';
      }
    }

    // 构建待办事项
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
          <div class="todo-item $priorityClass">
            <div class="todo-check"></div>
            <span class="todo-text">$priorityIcon${todo.title}</span>
          </div>
        ''';
      }
      if (completedTodos.isNotEmpty) {
        todosHtml += '<div class="todo-section-title">已完成</div>';
        for (final todo in completedTodos) {
          todosHtml += '''
            <div class="todo-item done">
              <div class="todo-check checked"></div>
              <span class="todo-text">${todo.title}</span>
            </div>
          ''';
        }
      }
    }

    // 天气数据 - 紧凑单行版
    String weatherHtml = '';
    if (_weather != null) {
      // 计算降水概率最高的值
      final maxPrecip = _weather!.hourlyForecast.isNotEmpty
          ? _weather!.hourlyForecast.map((h) => h.precipProbability).reduce((a, b) => a > b ? a : b)
          : 0;
      final precipText = maxPrecip > 0 ? '${maxPrecip.toInt()}%' : '无';

      // 7天预报 - 紧凑文字版
      String weeklyCompactHtml = '';
      for (final f in _weather!.forecast.take(7)) {
        weeklyCompactHtml += '''
          <span class="week-compact-item">
            <span class="week-compact-day">${f.weekday}</span>
            <span class="week-compact-icon">${f.weatherIcon}</span>
            <span class="week-compact-temp">${f.tempMax}°</span>
          </span>
        ''';
      }

      // 合并建议
      final nextCourse = _getNextCourse(todayCourses);
      final adviceText = '🎒${_weather!.travelAdvice} · 👔${_weather!.clothingAdvice}${nextCourse != null ? ' · 📚下一节${nextCourse.courseName}' : ''}';

      weatherHtml = '''
        <!-- 当前天气 -->
        <div class="current-weather">
          <span class="weather-icon-lg">${_weather!.weatherIcon}</span>
          <div class="weather-temp-main">
            <span class="temp-num">${_weather!.temp}</span>
            <span class="temp-unit">°C</span>
          </div>
          <span class="weather-desc">${_weather!.weatherText}</span>
        </div>

        <!-- 降水信息 -->
        <div class="precip-info">
          <span class="precip-icon">💧</span>
          <span>降水$precipText</span>
        </div>

        <!-- 7天预报 -->
        <div class="weekly-compact">
          $weeklyCompactHtml
        </div>

        <!-- 上课建议 -->
        <div class="advice-compact" title="$adviceText">
          <span>$adviceText</span>
        </div>
      ''';
    } else {
      weatherHtml = '''
        <div class="module-empty">
          <span class="empty-icon">🌤️</span>
          <span class="empty-text">天气数据加载中...</span>
        </div>
      ''';
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

    /* 主容器 - 可滚动布局 */
    .main-container {
      max-width: 1400px;
      margin: 0 auto;
      padding: 16px 16px 24px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    /* 顶部状态栏 */
    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 20px;
      background: var(--bg-card);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
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

    .topbar-center {
      flex: 1;
      text-align: center;
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

    /* 通用卡片 */
    .card {
      background: var(--bg-card);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      transition: background 0.3s;
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

    /* 课表标题后的古诗词 */
    .schedule-quote {
      font-size: 12px;
      color: var(--text-hint);
      font-style: italic;
      margin-left: auto;
      transition: opacity 0.5s;
    }

    .card-body {
      padding: 12px;
      flex: 1;
      overflow-y: auto;
      min-height: 0;
    }

    /* 今日课程卡片 */
    .today-card .card-body { display: flex; flex-direction: column; gap: 10px; }

    .today-item {
      background: var(--bg-secondary);
      border-radius: var(--radius-sm);
      padding: 10px 14px;
      position: relative;
      border-left: 4px solid var(--accent);
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .today-item.active {
      background: linear-gradient(135deg, var(--accent) 0%, var(--primary) 100%);
      color: white;
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

    .status-dot.pending { background: #3B82F6; }  /* 蓝色 - 未开始 */
    .status-dot.active { background: #F59E0B; animation: dotPulse 1.5s infinite; }  /* 黄色 - 上课中 */
    .status-dot.finished { background: #10B981; }  /* 绿色 - 已结束 */

    @keyframes dotPulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.7; transform: scale(1.2); }
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
    .item-progress { display: flex; align-items: center; gap: 8px; margin-top: 8px; }
    .progress-track { flex: 1; height: 4px; background: rgba(255,255,255,0.3); border-radius: 2px; }
    .progress-fill { height: 100%; background: white; border-radius: 2px; transition: width 0.5s; }
    .progress-num { font-size: 12px; font-weight: 600; min-width: 35px; text-align: right; }
    .item-remaining { font-size: 11px; opacity: 0.8; margin-top: 2px; }

    /* 待办卡片 */
    .todo-card .card-body { display: flex; flex-direction: column; gap: 8px; }

    .todo-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      background: var(--bg-secondary);
      border-radius: var(--radius-sm);
    }

    .todo-item.urgent { border-left: 4px solid var(--danger); }
    .todo-item.important { border-left: 4px solid var(--warning); }
    .todo-item.done { opacity: 0.5; }
    .todo-item.done .todo-text { text-decoration: line-through; }

    .todo-check {
      width: 18px;
      height: 18px;
      border: 2px solid var(--border);
      border-radius: 50%;
      flex-shrink: 0;
    }

    .todo-check.checked {
      background: var(--success);
      border-color: var(--success);
    }

    .todo-text { font-size: 13px; flex: 1; }
    .todo-section-title { font-size: 11px; color: var(--text-hint); padding: 4px 0; }

    /* 课表卡片 */
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
      min-height: 300px;
    }

    .schedule-col {
      display: flex;
      flex-direction: column;
      gap: 6px;
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
    }

    .grid-cell.empty {
      background: var(--bg-secondary);
      border: 1px dashed var(--border);
    }

    .grid-cell.course {
      background: var(--cell-color);
      color: var(--text-color);
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

    /* 天气卡片 - 横向布局 */
    .weather-card {
      flex-shrink: 0;
      min-height: 180px;
    }

    /* 天气卡片 - 紧凑单行布局 */
    .weather-card {
      min-height: unset;
    }

    .weather-card .card-body {
      padding: 12px 16px;
      display: flex;
      align-items: center;
      gap: 20px;
      overflow: hidden;
    }

    /* 当前天气 */
    .current-weather {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-shrink: 0;
    }

    .weather-icon-lg { font-size: 32px; line-height: 1; }
    .weather-temp-main { display: flex; align-items: baseline; gap: 2px; }
    .temp-num { font-size: 28px; font-weight: 700; line-height: 1; }
    .temp-unit { font-size: 14px; color: var(--text-secondary); }
    .weather-desc { font-size: 12px; color: var(--text-secondary); }

    /* 降水信息 - 文字简洁版 */
    .precip-info {
      flex-shrink: 0;
      font-size: 12px;
      color: var(--text-secondary);
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 4px 10px;
      background: var(--bg-secondary);
      border-radius: var(--radius-sm);
    }

    .precip-icon { font-size: 14px; }

    /* 7天预报 - 紧凑横排 */
    .weekly-compact {
      flex: 1;
      display: flex;
      gap: 12px;
      overflow: hidden;
    }

    .week-compact-item {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 12px;
      white-space: nowrap;
      flex-shrink: 0;
    }

    .week-compact-day { color: var(--text-secondary); }
    .week-compact-icon { font-size: 14px; }
    .week-compact-temp { color: var(--text-primary); font-weight: 500; }

    /* 建议 - 单行合并 */
    .advice-compact {
      flex-shrink: 0;
      font-size: 12px;
      color: var(--text-secondary);
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 4px 12px;
      background: var(--bg-secondary);
      border-radius: var(--radius-sm);
      max-width: 280px;
    }

    .advice-compact span {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    /* 空状态 */
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

    /* 平板适配 - iPad / Android Pad */
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

    /* 响应式 - 手机 */
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

      /* 小分辨率课程间距优化 */
      .today-card .card-body {
        gap: 12px;
      }

      .today-item {
        padding: 12px 14px;
      }

      .weather-card .card-body {
        flex-wrap: wrap;
        justify-content: center;
        gap: 12px;
      }

      /* 天气卡片小屏处理 */
      .weather-card .card-body {
        flex-wrap: wrap;
        gap: 12px;
      }

      .weekly-compact {
        order: 10;
        width: 100%;
        justify-content: space-around;
      }

      .advice-compact {
        max-width: 100%;
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

      /* 古诗词在小屏隐藏 */
      .schedule-quote {
        display: none;
      }
    }

    /* 大屏优化 */
    @media (min-width: 1200px) {
      .top-row {
        grid-template-columns: 320px 1fr;
      }
    }

    /* 动画 */
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .card { animation: fadeIn 0.4s ease; }
    .topbar { animation: fadeIn 0.3s ease; }
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
          <span class="topbar-date">$todayStr $todayName</span>
        </div>
      </div>
      <div class="topbar-center">
        <span class="topbar-status">$statusIcon ${currentStatus}${nextCourseName.isNotEmpty ? ' $nextCourseName' : ''}</span>
      </div>
      <div class="topbar-right">
        <span class="topbar-time" id="liveTime">--:--:--</span>
        <button class="theme-toggle" id="themeBtn" onclick="toggleTheme()" ontouchend="toggleTheme();event.preventDefault();" title="切换主题">🌓</button>
      </div>
    </div>

    <!-- 上课天气预报 - 姓名头像下方 -->
    <div class="card weather-card">
      <div class="card-header">
        <div class="card-icon">🌤️</div>
        <span class="card-title">上课天气预报</span>
      </div>
      <div class="card-body">
        $weatherHtml
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
          <div class="card-icon">📅</div>
          <span class="card-title">本周课程表</span>
          <span class="schedule-quote" id="quoteText">📜 读万卷书，行万里路</span>
        </div>
        <div class="schedule-grid">
          $scheduleGridHtml
        </div>
      </div>
    </div>
  </div>

  <script>
    // 励志古诗词库
    const quotes = [
      "📜 读万卷书，行万里路",
      "📜 书山有路勤为径，学海无涯苦作舟",
      "📜 春蚕到死丝方尽，蜡炬成灰泪始干",
      "📜 落红不是无情物，化作春泥更护花",
      "📜 随风潜入夜，润物细无声",
      "📜 采得百花成蜜后，为谁辛苦为谁甜",
      "📜 人生自古谁无死，留取丹心照汗青",
      "📜 先天下之忧而忧，后天下之乐而乐",
      "📜 业精于勤，荒于嬉；行成于思，毁于随",
      "📜 纸上得来终觉浅，绝知此事要躬行",
      "📜 问渠那得清如许？为有源头活水来",
      "📜 旧书不厌百回读，熟读深思子自知",
      "📜 千淘万漉虽辛苦，吹尽狂沙始到金",
      "📜 长风破浪会有时，直挂云帆济沧海",
      "📜 会当凌绝顶，一览众山小"
    ];

    let currentQuoteIndex = 0;

    function updateQuote() {
      const quoteEl = document.getElementById('quoteText');
      if (quoteEl) {
        quoteEl.style.opacity = '0';
        setTimeout(() => {
          currentQuoteIndex = (currentQuoteIndex + 1) % quotes.length;
          quoteEl.textContent = quotes[currentQuoteIndex];
          quoteEl.style.opacity = '1';
        }, 300);
      }
    }

    // 每3分钟切换一次
    setInterval(updateQuote, 180000);

    // 实时时钟
    function updateTime() {
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const seconds = String(now.getSeconds()).padStart(2, '0');
      document.getElementById('liveTime').textContent = hours + ':' + minutes + ':' + seconds;
    }
    updateTime();
    setInterval(updateTime, 1000);

    // 深浅模式切换
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
  </script>
</body>
</html>
''';
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
    // Flutter Color 对象的计算方式
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
