import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

// 课程节次
class ClassPeriod {
  final int index; // 节次编号（1-8）
  final String name; // 显示名
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const ClassPeriod({
    required this.index,
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  String get startTime =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String get endTime =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

  Duration get duration => Duration(
        minutes: (endHour * 60 + endMinute) - (startHour * 60 + startMinute),
      );
}

// 周几常量（1=周一，7=周日，与 Dart DateTime.weekday 一致）
class Weekday {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 3;
  static const int thursday = 4;
  static const int friday = 5;
  static const int saturday = 6;
  static const int sunday = 7;
}

/// 获取周几名称
String getWeekdayName(int weekday) {
  const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return weekday >= 1 && weekday <= 7 ? names[weekday] : '未知';
}

/// 检查是否为工作日（周一-周五）
bool isWeekday(int weekday) => weekday >= 1 && weekday <= 5;

/// 检查是否为周末（周六、周日）
bool isWeekendDay(int weekday) => weekday == 6 || weekday == 7;

// 预设作息表（默认值）
class SchedulePresets {
  // 周一到周五作息 - 两节合并的大节课
  static const List<ClassPeriod> weekdayPeriodsDefault = [
    ClassPeriod(
        index: 1, name: '第1-2节', startHour: 8, startMinute: 30, endHour: 10, endMinute: 5),
    ClassPeriod(
        index: 2, name: '第3-4节', startHour: 10, startMinute: 25, endHour: 12, endMinute: 0),
    ClassPeriod(
        index: 3, name: '第5-6节', startHour: 14, startMinute: 0, endHour: 15, endMinute: 35),
    ClassPeriod(
        index: 4, name: '第7-8节', startHour: 15, startMinute: 55, endHour: 17, endMinute: 30),
  ];

  // 周六到周日作息 - 两节合并的大节课
  static const List<ClassPeriod> weekendPeriodsDefault = [
    ClassPeriod(
        index: 1, name: '第1-2节', startHour: 8, startMinute: 0, endHour: 9, endMinute: 40),
    ClassPeriod(
        index: 2, name: '第3-4节', startHour: 10, startMinute: 5, endHour: 11, endMinute: 45),
    ClassPeriod(
        index: 3, name: '第5-6节', startHour: 14, startMinute: 30, endHour: 16, endMinute: 10),
    ClassPeriod(
        index: 4, name: '第7-8节', startHour: 16, startMinute: 35, endHour: 18, endMinute: 15),
  ];

  // 运行时缓存
  static List<ClassPeriod>? _weekdayPeriods;
  static List<ClassPeriod>? _weekendPeriods;
  static Box? _settingsBox;

  /// 初始化 - 从 Hive 加载自定义作息时间
  static Future<void> init() async {
    _settingsBox ??= Hive.box('settings');
    await _loadCustomSchedule();
  }

  /// 从 Hive 加载自定义作息时间
  static Future<void> _loadCustomSchedule() async {
    if (_settingsBox == null) return;

    final weekdayJson = _settingsBox!.get('customWeekdayPeriods');
    final weekendJson = _settingsBox!.get('customWeekendPeriods');

    if (weekdayJson != null) {
      _weekdayPeriods = _parsePeriods(weekdayJson);
    } else {
      _weekdayPeriods = weekdayPeriodsDefault;
    }

    if (weekendJson != null) {
      _weekendPeriods = _parsePeriods(weekendJson);
    } else {
      _weekendPeriods = weekendPeriodsDefault;
    }
  }

  /// 解析作息时间 JSON
  static List<ClassPeriod> _parsePeriods(dynamic json) {
    if (json is! List || json.isEmpty) {
      return weekdayPeriodsDefault;
    }
    return json.map((p) {
      if (p is Map) {
        return ClassPeriod(
          index: p['index'] ?? 1,
          name: p['name'] ?? '第${p['index']}节',
          startHour: p['startHour'] ?? 8,
          startMinute: p['startMinute'] ?? 0,
          endHour: p['endHour'] ?? 9,
          endMinute: p['endMinute'] ?? 40,
        );
      }
      return weekdayPeriodsDefault.first;
    }).toList();
  }

  /// 保存自定义作息时间到 Hive
  static Future<void> saveCustomSchedule({
    required List<ClassPeriod>? weekday,
    required List<ClassPeriod>? weekend,
  }) async {
    if (_settingsBox == null) {
      _settingsBox = Hive.box('settings');
    }

    if (weekday != null) {
      final json = weekday.map((p) => {
        'index': p.index,
        'name': p.name,
        'startHour': p.startHour,
        'startMinute': p.startMinute,
        'endHour': p.endHour,
        'endMinute': p.endMinute,
      }).toList();
      await _settingsBox!.put('customWeekdayPeriods', json);
      _weekdayPeriods = weekday;
    }

    if (weekend != null) {
      final json = weekend.map((p) => {
        'index': p.index,
        'name': p.name,
        'startHour': p.startHour,
        'startMinute': p.startMinute,
        'endHour': p.endHour,
        'endMinute': p.endMinute,
      }).toList();
      await _settingsBox!.put('customWeekendPeriods', json);
      _weekendPeriods = weekend;
    }
  }

  /// 重置为默认作息时间
  static Future<void> resetToDefault() async {
    if (_settingsBox == null) {
      _settingsBox = Hive.box('settings');
    }
    await _settingsBox!.delete('customWeekdayPeriods');
    await _settingsBox!.delete('customWeekendPeriods');
    _weekdayPeriods = weekdayPeriodsDefault;
    _weekendPeriods = weekendPeriodsDefault;
  }

  /// 检查是否使用自定义作息时间
  static bool get isCustomSchedule {
    if (_settingsBox == null) return false;
    return _settingsBox!.get('customWeekdayPeriods') != null ||
           _settingsBox!.get('customWeekendPeriods') != null;
  }

  /// 获取当前生效的工作日作息（自定义或默认）
  static List<ClassPeriod> get weekdayPeriods {
    return _weekdayPeriods ?? weekdayPeriodsDefault;
  }

  /// 获取当前生效的周末作息（自定义或默认）
  static List<ClassPeriod> get weekendPeriods {
    return _weekendPeriods ?? weekendPeriodsDefault;
  }

  /// 根据周几获取作息表
  static List<ClassPeriod> getPeriodsForWeekday(int weekday) {
    return isWeekday(weekday) ? weekdayPeriods : weekendPeriods;
  }

  static String getModeLabel(int weekday) {
    return isWeekday(weekday) ? '工作日作息' : '周末作息';
  }

  static String getModeShortLabel(int weekday) {
    return getWeekdayName(weekday);
  }
}

// 自定义提醒项
@HiveType(typeId: 0)
class ReminderItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int hour;

  @HiveField(3)
  int minute;

  @HiveField(4)
  int weekday; // 1=周一，2=周二，...，7=周日，0=每天

  @HiveField(5)
  bool isEnabled;

  @HiveField(6)
  String? note;

  @HiveField(7)
  int advanceMinutes; // 提前几分钟提醒（0=准时）

  ReminderItem({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.weekday,
    this.isEnabled = true,
    this.note,
    this.advanceMinutes = 0,
  });

  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 获取周几显示文本
  String get weekdayString {
    if (weekday == 0) return '每天';
    return getWeekdayName(weekday);
  }
}

// Hive adapter - 手动生成以避免 build_runner
class ReminderItemAdapter extends TypeAdapter<ReminderItem> {
  @override
  final int typeId = 0;

