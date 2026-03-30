import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_exceptions.dart';
import 'api_response.dart';
import 'models/schedule_model.dart';
import 'models/auth_model.dart';
import 'models/task_model.dart';
import 'cache_manager.dart';

/// 增强版的正方教务系统 API 客户端
/// 
/// 在基本客户端基础上添加了缓存、重试机制、离线支持等高级功能
class EnhancedZhengFangApiClient {
  final String baseUrl;
  final http.Client client;
  String? _token;
  String? _userId;
  
  // 配置参数
  final bool enableCache;
  final bool enableRetry;
  final int maxRetryAttempts;
  final Duration retryDelay;
  final Duration requestTimeout;
  
  // 状态跟踪
  final Map<String, DateTime> _requestTimestamps = {};
  final StreamController<bool> _onlineStatusController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  DateTime? _lastOfflineTime;

  EnhancedZhengFangApiClient({
    String? baseUrl,
    http.Client? client,
    this.enableCache = true,
    this.enableRetry = true,
    this.maxRetryAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 10),
  })  : baseUrl = baseUrl ?? 'http://localhost:5000',
        client = client ?? http.Client() {
    // 初始化时清理过期缓存
    _initialize();
  }

  /// 初始化
  Future<void> _initialize() async {
    if (enableCache) {
      await ApiCacheManager.clearExpiredCache();
    }
  }

  /// 设置认证信息
  void setAuth(String token, String userId) {
    _token = token;
    _userId = userId;
  }

  /// 清理认证信息
  void clearAuth() {
    _token = null;
    _userId = null;
    // 清理用户相关的缓存
    if (_userId != null && enableCache) {
      _clearUserCache(_userId!);
    }
  }

  /// 清理用户相关的缓存
  Future<void> _clearUserCache(String userId) async {
    await ApiCacheManager.deleteCache('schedule_$userId');
    await ApiCacheManager.deleteCache('tasks_$userId');
  }

  /// 获取请求头
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'X-Client-Version': '1.0.0', // 客户端版本
      'X-Request-ID': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  /// 设置在线/离线状态
  void setOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      if (!isOnline) {
        _lastOfflineTime = DateTime.now();
      } else if (_lastOfflineTime != null) {
        final offlineDuration = DateTime.now().difference(_lastOfflineTime!);
        print('恢复在线，离线时长: ${offlineDuration.inSeconds}秒');
      }
      _onlineStatusController.add(isOnline);
    }
  }

  /// 获取在线状态流
  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;

  /// 执行增强的 HTTP 请求
  Future<ApiResponse<T>> _enhancedRequest<T>(
    String method,
    String path, {
    Map<String, dynamic>? data,
    bool useCache = true,
    Duration? cacheDuration,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    // 检查频率限制（防止重复请求）
    final requestKey = '$method:$path:${jsonEncode(data ?? {})}';
    final lastRequestTime = _requestTimestamps[requestKey];
    if (lastRequestTime != null) {
      final timeSinceLast = DateTime.now().difference(lastRequestTime);
      if (timeSinceLast < const Duration(milliseconds: 500)) {
        return ApiResponse<T>(
          success: false,
          error: '请求过于频繁，请稍后再试',
          statusCode: 429,
        );
      }
    }
    _requestTimestamps[requestKey] = DateTime.now();

    // 尝试从缓存获取（如果启用缓存且是缓存GET请求）
    if (enableCache && useCache && method == 'GET') {
      final cached = await _getFromCache<T>(path, data, fromJson);
      if (cached != null) {
        return ApiResponse<T>.success(cached, 200, '来自缓存');
      }
    }

    int attempt = 0;
    late http.Response response;
    
    while (true) {
      attempt++;
      
      try {
        // 构建完整的URL
        final url = Uri.parse('$baseUrl$path');
        final headers = _getHeaders();
        
        // 准备请求体
        late String body;
        if (data != null) {
          body = jsonEncode(data);
        }

        // 创建请求，设置超时
        Future<http.Response> request;

        switch (method.toUpperCase()) {
          case 'GET':
            request = client.get(url, headers: headers).timeout(requestTimeout);
            break;
          case 'POST':
            request = client.post(url, headers: headers, body: body).timeout(requestTimeout);
            break;
          case 'PUT':
            request = client.put(url, headers: headers, body: body).timeout(requestTimeout);
            break;
          case 'DELETE':
            request = client.delete(url, headers: headers).timeout(requestTimeout);
            break;
          default:
            throw ApiException('不支持的HTTP方法: $method');
        }

        // 执行请求
        response = await request;

        // 处理响应
        await _handleResponseStatus(response.statusCode);

        final bodyString = response.body;
        Map<String, dynamic> responseData;

        try {
          responseData = jsonDecode(bodyString);
        } catch (e) {
          // 如果是文本响应，尝试作为字符串解析
          if (bodyString.isNotEmpty && !bodyString.startsWith('{')) {
            responseData = {'message': bodyString};
          } else {
            throw ApiException('响应JSON解析失败: $e');
          }
        }

        // 处理API错误
        if (response.statusCode >= 400) {
          final errorMsg = responseData['error'] ?? 
                          responseData['message'] ?? 
                          '请求失败 (${response.statusCode})';
          throw ApiException(errorMsg, response.statusCode);
        }

        // 解析为指定类型
        T result;
        if (fromJson != null) {
          result = fromJson(responseData);
        } else {
          result = responseData as T;
        }

        // 缓存响应（如果启用缓存）
        if (enableCache && useCache && method == 'GET') {
          await _cacheResponse(path, data, responseData, cacheDuration);
        }

        // 设置在线状态
        if (!_isOnline) {
          setOnlineStatus(true);
        }

        return ApiResponse<T>.success(result, response.statusCode);

      } on http.ClientException catch (e) {
        // 网络连接问题
        setOnlineStatus(false);
        
        if (enableRetry && attempt < maxRetryAttempts) {
          print('请求失败，${retryDelay.inSeconds}秒后重试 ($attempt/$maxRetryAttempts): $e');
          await Future.delayed(retryDelay * attempt); // 指数退避
          continue;
        }
        
        // 网络错误时尝试返回缓存数据
        if (enableCache && useCache && method == 'GET') {
          final cached = await _getFromCache<T>(path, data, fromJson);
          if (cached != null) {
            return ApiResponse<T>.success(cached, 200, '离线缓存数据');
          }
        }
        
        return ApiResponse<T>.error(_mapNetworkError(e));

      } on TimeoutException catch (e) {
        setOnlineStatus(false);
        
        if (enableRetry && attempt < maxRetryAttempts) {
          print('请求超时，${retryDelay.inSeconds}秒后重试 ($attempt/$maxRetryAttempts)');
          await Future.delayed(retryDelay * attempt);
          continue;
        }
        
        return ApiResponse<T>.error('请求超时，请检查网络连接');

      } on ApiException catch (e) {
        // API错误不重试
        return ApiResponse<T>.error(e.message, e.statusCode);

      } catch (e) {
        // 其他异常
        return ApiResponse<T>.error('请求异常: $e');
      }
    }
  }

  /// 从缓存获取数据
  Future<T?> _getFromCache<T>(
    String path, 
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>)? fromJson,
  ) async {
    try {
      final cachedData = await ApiCacheManager.getCachedApiResponse(path, data);
      if (cachedData != null) {
        if (fromJson != null) {
          return fromJson(cachedData);
        } else {
          return cachedData as T;
        }
      }
    } catch (_) {
      // 缓存读取失败不抛出异常
    }
    return null;
  }

  /// 缓存响应
  Future<void> _cacheResponse(
    String path,
    Map<String, dynamic>? data,
    dynamic responseData,
    Duration? cacheDuration,
  ) async {
    try {
      await ApiCacheManager.cacheApiResponse(
        path, 
        data, 
        responseData, 
        cacheDuration,
      );
    } catch (_) {
      // 缓存写入失败不抛出异常
    }
  }

  /// 处理HTTP状态码
  Future<void> _handleResponseStatus(int statusCode) async {
    switch (statusCode) {
      case 401:
      case 403:
        // 认证失败，清理认证信息
        clearAuth();
        throw ApiException('认证已过期，请重新登录', statusCode);
      case 500:
        // 服务器错误，重试也无益
        throw ApiException('服务器内部错误');
      case 502:
      case 503:
      case 504:
        // 服务暂时不可用，可以重试
        throw ApiException('服务暂时不可用，请稍后重试', statusCode);
    }
  }

  /// 映射网络错误
  String _mapNetworkError(http.ClientException error) {
    final message = error.message.toLowerCase();
    if (message.contains('connection refused') ||
        message.contains('connection reset')) {
      return '无法连接服务器，请检查网络';
    } else if (message.contains('dns')) {
      return '域名解析失败，请检查网络设置';
    } else if (message.contains('timeout')) {
      return '连接超时，请检查网络或稍后重试';
    } else if (message.contains('handshake')) {
      return '安全连接失败，请检查时间设置';
    } else {
      return '网络连接失败: ${error.message}';
    }
  }

  /// ---------- 公开API方法 ----------

  /// 用户登录
  Future<ApiResponse<AuthResponse>> login(String username, String password) async {
    final response = await _enhancedRequest<Map<String, dynamic>>(
      'POST',
      '/auth/login',
      data: {'username': username, 'password': password},
      useCache: false, // 登录请求不缓存
      fromJson: (json) => AuthResponse.fromJson(json),
    );

    if (response.success && response.data != null) {
      // 登录成功后设置认证信息
      setAuth(response.data!.token, response.data!.userId);
      // 预取用户数据
      _prefetchUserData(response.data!.userId);
    }

    return response;
  }

  /// 预取用户数据
  Future<void> _prefetchUserData(String userId) async {
    if (!enableCache) return;
    
    try {
      // 并行预取课表和任务
      await Future.wait([
        getSchedule(userId).catchError((_) {}),
        getTasks(userId).catchError((_) {}),
      ]);
    } catch (_) {
      // 预取失败不影响登录流程
    }
  }

  /// 获取课程表
  Future<ApiResponse<List<ScheduleData>>> getSchedule(String userId) async {
    final response = await _enhancedRequest<List<dynamic>>(
      'GET',
      '/schedule/$userId',
      useCache: true,
      cacheDuration: const Duration(minutes: 30),
    );

    if (response.success && response.data != null) {
      final scheduleList = response.data!
          .map((json) => ScheduleData.fromJson(json))
          .toList();
      
      // 缓存用户课程表
      if (enableCache) {
        await ApiCacheManager.cacheUserSchedule(userId, response.data!);
      }
      
      return ApiResponse<List<ScheduleData>>.success(
        scheduleList,
        response.statusCode,
        response.message,
      );
    }
    
    return ApiResponse.error(response.error, response.statusCode);
  }

  /// 获取任务列表
  Future<ApiResponse<List<TaskData>>> getTasks(String userId) async {
    final response = await _enhancedRequest<List<dynamic>>(
      'GET',
      '/tasks/$userId',
      useCache: true,
      cacheDuration: const Duration(minutes: 15),
    );

    if (response.success && response.data != null) {
      final taskList = response.data!
          .map((json) => TaskData.fromJson(json))
          .toList();
      
      // 缓存用户任务
      if (enableCache) {
        await ApiCacheManager.cacheUserTasks(userId, response.data!);
      }
      
      return ApiResponse<List<TaskData>>.success(
        taskList,
        response.statusCode,
        response.message,
      );
    }
    
    return ApiResponse.error(response.error, response.statusCode);
  }

  /// 创建新任务
  Future<ApiResponse<TaskData>> createTask(TaskData task) async {
    final response = await _enhancedRequest<Map<String, dynamic>>(
      'POST',
      '/tasks',
      data: task.toJson(),
      useCache: false,
      fromJson: (json) => TaskData.fromJson(json),
    );

    // 创建成功后清理任务缓存
    if (response.success && _userId != null && enableCache) {
      await ApiCacheManager.deleteCache('tasks_$_userId');
    }

    return response;
  }

  /// 更新任务
  Future<ApiResponse<TaskData>> updateTask(String taskId, TaskData task) async {
    final response = await _enhancedRequest<Map<String, dynamic>>(
      'PUT',
      '/tasks/$taskId',
      data: task.toJson(),
      useCache: false,
      fromJson: (json) => TaskData.fromJson(json),
    );

    // 更新成功后清理缓存
    if (response.success && _userId != null && enableCache) {
      await ApiCacheManager.deleteCache('tasks_$_userId');
    }

    return response;
  }

  /// 删除任务
  Future<ApiResponse<void>> deleteTask(String taskId) async {
    final response = await _enhancedRequest<void>(
      'DELETE',
      '/tasks/$taskId',
      useCache: false,
    );

    // 删除成功后清理缓存
    if (response.success && _userId != null && enableCache) {
      await ApiCacheManager.deleteCache('tasks_$_userId');
    }

    return response;
  }

  /// 获取缓存统计信息
  Future<CacheStatistics> getCacheStatistics() async {
    return await ApiCacheManager.getStatistics();
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    await ApiCacheManager.clearAllCache();
  }

  /// 强制刷新数据（清理缓存后重新获取）
  Future<ApiResponse<List<ScheduleData>>> refreshSchedule(String userId) async {
    // 清理缓存
    await ApiCacheManager.deleteCache('schedule_$userId');
    // 重新获取
    return await getSchedule(userId);
  }

  /// 强制刷新任务
  Future<ApiResponse<List<TaskData>>> refreshTasks(String userId) async {
    // 清理缓存
    await ApiCacheManager.deleteCache('tasks_$userId');
    // 重新获取
    return await getTasks(userId);
  }

  /// 批量操作支持
  Future<List<ApiResponse<T>>> batchRequest<T>(
    List<Future<ApiResponse<T>>> requests,
  ) async {
    final responses = await Future.wait(requests);
    return responses;
  }

  /// 清理请求时间戳（避免内存泄漏）
  void cleanup() {
    // 清理过期的请求时间戳（保留最近10分钟）
    final cutoffTime = DateTime.now().subtract(const Duration(minutes: 10));
    _requestTimestamps.removeWhere((key, timestamp) => timestamp.isBefore(cutoffTime));
  }

  /// 析构函数
  void dispose() {
    client.close();
    _onlineStatusController.close();
    cleanup();
  }
}