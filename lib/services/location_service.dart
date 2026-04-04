import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 位置服务 - 自动定位获取城市名称
class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  // 缓存
  String? _cachedCity;
  DateTime? _lastLocationTime;
  static const _cacheDuration = Duration(hours: 1);

  // 地名中英文映射表（常见城市/区域）
  static const Map<String, String> _locationTranslations = {
    // 广东
    'shanwei': '汕尾',
    'downtown core': '城区',
    'haifeng': '海丰',
    'lufeng': '陆丰',
    'luhe': '陆河',
    'guangzhou': '广州',
    'shenzhen': '深圳',
    'foshan': '佛山',
    'dongguan': '东莞',
    'zhuhai': '珠海',
    'zhongshan': '中山',
    'huizhou': '惠州',
    'jiangmen': '江门',
    'zhaoqing': '肇庆',
    'qingyuan': '清远',
    'shaoguan': '韶关',
    'heyuan': '河源',
    'meizhou': '梅州',
    'chaozhou': '潮州',
    'jieyang': '揭阳',
    'yangjiang': '阳江',
    'yunfu': '云浮',
    'maoming': '茂名',
    'zhanjiang': '湛江',
    'shantou': '汕头',
    'shunde': '顺德',
    'nanhai': '南海',
    'panyu': '番禺',
    'nansha': '南沙',

    // 其他省份常见城市
    'beijing': '北京',
    'shanghai': '上海',
    'tianjin': '天津',
    'chongqing': '重庆',
    'hangzhou': '杭州',
    'nanjing': '南京',
    'chengdu': '成都',
    'wuhan': '武汉',
    'xian': '西安',
    'changsha': '长沙',
    'zhengzhou': '郑州',
    'jinan': '济南',
    'qingdao': '青岛',
    'dalian': '大连',
    'shenyang': '沈阳',
    'harbin': '哈尔滨',
    'changchun': '长春',
    'kunming': '昆明',
    'guiyang': '贵阳',
    'nanning': '南宁',
    'haikou': '海口',
    'sanya': '三亚',
    'fuzhou': '福州',
    'xiamen': '厦门',
    'nanchang': '南昌',
    'hefei': '合肥',
    'taiyuan': '太原',
    'shijiazhuang': '石家庄',
    'lhasa': '拉萨',
    'urumqi': '乌鲁木齐',
    'hohhot': '呼和浩特',
    'yinchuan': '银川',
    'xining': '西宁',
    'lanzhou': '兰州',
  };

  /// 翻译地名为中文
  String _translateLocation(String english) {
    final lower = english.toLowerCase().trim();

    // 精确匹配
    if (_locationTranslations.containsKey(lower)) {
      return _locationTranslations[lower]!;
    }

    // 包含匹配（如 "Downtown Core, Shanwei" -> "城区"）
    for (final entry in _locationTranslations.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // 无法翻译则返回原文
    return english;
  }

  // 原生定位通道
  static const _channel = MethodChannel('com.lisijie.teacher_schedule/location');

  /// 打开应用设置页面（用于权限被永久拒绝时）
  Future<bool> openAppSettings() async {
    try {
      // 使用 platform channel 调用原生打开设置
      const platform = MethodChannel('com.lisijie.teacher_schedule/app_settings');
      await platform.invokeMethod('openSettings');
      return true;
    } catch (e) {
      print('[LocationService] 打开设置失败: $e');
      return false;
    }
  }

  /// 获取当前位置坐标（优先网络定位，回退GPS）
  Future<Map<String, double>?> getCurrentPosition() async {
    // 原生定位已禁用，直接返回 null 使用 IP 定位
    print('[LocationService] 原生定位已禁用，使用IP定位');
    return null;
  }

  /// 通过IP定位获取城市（精确到区县）
  Future<String?> getLocationByIP() async {
    try {
      print('[LocationService] 尝试IP定位...');

      // 使用 ip-api.com（免费，每分钟45次请求限制）
      final response = await http.get(
        Uri.parse('http://ip-api.com/json/?lang=zh-CN&fields=status,city,regionName,district,country'),
        headers: {'User-Agent': 'TeacherScheduleApp/2.4.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // 优先级：区县 > 城市 > 省份
          String? location = data['district']?.toString(); // 区县
          if (location == null || location.isEmpty) {
            location = data['city']?.toString(); // 城市
          }
          if (location == null || location.isEmpty) {
            location = data['regionName']?.toString(); // 省份
          }

          // 翻译英文地名为中文
          if (location != null) {
            location = _translateLocation(location);
          }

          print('[LocationService] IP定位成功: $location (district=${data['district']}, city=${data['city']}, region=${data['regionName']})');
          return location;
        }
      }
      return null;
    } catch (e) {
      print('[LocationService] IP定位失败: $e');
      return null;
    }
  }

  /// 根据坐标获取城市名称（逆地理编码）
  Future<String?> getCityName(double latitude, double longitude) async {
    try {
      // 使用 Nominatim API 进行逆地理编码（免费，无需密钥）
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=10&accept-language=zh-CN',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TeacherScheduleApp/2.3.6',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        // 优先级：市 > 省 > 县
        String? city = address['city'] ?? 
                       address['town'] ?? 
                       address['county'] ?? 
                       address['state'];

        // 清理城市名称（去掉"市"、"省"后缀）
        if (city != null) {
          city = city
              .replaceAll('市', '')
              .replaceAll('省', '')
              .replaceAll('自治区', '')
              .replaceAll('维吾尔', '')
              .replaceAll('壮族', '')
              .replaceAll('回族', '');

          // 处理特殊地区名称
          if (city.contains('北京') || city.contains('上海') || 
              city.contains('天津') || city.contains('重庆')) {
            city = city.substring(0, 2);
          }
        }

        return city;
      }

      return null;
    } catch (e) {
      print('[LocationService] 逆地理编码失败: $e');
      return null;
    }
  }

  /// 一键获取当前城市（纯IP定位，不依赖原生定位）
  /// @param forceRefresh 是否强制刷新（忽略缓存）
  Future<String?> getCurrentCity({bool forceRefresh = false}) async {
    // 如果不是强制刷新，优先使用缓存
    if (!forceRefresh) {
      // 优先使用内存缓存
      if (_cachedCity != null) {
        // 检查缓存是否是错误数据
        if (_isInvalidLocation(_cachedCity!)) {
          print('[LocationService] 检测到无效缓存: $_cachedCity，强制重新定位');
          _cachedCity = null;
        } else {
          print('[LocationService] 使用内存缓存: $_cachedCity');
          return _cachedCity;
        }
      }

      // 尝试从SharedPreferences读取缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_city');
        final cacheTime = prefs.getInt('city_cache_time');
        if (cached != null && cacheTime != null) {
          // 检查缓存是否是错误数据
          if (_isInvalidLocation(cached)) {
            print('[LocationService] 检测到无效本地缓存: $cached，清除并重新定位');
            await prefs.remove('cached_city');
            await prefs.remove('city_cache_time');
          } else {
            final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
            if (DateTime.now().difference(cacheDate) < _cacheDuration) {
              _cachedCity = cached;
              print('[LocationService] 使用本地缓存: $cached');
              return cached;
            }
          }
        }
      } catch (_) {}
    }

    // 清除旧缓存，强制重新定位
    _cachedCity = null;
    print('[LocationService] ${forceRefresh ? "强制" : ""}使用IP定位...');
    
    try {
      final cityName = await getLocationByIP();
      if (cityName != null && cityName.isNotEmpty) {
        print('[LocationService] IP定位成功: $cityName');
        _cachedCity = cityName;
        _saveCache(cityName);
        return cityName;
      }
    } catch (e) {
      print('[LocationService] IP定位失败: $e');
    }

    print('[LocationService] 所有定位方案均失败');
    return null;
  }

  /// 检查是否是无效的位置名称（需要重新定位）
  bool _isInvalidLocation(String location) {
    final lower = location.toLowerCase();
    // 这些是常见的错误定位结果
    return lower == 'downtown core' ||
           lower == 'unknown' ||
           lower == 'localhost' ||
           lower.contains('private') ||
           lower.contains('reserved');
  }

  /// 保存缓存
  Future<void> _saveCache(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_city', city);
      await prefs.setInt('city_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
