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

  /// 获取当前位置坐标（仅使用 WiFi 和移动网络定位，完全禁用 GPS）
  Future<Map<String, double>?> getCurrentPosition() async {
    try {
      // 调用原生网络定位
      final result = await _channel.invokeMethod<Map>('getNetworkLocation');
      if (result != null) {
        final lat = result['latitude'] as double;
        final lng = result['longitude'] as double;
        print('[LocationService] 原生网络定位成功: $lat, $lng');
        return {'latitude': lat, 'longitude': lng};
      }
      return null;
    } catch (e) {
      print('[LocationService] 原生网络定位失败: $e');
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
          'User-Agent': 'TeacherScheduleApp/2.3.0',
        },
      );

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

  /// 一键获取当前城市（组合方法，带缓存）
  Future<String?> getCurrentCity() async {
    // 优先使用缓存
    if (_cachedCity != null) return _cachedCity;

    // 尝试从SharedPreferences读取缓存
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_city');
      final cacheTime = prefs.getInt('city_cache_time');
      if (cached != null && cacheTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
        if (DateTime.now().difference(cacheDate) < _cacheDuration) {
          _cachedCity = cached;
          return cached;
        }
      }
    } catch (_) {}

    try {
      final position = await getCurrentPosition();
      if (position == null) return null;

      final cityName = await getCityName(position['latitude']!, position['longitude']!);
      if (cityName != null) {
        _cachedCity = cityName;
        // 保存到缓存
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_city', cityName);
          await prefs.setInt('city_cache_time', DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}
      }
      return cityName;
    } catch (e) {
      print('[LocationService] 获取当前城市失败: $e');
      return null;
    }
  }
}
