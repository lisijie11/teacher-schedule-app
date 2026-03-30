import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

class HolidayService {
  HolidayService._();
  static final HolidayService instance = HolidayService._();

  late Box _box;

  // 节假日数据缓存（key: "2026-01-01", value: DayType）
  Map<String, DayType> _cache = {};

  Future<void> init() async {
    _box = Hive.box('settings');
    _loadCache();
    // 异步拉取节假日数据
    _fetchHolidays();
  }

  void _loadCache() {
    final raw = _box.get('holiday_cache');
    if (raw != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw as String);
        _cache = data.map((k, v) => MapEntry(k, DayType.values[v as int]));
      } catch (_) {}
    }
  }

  Future<void> _fetchHolidays() async {
    final year = DateTime.now().year;
    try {
      // 使用 timor.tech 的节假日 API
      final res = await http.get(
        Uri.parse('https://timor.tech/api/holiday/year/$year'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['code'] == 0) {
          final holidays = data['holiday'] as Map<String, dynamic>;
          for (final entry in holidays.entries) {
            final dateStr = entry.key; // "01-01"
            final fullDate = '$year-$dateStr';
            final info = entry.value as Map<String, dynamic>;
            final isHoliday = info['holiday'] as bool;
            // holiday=true 是法定假日，false 是补班（调休工作日）
            _cache[fullDate] = isHoliday ? DayType.holiday : DayType.workday;
          }
          // 缓存到本地
          final encoded = jsonEncode(
              _cache.map((k, v) => MapEntry(k, v.index)));
          _box.put('holiday_cache', encoded);
          _box.put('holiday_updated', DateTime.now().toIso8601String());
        }
      }
    } catch (_) {
      // 网络失败时使用缓存数据，不报错
    }
  }

  /// 判断某天的类型
  DayType getDayType(DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // 先查节假日数据库
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // 默认：周一到周五是工作日，周六周日是休息日
    if (date.weekday >= 1 && date.weekday <= 5) {
      return DayType.workday;
    } else {
      return DayType.weekend;
    }
  }

  /// 今天是否是工作日（考虑调休）
  bool isWorkday(DateTime date) {
    return getDayType(date) == DayType.workday;
  }

  /// 今天是否是休息日（考虑调休）
  bool isRestDay(DateTime date) {
    final type = getDayType(date);
    return type == DayType.weekend || type == DayType.holiday;
  }

  /// 获取今天应该使用的作息模式
  bool getTodayIsWeekday() {
    return isWorkday(DateTime.now());
  }

  /// 获取节假日描述
  String? getHolidayNote(DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (_cache[key] == DayType.holiday) {
      return '法定假日';
    } else if (_cache[key] == DayType.workday &&
        (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday)) {
      return '调休补班';
    }
    return null;
  }
}

enum DayType {
  workday, // 工作日（含调休补班）
  weekend, // 普通周末
  holiday, // 法定假日
}
