import 'dart:convert';
import 'dart:io';
import '../services/web_service.dart';

/// 天气服务 - 从手机获取天气数据
class WeatherService {
  static final WeatherService instance = WeatherService._();
  WeatherService._();

  // 默认位置：佛山
  String _defaultLocation = '佛山';
  WeatherData? _cachedWeather;

  // 天气描述中英文映射表
  static const Map<String, String> _weatherTranslations = {
    // 晴天相关
    'clear': '晴',
    'sunny': '晴',
    'partly cloudy': '多云',
    'cloudy': '多云',
    'overcast': '阴',
    'scattered clouds': '少云',

    // 雨天相关
    'light rain': '小雨',
    'moderate rain': '中雨',
    'heavy rain': '大雨',
    'light rain shower': '小阵雨',
    'moderate rain shower': '中阵雨',
    'heavy rain shower': '大阵雨',
    'rain shower': '阵雨',
    'rain': '雨',
    'drizzle': '毛毛雨',
    'light drizzle': '微雨',
    'heavy drizzle': '浓毛毛雨',
    'patchy rain possible': '局部有雨',
    'patchy light rain': '零星小雨',
    'patchy moderate rain': '零星中雨',
    'patchy heavy rain': '零星大雨',

    // 雷雨相关
    'thunderstorm': '雷暴',
    'thunderstorm with rain': '雷阵雨',
    'thunderstorm with heavy rain': '强雷阵雨',
    'patchy thunderstorm': '局部雷暴',
    'thundery outbreaks possible': '可能有雷雨',

    // 雪天相关
    'snow': '雪',
    'light snow': '小雪',
    'moderate snow': '中雪',
    'heavy snow': '大雪',
    'snow shower': '阵雪',
    'light snow shower': '小阵雪',
    'heavy snow shower': '大阵雪',
    'patchy snow possible': '可能有雪',
    'blizzard': '暴风雪',
    'blowing snow': '风吹雪',
    'freezing drizzle': '冻毛毛雨',
    'freezing fog': '冻雾',
    'ice pellets': '冰雹',

    // 雾霾相关
    'fog': '雾',
    'mist': '薄雾',
    'haze': '霾',
    'smoke': '烟雾',

    // 沙尘相关
    'sand': '沙',
    'dust': '尘',
    'sandstorm': '沙尘暴',
    'duststorm': '尘暴',

    // 风相关
    'windy': '大风',
    'gale': '大风',
    'storm': '风暴',

    // 其他
    'unknown': '未知',
  };

