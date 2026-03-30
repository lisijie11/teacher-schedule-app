import 'package:hive_flutter/hive_flutter.dart';

/// API缓存管理器
/// 提供数据的缓存和过期管理
class ApiCacheManager {
  static const String _cacheBoxName = 'api_cache';
  static const Duration _defaultExpireDuration = Duration(hours: 1);
  static const Duration _scheduleExpireDuration = Duration(minutes: 30);
  static const Duration _tasksExpireDuration = Duration(minutes: 15);
  
  /// 初始化缓存管理器
  static Future<void> init() async {
    // 缓存box已经由main.dart统一初始化，这里不需要重复初始化
  }
  
  /// 获取缓存数据
  static Future<ApiCacheEntry?> getCache(String key) async {
    try {
      final box = await _getCacheBox();
      final cache = box.get(key);
      if (cache != null) {
        final entry = ApiCacheEntry.fromMap(cache);
        if (!entry.isExpired) {
          return entry;
        } else {
          // 过期数据自动清理
          await box.delete(key);
        }
      }
    } catch (_) {
      // 缓存读取失败不影响主流程
    }
    return null;
  }
  
  /// 设置缓存数据
  static Future<void> setCache(
    String key, 
    dynamic data, {
    Duration? expireDuration,
  }) async {
    try {
      final box = await _getCacheBox();
      final entry = ApiCacheEntry(
        key: key,
        data: data,
        expireAt: DateTime.now().add(expireDuration ?? _defaultExpireDuration),
      );
      await box.put(key, entry.toMap());
    } catch (_) {
      // 缓存写入失败不影响主流程
    }
  }
  
  /// 删除缓存数据
  static Future<void> deleteCache(String key) async {
    try {
      final box = await _getCacheBox();
      await box.delete(key);
    } catch (_) {
      // 忽略错误
    }
  }
  
  /// 清除所有缓存
  static Future<void> clearAllCache() async {
    try {
      final box = await _getCacheBox();
      await box.clear();
    } catch (_) {
      // 忽略错误
    }
  }
  
  /// 清除过期缓存
  static Future<void> clearExpiredCache() async {
    try {
      final box = await _getCacheBox();
      final keys = box.keys.toList();
      
      for (final key in keys) {
        final cache = box.get(key);
        if (cache != null) {
          final entry = ApiCacheEntry.fromMap(cache);
          if (entry.isExpired) {
            await box.delete(key);
          }
        }
      }
    } catch (_) {
      // 忽略错误
    }
  }
  
  /// 检查是否有有效的缓存
  static Future<bool> hasValidCache(String key) async {
    try {
      final cache = await getCache(key);
      return cache != null;
    } catch (_) {
      return false;
    }
  }
  
  /// 获取缓存Box
  static Future<Box<dynamic>> _getCacheBox() async {
    return await Hive.openBox<dynamic>(_cacheBoxName);
  }
  
  /// 特定类型的缓存方法
  
  /// 缓存用户课程表
  static Future<void> cacheUserSchedule(String userId, dynamic scheduleData) async {
    final key = 'schedule_$userId';
    await setCache(key, scheduleData, expireDuration: _scheduleExpireDuration);
  }
  
  /// 获取缓存的用户课程表
  static Future<dynamic> getCachedSchedule(String userId) async {
    final key = 'schedule_$userId';
    final cache = await getCache(key);
    return cache?.data;
  }
  
  /// 缓存用户任务列表
  static Future<void> cacheUserTasks(String userId, dynamic tasksData) async {
    final key = 'tasks_$userId';
    await setCache(key, tasksData, expireDuration: _tasksExpireDuration);
  }
  
  /// 获取缓存的用户任务列表
  static Future<dynamic> getCachedTasks(String userId) async {
    final key = 'tasks_$userId';
    final cache = await getCache(key);
    return cache?.data;
  }
  
  /// 缓存API响应（带请求参数）
  static Future<void> cacheApiResponse(
    String endpoint, 
    Map<String, dynamic>? params, 
    dynamic responseData,
    Duration? expireDuration,
  ) async {
    final key = _generateCacheKey(endpoint, params);
    await setCache(key, responseData, expireDuration: expireDuration);
  }
  
  /// 获取缓存的API响应
  static Future<dynamic> getCachedApiResponse(
    String endpoint, 
    Map<String, dynamic>? params,
  ) async {
    final key = _generateCacheKey(endpoint, params);
    final cache = await getCache(key);
    return cache?.data;
  }
  
  /// 生成缓存键
  static String _generateCacheKey(String endpoint, Map<String, dynamic>? params) {
    String key = endpoint;
    if (params != null && params.isNotEmpty) {
      final sortedKeys = params.keys.toList()..sort();
      for (final paramKey in sortedKeys) {
        final value = params[paramKey];
        key += '_${paramKey}_$value';
      }
    }
    // 确保key长度合理
    if (key.length > 200) {
      key = '${endpoint}_${params.hashCode}';
    }
    return key;
  }
  
  /// 获取缓存统计信息
  static Future<CacheStatistics> getStatistics() async {
    try {
      final box = await _getCacheBox();
      final keys = box.keys.toList();
      int total = keys.length;
      int expired = 0;
      int valid = 0;
      
      for (final key in keys) {
        final cache = box.get(key);
        if (cache != null) {
          final entry = ApiCacheEntry.fromMap(cache);
          if (entry.isExpired) {
            expired++;
          } else {
            valid++;
          }
        }
      }
      
      return CacheStatistics(
        totalEntries: total,
        validEntries: valid,
        expiredEntries: expired,
      );
    } catch (_) {
      return CacheStatistics();
    }
  }
}

/// 缓存条目数据类
class ApiCacheEntry {
  final String key;
  final dynamic data;
  final DateTime createdAt;
  final DateTime expireAt;
  
  ApiCacheEntry({
    required this.key,
    required this.data,
    DateTime? expireAt,
  }) : 
    createdAt = DateTime.now(),
    expireAt = expireAt ?? DateTime.now().add(const Duration(hours: 1));
  
  /// 是否过期
  bool get isExpired => DateTime.now().isAfter(expireAt);
  
  /// 距离过期还有多少时间（毫秒）
  int get timeToExpire => expireAt.difference(DateTime.now()).inMilliseconds;
  
  /// 转换为Map（用于存储）
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'expireAt': expireAt.toIso8601String(),
    };
  }
  
  /// 从Map创建
  factory ApiCacheEntry.fromMap(Map<dynamic, dynamic> map) {
    return ApiCacheEntry(
      key: map['key'] ?? '',
      data: map['data'],
      expireAt: map['expireAt'] != null 
        ? DateTime.parse(map['expireAt']) 
        : DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

/// 缓存统计信息
class CacheStatistics {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;
  
  const CacheStatistics({
    this.totalEntries = 0,
    this.validEntries = 0,
    this.expiredEntries = 0,
  });
  
  /// 缓存命中率（有效缓存/总缓存）
  double get hitRate => totalEntries > 0 ? validEntries / totalEntries : 0;
  
  /// 过期率
  double get expireRate => totalEntries > 0 ? expiredEntries / totalEntries : 0;
  
  @override
  String toString() {
    return '缓存统计: 总数=$totalEntries, 有效=$validEntries, 过期=$expiredEntries, 命中率=${(hitRate * 100).toStringAsFixed(1)}%, 过期率=${(expireRate * 100).toStringAsFixed(1)}%';
  }
}