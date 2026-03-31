import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'api_response.dart';
import 'models/auth_model.dart';
import 'models/schedule_model.dart';
import 'models/task_model.dart';

/// API 服务管理器
/// 
/// 提供单例访问，管理API客户端的生命周期和认证状态。
class ApiServiceManager {
  static final ApiServiceManager _instance = ApiServiceManager._internal();
  late ZhengFangApiClient _apiClient;
  bool _isInitialized = false;
  UserProfile? _currentUser;
  LoginResponse? _currentLogin;

  factory ApiServiceManager() {
    return _instance;
  }

  ApiServiceManager._internal();

  /// 初始化API服务
  Future<void> initialize({
    String? baseUrl,
    http.Client? client,
  }) async {
    if (_isInitialized) return;

    _apiClient = ZhengFangApiClient(baseUrl: baseUrl, client: client);

    // 从本地存储恢复认证信息
    await _restoreAuthFromStorage();

    _isInitialized = true;
  }

  /// 获取API客户端实例
  ZhengFangApiClient get apiClient {
    if (!_isInitialized) {
      throw Exception('ApiServiceManager not initialized. Call initialize() first.');
    }
    return _apiClient;
  }

  /// 获取当前用户信息
  UserProfile? get currentUser => _currentUser;

  /// 检查用户是否已登录
  bool get isLoggedIn => _currentLogin != null && !_currentLogin!.isExpired;

  /// 获取认证令牌
  String? get authToken => _currentLogin?.token;

  /// 从本地存储恢复认证信息
  Future<void> _restoreAuthFromStorage() async {
    try {
      final box = Hive.box('api_auth');
      final token = box.get('token') as String?;
      final username = box.get('username') as String?;
      final userId = box.get('userId') as String?;
      final expiresAtStr = box.get('expiresAt') as String?;

      if (token != null && username != null && userId != null && expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        final now = DateTime.now();

        // 检查token是否过期
        if (now.isBefore(expiresAt)) {
          _currentLogin = LoginResponse(
            token: token,
            userId: userId,
            userRole: 'teacher', // 默认角色
            username: username,
            expiresAt: expiresAt,
          );

          _apiClient.setAuth(token, userId);

          // 尝试获取用户资料
          await _refreshUserProfile();
        } else {
          // Token已过期，清除存储
          await _clearAuthStorage();
        }
      }
    } catch (e) {
      // 存储读取失败，忽略错误
      print('Failed to restore auth from storage: $e');
    }
  }

  /// 保存认证信息到本地存储
  Future<void> _saveAuthToStorage(LoginResponse login) async {
    try {
      final box = Hive.box('api_auth');
      await box.putAll({
        'token': login.token,
        'userId': login.userId,
        'username': login.username,
        'expiresAt': login.expiresAt.toIso8601String(),
      });
    } catch (e) {
      print('Failed to save auth to storage: $e');
    }
  }

  /// 清除本地认证存储
  Future<void> _clearAuthStorage() async {
    try {
      final box = Hive.box('api_auth');
      await box.clear();
    } catch (e) {
      print('Failed to clear auth storage: $e');
    }
  }

  /// 登录
  Future<ApiResponse<LoginResponse>> login(LoginRequest request) async {
    final response = await _apiClient.login(request);

    if (response.success && response.hasData) {
      _currentLogin = response.data!;
      _apiClient.setAuth(_currentLogin!.token, _currentLogin!.userId);

      // 保存到本地存储
      await _saveAuthToStorage(_currentLogin!);

      // 获取用户资料
      await _refreshUserProfile();
    }

    return response;
  }

  /// 登出
  Future<void> logout() async {
    _currentLogin = null;
    _currentUser = null;
    _apiClient.clearAuth();

    // 清除本地存储
    await _clearAuthStorage();
  }

  /// 刷新用户资料
  Future<void> _refreshUserProfile() async {
    // 这里可以添加获取用户详细资料的API调用
    // 目前使用登录响应中的基本信息构造UserProfile
    if (_currentLogin != null) {
      _currentUser = UserProfile(
        userId: _currentLogin!.userId,
        username: _currentLogin!.username,
        realName: _currentLogin!.username, // 暂时使用用户名作为真实姓名
        department: '教师', // 默认部门
        roles: [_currentLogin!.userRole],
        lastLoginAt: DateTime.now(),
      );
    }
  }

  /// 健康检查
  Future<ApiResponse<String>> healthCheck() {
    return _apiClient.healthCheck();
  }

  /// 获取教师课表
  Future<ApiResponse<List<Course>>> getTeacherSchedule({
    String? teacherId,
    String? weekNum,
  }) {
    return _apiClient.getTeacherSchedule(
      teacherId: teacherId,
      weekNum: weekNum,
    );
  }

  /// 获取任务清单
  Future<ApiResponse<List<Task>>> getTeacherTasks({
    String? teacherId,
    String? status,
    String? beforeDate,
  }) {
    return _apiClient.getTeacherTasks(
      teacherId: teacherId,
      status: status,
      beforeDate: beforeDate,
    );
  }

  /// 检查网络连接状况
  Future<bool> checkConnectivity() async {
    try {
      final response = await healthCheck();
      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// 设置API基础URL
  void setBaseUrl(String baseUrl) {
    _apiClient = ZhengFangApiClient(baseUrl: baseUrl);
    if (_currentLogin != null) {
      _apiClient.setAuth(_currentLogin!.token, _currentLogin!.userId);
    }
  }
}