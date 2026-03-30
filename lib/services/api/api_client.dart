import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exceptions.dart';
import 'api_response.dart';
import 'models/schedule_model.dart';
import 'models/auth_model.dart';
import 'models/task_model.dart';

/// 正方教务系统 API 客户端
/// 
/// 支持与模拟 API 或真实 API 交互的客户端类。
/// 在生产环境使用真实 API 地址，开发/测试时可连接本地 mock 服务器。
class ZhengFangApiClient {
  final String baseUrl;
  final http.Client client;
  String? _token;
  String? _userId;

  ZhengFangApiClient({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'http://localhost:5000', // 默认连接本地 mock
        client = client ?? http.Client();

  /// 设置认证信息（登录成功后存储）
  void setAuth(String token, String userId) {
    _token = token;
    _userId = userId;
  }

  /// 清理认证信息（登出时调用）
  void clearAuth() {
    _token = null;
    _userId = null;
  }

  /// 获取请求头（包含认证信息）
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  /// 执行 HTTP 请求并处理异常
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = _getHeaders();

      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await client.get(url, headers: headers);
          break;
        case 'POST':
          final body = data != null ? jsonEncode(data) : null;
          response = await client.post(url, headers: headers, body: body);
          break;
        case 'PUT':
          final body = data != null ? jsonEncode(data) : null;
          response = await client.put(url, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await client.delete(url, headers: headers);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      // 解析响应
      final responseBody = response.body.isNotEmpty 
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      // HTTP 错误处理
      if (response.statusCode >= 400) {
        final errorMsg = responseBody['message'] ?? response.reasonPhrase;
        throw ApiException(
          'HTTP ${response.statusCode}: $errorMsg',
          statusCode: response.statusCode,
        );
      }

      return responseBody;
    } catch (e) {
      if (e is ApiException) rethrow;
      
      // 网络错误或 JSON 解析错误
      if (e is FormatException) {
        throw ApiException('Invalid JSON response: ${e.message}');
      }
      
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// 健康检查 - 测试 API 连接
  Future<ApiResponse<String>> healthCheck() async {
    try {
      final response = await _request('GET', '/api/health');
      final healthy = response['healthy'] == true;
      final message = response['message'] ?? '';
      
      return ApiResponse.success(
        data: message,
        message: message,
      );
    } on ApiException catch (e) {
      return ApiResponse.error(
        error: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  /// 用户登录
  Future<ApiResponse<LoginResponse>> login(LoginRequest request) async {
    try {
      final response = await _request('POST', '/api/auth/login', data: {
        'username': request.username,
        'password': request.password,
        'userType': request.userType,
      });

      final token = response['token'] as String?;
      final userId = response['userId'] as String?;
      final userRole = response['userRole'] as String?;
      final username = response['username'] as String?;

      if (token == null || userId == null) {
        throw ApiException('Invalid response: missing token or userId');
      }

      // 存储认证信息
      setAuth(token, userId);

      return ApiResponse.success(
        data: LoginResponse(
          token: token,
          userId: userId,
          userRole: userRole ?? 'teacher',
          username: username ?? request.username,
          expiresAt: DateTime.now().add(const Duration(hours: 2)),
        ),
        message: '登录成功',
      );
    } on ApiException catch (e) {
      return ApiResponse.error(
        error: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  /// 获取教师课表（默认本周）
  Future<ApiResponse<List<Course>>> getTeacherSchedule({
    String? teacherId,
    String? weekNum,
  }) async {
    try {
      final teacher = teacherId ?? _userId;
      if (teacher == null) {
        throw ApiException('Teacher ID not provided and user not logged in');
      }

      final path = weekNum != null
          ? '/api/teacher/schedule/week/$weekNum'
          : '/api/teacher/schedule';
      
      final response = await _request('GET', path, data: {
        'teacherId': teacher,
      });

      final scheduleData = response['schedule'] as List? ?? [];
      final courses = scheduleData.map((item) => Course.fromJson(item as Map<String, dynamic>)).toList();

      return ApiResponse.success(
        data: courses,
        message: '获取课表成功',
      );
    } on ApiException catch (e) {
      return ApiResponse.error(
        error: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  /// 获取任务清单
  Future<ApiResponse<List<Task>>> getTeacherTasks({
    String? teacherId,
    String? status,
    String? beforeDate,
  }) async {
    try {
      final teacher = teacherId ?? _userId;
      if (teacher == null) {
        throw ApiException('Teacher ID not provided and user not logged in');
      }

      final queryParams = <String, dynamic>{'teacherId': teacher};
      if (status != null) queryParams['status'] = status;
      if (beforeDate != null) queryParams['beforeDate'] = beforeDate;

      final response = await _request('GET', '/api/teacher/tasks', data: queryParams);

      final tasksData = response['tasks'] as List? ?? [];
      final tasks = tasksData.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList();

      return ApiResponse.success(
        data: tasks,
        message: '获取任务成功',
      );
    } on ApiException catch (e) {
      return ApiResponse.error(
        error: e.message,
        statusCode: e.statusCode,
      );
    }
  }
}