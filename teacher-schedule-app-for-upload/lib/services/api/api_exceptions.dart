/// API 异常基类
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalException;
  final DateTime timestamp;

  ApiException(
    this.message, {
    this.statusCode,
    this.originalException,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    if (statusCode != null) {
      return '[$statusCode] $message';
    }
    return message;
  }
}

/// 认证相关异常
class AuthenticationException extends ApiException {
  AuthenticationException(
    String message, {
    int? statusCode,
    dynamic originalException,
  }) : super(message, 
        statusCode: statusCode ?? 401,
        originalException: originalException,
      );
}

/// 网络连接异常
class NetworkException extends ApiException {
  NetworkException(
    String message, {
    int? statusCode,
    dynamic originalException,
  }) : super(message, 
        statusCode: statusCode ?? 503,
        originalException: originalException,
      );
}

/// 授权异常（权限不足）
class AuthorizationException extends ApiException {
  AuthorizationException(
    String message, {
    int? statusCode,
    dynamic originalException,
  }) : super(message, 
        statusCode: statusCode ?? 403,
        originalException: originalException,
      );
}

/// 请求超时异常
class TimeoutException extends ApiException {
  TimeoutException(
    String message, {
    int? statusCode,
    dynamic originalException,
  }) : super(message, 
        statusCode: statusCode ?? 408,
        originalException: originalException,
      );
}

/// 数据格式异常（JSON 解析错误等）
class FormatException extends ApiException {
  FormatException(
    String message, {
    int? statusCode,
    dynamic originalException,
  }) : super(message, 
        statusCode: statusCode ?? 422,
        originalException: originalException,
      );
}

/// 服务器错误异常
class ServerException extends ApiException {
  ServerException(
    String message, {
    int? statusCode,
    dynamic originalException,
  }) : super(message, 
        statusCode: statusCode ?? 500,
        originalException: originalException,
      );
}