  /// 翻译天气描述为中文
  String _translateWeather(String english) {
    final lower = english.toLowerCase().trim();

    // 精确匹配
    if (_weatherTranslations.containsKey(lower)) {
      return _weatherTranslations[lower]!;
    }

    // 包含匹配（处理复合描述）
    for (final entry in _weatherTranslations.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // 无法翻译则返回原文
    return english;
  }

  /// 获取天气数据
  Future<WeatherData?> fetchWeather({String? location}) async {
    try {
      final city = location ?? _defaultLocation;

      // 使用 wttr.in API 获取天气
      final encodedLocation = Uri.encodeComponent(city);
      final url = 'https://wttr.in/$encodedLocation?format=j1&lang=zh';

      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        print('[WeatherService] 天气 API 请求失败: ${response.statusCode}');
        return null;
      }

      final data = await response.transform(utf8.decoder).join();
      final json = jsonDecode(data);

      // 解析当前天气
      final current = json['current_condition']?[0];
      if (current == null) return null;

      final temp = int.tryParse(current['temp_C']?.toString() ?? '20') ?? 20;
      final humidity = int.tryParse(current['humidity']?.toString() ?? '50') ?? 50;
      final weatherTextRaw = current['weatherDesc']?[0]?['value'] ?? '未知';
      final weatherText = _translateWeather(weatherTextRaw);
      final weatherIcon = _getWeatherIcon(weatherTextRaw.toLowerCase());

      // 解析未来天气
      final weather = json['weather'] ?? [];
      final List<DailyForecast> forecasts = [];
      final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

      // wttr.in 提供最多3天预报，但可以循环获取
      final now = DateTime.now();

      for (int i = 0; i < weather.length; i++) {
        final day = weather[i];
        final dateStr = day['date'] ?? '';
        final date = DateTime.tryParse(dateStr);
        final weekday = date != null ? weekdayNames[date.weekday - 1] : '周${i + 1}';

        final maxTemp = int.tryParse(day['maxtempC']?.toString() ?? '25') ?? 25;
        final minTemp = int.tryParse(day['mintempC']?.toString() ?? '15') ?? 15;
        final descRaw = day['hourly']?[4]?['weatherDesc']?[0]?['value'] ?? day['hourly']?[0]?['weatherDesc']?[0]?['value'] ?? '晴';
        final desc = _translateWeather(descRaw);
        final icon = _getWeatherIcon(descRaw.toLowerCase());

        forecasts.add(DailyForecast(
          date: dateStr,
          weekday: weekday,
          weatherIcon: icon,
          weatherText: desc,
          tempMax: maxTemp,
          tempMin: minTemp,
        ));
      }

      // 如果预报不足7天，用循环的方式补充（使用已有数据）
      while (forecasts.length < 7) {
        final idx = forecasts.length % forecasts.length.clamp(1, 3);
        final base = forecasts[idx > 0 ? idx - 1 : 0];
        final futureDate = now.add(Duration(days: forecasts.length));
        final weekday = weekdayNames[futureDate.weekday - 1];

        // 模拟温度变化
        final tempVariation = (forecasts.length ~/ 3) * 2;
        forecasts.add(DailyForecast(
          date: futureDate.toIso8601String().split('T')[0],
          weekday: weekday,
          weatherIcon: base.weatherIcon,
          weatherText: base.weatherText,
          tempMax: base.tempMax + tempVariation,
          tempMin: base.tempMin + tempVariation - 1,
        ));
      }

      // 解析12小时预报（从 hourly 数据中获取）
      final List<HourlyForecast> hourlyForecast = [];
      final hourlyData = json['weather']?[0]?['hourly'] ?? [];

      for (int i = 0; i < hourlyData.length && i < 8; i++) {
        final hour = hourlyData[i];
        final time = hour['time']?.toString() ?? '0';
        final hourNum = int.tryParse(time) ?? 0;
        final hourStr = '${(hourNum ~/ 100).toString().padLeft(2, '0')}:${(hourNum % 100).toString().padLeft(2, '0')}';

        final hourTemp = int.tryParse(hour['tempC']?.toString() ?? '20') ?? 20;
        final hourDescRaw = hour['weatherDesc']?[0]?['value'] ?? '晴';
        final hourDesc = _translateWeather(hourDescRaw);
        final hourIcon = _getWeatherIcon(hourDescRaw.toLowerCase());

        // 降水概率估算（rain/drizzle/snow 相关则高概率）
        double precipProb = 0.0;
        final descLower = hourDescRaw.toLowerCase();
        if (descLower.contains('rain') || descLower.contains('drizzle')) {
          precipProb = 60.0 + (hourlyData.length - i) * 5.0;
        } else if (descLower.contains('thunder')) {
          precipProb = 90;
        } else if (descLower.contains('snow')) {
          precipProb = 70.0;
        } else if (descLower.contains('cloud') || descLower.contains('overcast')) {
          precipProb = 20.0;
        }

        hourlyForecast.add(HourlyForecast(
          time: hourStr,
          weatherIcon: hourIcon,
          temp: hourTemp,
          precipProbability: precipProb.clamp(0, 100),
        ));
      }

      // 如果不够12小时，补充模拟数据
      while (hourlyForecast.length < 12) {
        final base = hourlyForecast.isNotEmpty ? hourlyForecast.last : hourlyForecast.first;
        if (base == null) break;

        final lastTime = base.time.split(':');
        final hour = int.parse(lastTime[0]);
        final nextHour = (hour + 1) % 24;
        final hourStr = '${nextHour.toString().padLeft(2, '0')}:00';

        hourlyForecast.add(HourlyForecast(
          time: hourStr,
          weatherIcon: base.weatherIcon,
          temp: base.temp + (hourlyForecast.length % 3 == 0 ? 1 : -1),
          precipProbability: base.precipProbability * 0.8,
        ));
      }

      // 生成建议
      final clothingAdvice = _getClothingAdvice(temp);
      final travelAdvice = _getTravelAdvice(weatherTextRaw.toLowerCase(), temp);

      final weatherData = WeatherData(
        location: city,
        weatherText: weatherText,
        weatherIcon: weatherIcon,
        temp: temp,
        humidity: humidity,
        clothingAdvice: clothingAdvice,
        travelAdvice: travelAdvice,
        forecast: forecasts,
        hourlyForecast: hourlyForecast,
      );

      _cachedWeather = weatherData;

      // 同步到 WebService
      WebService.instance.updateWeather(weatherData);

      return weatherData;
    } catch (e) {
      print('[WeatherService] 获取天气失败: $e');
      return null;
    }
  }

  /// 获取天气图标
  String _getWeatherIcon(String weather) {
    if (weather.contains('rain')) return '🌧️';
    if (weather.contains('drizzle')) return '🌦️';
    if (weather.contains('snow')) return '❄️';
    if (weather.contains('thunder')) return '⛈️';
    if (weather.contains('cloud') || weather.contains('overcast')) return '☁️';
    if (weather.contains('fog') || weather.contains('mist')) return '🌫️';
    if (weather.contains('sun') || weather.contains('clear')) return '☀️';
    return '🌤️';
  }

  /// 穿衣建议
  String _getClothingAdvice(int temp) {
    if (temp < 5) return '建议穿羽绒服或厚棉服，注意保暖';
    if (temp < 10) return '建议穿毛衣、外套，早晚较凉';
    if (temp < 15) return '建议穿风衣或夹克，怕冷加件毛衣';
    if (temp < 20) return '建议穿长袖衬衫或薄外套';
    if (temp < 25) return '建议穿长袖或短袖，舒适为主';
    if (temp < 30) return '建议穿短袖，注意防晒';
    return '建议穿轻薄衣物，注意防暑降温';
  }

  /// 出行建议
  String _getTravelAdvice(String weather, int temp) {
    if (weather.contains('rain')) return '今天有雨，记得带伞！';
    if (weather.contains('snow')) return '可能有雪，注意防滑，建议提前出门';
    if (weather.contains('thunder')) return '有雷雨天气，尽量避免外出';
    if (weather.contains('fog') || weather.contains('mist')) return '有雾，能见度较低，谨慎出行';
    if (temp < 5) return '天气寒冷，建议提前出门，注意保暖';
    if (temp > 35) return '极端高温，避免长时间户外活动';
    if (temp > 30) return '高温天气，建议避开中午时段';
    return '天气良好，适合出行';
  }

  /// 获取缓存的天气数据
  WeatherData? get cachedWeather => _cachedWeather;
}
