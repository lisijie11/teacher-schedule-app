/// API 响应包装类
/// 
/// 统一封装 API 调用的结果，包含成功/失败状态、数据和元数据。
class ApiResponse<T> {
  final T? data;
  final String? error;
  final String? message;
  final int? statusCode;
  final DateTime timestamp;
  final bool success;

  /// 成功的响应
  ApiResponse.success({
    required T this.data,
    String? this.message,
    int? this.statusCode,
    DateTime? this.timestamp,
  })  : success = true,
        error = null,
        timestamp = timestamp ?? DateTime.now();

  /// 失败的响应
  ApiResponse.error({
    String? this.error,
    int? this.statusCode,
    String? this.message,
    DateTime? this.timestamp,
  })  : success = false,
        data = null,
        timestamp = timestamp ?? DateTime.now();

  /// 从 JSON 创建响应（用于反序列化）
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJson,
  ) {
    final success = json['success'] as bool? ?? (json['code'] == 0);
    final timestamp = json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now();

    if (success) {
      return ApiResponse.success(
        data: fromJson(json['data']),
        message: json['message'] as String?,
        statusCode: json['code'] as int? ?? 200,
        timestamp: timestamp,
      );
    } else {
      return ApiResponse.error(
        error: json['error'] as String? ?? json['message'] as String?,
        message: json['message'] as String?,
        statusCode: json['code'] as int? ?? 500,
        timestamp: timestamp,
      );
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson([T Function(T)? toJson]) {
    return {
      'success': success,
      'data': toJson != null && data != null ? toJson(data!) : data,
      'error': error,
      'message': message,
      'code': statusCode ?? (success ? 200 : 500),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 检查是否有错误
  bool get hasError => error != null;

  /// 检查是否有数据
  bool get hasData => data != null;

  /// 获取数据（失败时抛出异常）
  T requireData() {
    if (!success || data == null) {
      throw Exception(error ?? 'No data available');
    }
    return data!;
  }

  /// 复制响应并更新数据
  ApiResponse<R> copyWithData<R>(R newData, {String? newMessage}) {
    return ApiResponse.success(
      data: newData,
      message: newMessage ?? message,
      statusCode: statusCode,
      timestamp: timestamp,
    );
  }

  /// 复制响应并更新错误
  ApiResponse<U> copyWithError<U>(String newError, {int? newStatusCode}) {
    return ApiResponse.error(
      error: newError,
      message: message,
      statusCode: newStatusCode ?? statusCode,
      timestamp: timestamp,
    );
  }

  @override
  String toString() {
    return 'ApiResponse{success: $success, data: $data, error: $error, message: $message}';
  }
}