  @override
  ReminderItem read(BinaryReader reader) {
    final fields = reader.readMap();
    // 兼容旧数据：isWeekday (bool) -> weekday (int)
    int weekdayValue;
    if (fields[4] is bool) {
      weekdayValue = (fields[4] as bool) ? 1 : 6; // true=周一，false=周六
    } else {
      weekdayValue = fields[4] as int? ?? 1;
    }
    return ReminderItem(
      id: fields[0] as String,
      title: fields[1] as String,
      hour: fields[2] as int,
      minute: fields[3] as int,
      weekday: weekdayValue,
      isEnabled: fields[5] as bool? ?? true,
      note: fields[6] as String?,
      advanceMinutes: fields[7] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderItem obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.title,
      2: obj.hour,
      3: obj.minute,
      4: obj.weekday,
      5: obj.isEnabled,
      6: obj.note,
      7: obj.advanceMinutes,
    });
  }
}

// ScheduleProvider - 管理状态
class ScheduleProvider extends ChangeNotifier {
  late Box<ReminderItem> _box;
  late Box _settings;
  int _reminderAdvanceMinutes = 10; // 默认提前10分钟

  List<ReminderItem> get reminders => _box.values.toList();
  int get reminderAdvanceMinutes => _reminderAdvanceMinutes;

  ScheduleProvider() {
    _box = Hive.box<ReminderItem>('reminders');
    _settings = Hive.box('settings');
    _reminderAdvanceMinutes = _settings.get('advanceMinutes', defaultValue: 10);
  }

  void addReminder(ReminderItem item) {
    _box.put(item.id, item);
    notifyListeners();
  }

  void removeReminder(String id) {
    _box.delete(id);
    notifyListeners();
  }

  void toggleReminder(String id) {
    final item = _box.get(id);
    if (item != null) {
      item.isEnabled = !item.isEnabled;
      item.save();
      notifyListeners();
    }
  }

  void setAdvanceMinutes(int minutes) {
    _reminderAdvanceMinutes = minutes;
    _settings.put('advanceMinutes', minutes);
    notifyListeners();
  }

  /// 获取某天的提醒
  List<ReminderItem> getRemindersForWeekday(int weekday) {
    return reminders.where((r) => r.weekday == weekday).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  /// 获取每天的提醒开关状态
  Map<int, bool> getWeekdayReminderEnabled() {
    final Map<int, bool> enabled = {};
    for (int i = 1; i <= 7; i++) {
      // 如果有任何该天的有效提醒，则启用
      enabled[i] = reminders.any((r) => r.weekday == i && r.isEnabled);
    }
    return enabled;
  }
}
