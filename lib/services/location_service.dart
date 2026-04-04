import 'package:geolocator/geolocator.dart';
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

  /// 检查并请求位置权限
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 位置服务未开启
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 权限被永久拒绝
      return false;
    }

    return true;
  }

  /// 获取当前位置坐标（仅使用 WiFi 和移动网络定位，完全禁用 GPS）
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      // 先尝试 getLastKnownPosition（最快，可能来自其他应用的网络定位缓存）
      Position? cachedPosition = await Geolocator.getLastKnownPosition();
      if (cachedPosition != null && _lastLocationTime != null &&
          DateTime.now().difference(_lastLocationTime!) < _cacheDuration) {
        print('[LocationService] 使用缓存位置');
        return cachedPosition;
      }

      Position? position;

      // 策略1: 最低精度定位（只用 WiFi 和移动网络，完全禁用 GPS）
      try {
        print('[LocationService] 尝试网络定位（WiFi + 移动网络）...');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.lowest, // lowest 只用网络定位
          forceAndroidLocationManager: true, // 强制使用 Android LocationManager
          timeLimit: const Duration(seconds: 10),
        );
        _lastLocationTime = DateTime.now();
        print('[LocationService] 网络定位成功: ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e) {
        print('[LocationService] 网络定位失败: $e');
      }

      // 策略2: 使用其他应用的缓存位置（可能是网络定位）
      if (cachedPosition != null) {
        // 检查精度，如果精度太低（>3000m）说明可能是 GPS 但信号不好
        if (cachedPosition.accuracy < 3000) {
          print('[LocationService] 使用其他应用缓存位置（精度: ${cachedPosition.accuracy}m）');
          return cachedPosition;
        }
      }

      // 策略3: 再次尝试（不强制 LocationManager，某些设备优化更好）
      try {
        print('[LocationService] 重试网络定位...');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.lowest,
          timeLimit: const Duration(seconds: 8),
        );
        _lastLocationTime = DateTime.now();
        print('[LocationService] 重试成功');
        return position;
      } catch (e) {
        print('[LocationService] 重试失败: $e');
        // 最后返回缓存（即使精度差）
        return cachedPosition;
      }
    } catch (e) {
      print('[LocationService] 获取位置异常: $e');
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

      final cityName = await getCityName(position.latitude, position.longitude);
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

  /// 检查位置服务是否可用
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// 打开位置设置页面
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// 打开应用设置页面（用于权限被永久拒绝时）
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
