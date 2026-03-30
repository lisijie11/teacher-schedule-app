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

// 作息模式枚举
enum ScheduleMode { weekday, weekend }

// 预设作息表
class SchedulePresets {
  // 周一到周五：广东东软学院
  static const List<ClassPeriod> weekdayPeriods = [
    ClassPeriod(
        index: 1, name: '第1节', startHour: 8, startMinute: 30, endHour: 9, endMinute: 15),
    ClassPeriod(
        index: 2, name: '第2节', startHour: 9, startMinute: 20, endHour: 10, endMinute: 5),
    ClassPeriod(
        index: 3, name: '第3节', startHour: 10, startMinute: 25, endHour: 11, endMinute: 10),
    ClassPeriod(
        index: 4, name: '第4节', startHour: 11, startMinute: 15, endHour: 12, endMinute: 0),
    ClassPeriod(
        index: 5, name: '第5节', startHour: 14, startMinute: 0, endHour: 14, endMinute: 45),
    ClassPeriod(
        index: 6, name: '第6节', startHour: 14, startMinute: 50, endHour: 15, endMinute: 35),
    ClassPeriod(
        index: 7, name: '第7节', startHour: 15, startMinute: 55, endHour: 16, endMinute: 40),
    ClassPeriod(
        index: 8, name: '第8节', startHour: 16, startMinute: 45, endHour: 17, endMinute: 30),
  ];

  // 周六到周日：另一学校
  static const List<ClassPeriod> weekendPeriods = [
    ClassPeriod(
        index: 1, name: '第1-2节', startHour: 8, startMinute: 0, endHour: 9, endMinute: 40),
    ClassPeriod(
        index: 2, name: '第3-4节', startHour: 10, startMinute: 5, endHour: 11, endMinute: 45),
    ClassPeriod(
        index: 3, name: '第5-6节', startHour: 14, startMinute: 30, endHour: 16, endMinute: 10),
    ClassPeriod(
        index: 4, name: '第7-8节', startHour: 16, startMinute: 35, endHour: 18, endMinute: 15),
  ];

  static List<ClassPeriod> getPeriodsForMode(ScheduleMode mode) {
    return mode == ScheduleMode.weekday ? weekdayPeriods : weekendPeriods;
  }

  static String getModeLabel(ScheduleMode mode) {
    return mode == ScheduleMode.weekday ? '东软学院（工作日）' : '周末学校';
  }

  static String getModeShortLabel(ScheduleMode mode) {
    return mode == ScheduleMode.weekday ? '工作日' : '周末';
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
  bool isWeekday; // true=工作日，false=周末

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
    required this.isWeekday,
    this.isEnabled = true,
    this.note,
    this.advanceMinutes = 0,
  });

  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

// Hive adapter - 手动生成以避免 build_runner
class ReminderItemAdapter extends TypeAdapter<ReminderItem> {
  @override
  final int typeId = 0;

  @override
  ReminderItem read(BinaryReader reader) {
    final fields = reader.readMap();
    return ReminderItem(
      id: fields[0] as String,
      title: fields[1] as String,
      hour: fields[2] as int,
      minute: fields[3] as int,
      isWeekday: fields[4] as bool,
      isEnabled: fields[5] as bool,
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
      4: obj.isWeekday,
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

  List<ReminderItem> getRemindersForMode(bool isWeekday) {
    return reminders.where((r) => r.isWeekday == isWeekday).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }
}
