import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'schedule_model.dart' show SchedulePresets, ClassPeriod;
import '../services/widget_service.dart';

/// 周数类型枚举
enum WeekType {
  all,   // 全学期
  odd,   // 单周
  even,  // 双周
  custom // 自定义周数
}

/// 课程条目 —— 对应某节次在某天的课程信息
/// 用户可以手动为每个节次填写课程名称、地点、备注
@HiveType(typeId: 2)
class CourseEntry extends HiveObject {
  @HiveField(0)
  String id; // 唯一 ID

  @HiveField(1)
  int weekday; // 1=周一，2=周二，...，7=周日

  @HiveField(2)
  int periodIndex; // 对应的节次编号（1-based）

  @HiveField(3)
  String courseName; // 课程名称

  @HiveField(4)
  String classroom; // 上课地点

  @HiveField(5)
  String? note; // 备注

  @HiveField(6)
  int colorIndex; // 颜色标记（0-7）

  @HiveField(7)
  int weekTypeIndex; // 周数类型（0=全学期，1=单周，2=双周，3=自定义）

  @HiveField(8)
  List<int>? customWeeks; // 自定义周数列表，如 [1,3,5] 或 [1,2,3,4,5,6,7,8]

  CourseEntry({
    required this.id,
    required this.weekday,
    required this.periodIndex,
    required this.courseName,
    required this.classroom,
    this.note,
    this.colorIndex = 0,
    this.weekTypeIndex = 0, // 默认全学期
    this.customWeeks,
  });

  /// 获取周数类型
  WeekType get weekType => WeekType.values[weekTypeIndex];

  /// 获取周数描述
  String get weekTypeDesc {
    switch (weekType) {
      case WeekType.all:
        return '全学期';
      case WeekType.odd:
        return '单周';
      case WeekType.even:
        return '双周';
      case WeekType.custom:
        if (customWeeks == null || customWeeks!.isEmpty) return '全学期';
        if (customWeeks!.length <= 3) {
          return '第${customWeeks!.join('、')}周';
        } else {
          final sorted = List<int>.from(customWeeks!)..sort();
          // 检查是否连续
          bool isConsecutive = true;
          for (int i = 1; i < sorted.length; i++) {
            if (sorted[i] != sorted[i - 1] + 1) {
              isConsecutive = false;
              break;
            }
          }
          if (isConsecutive) {
            return '第${sorted.first}-${sorted.last}周';
          }
          return '${sorted.length}周';
        }
    }
  }

  /// 检查指定周数是否有课
  bool hasClassInWeek(int weekNumber) {
    switch (weekType) {
      case WeekType.all:
        return true;
      case WeekType.odd:
        return weekNumber % 2 == 1;
      case WeekType.even:
        return weekNumber % 2 == 0;
      case WeekType.custom:
        return customWeeks?.contains(weekNumber) ?? true;
    }
  }

  /// 8种配色供用户选择
  static const List<Color> palette = [
    Color(0xFF6C63FF), // 紫蓝
    Color(0xFF5B8AF5), // 天蓝
    Color(0xFF07C160), // 绿
    Color(0xFFFF7043), // 橙
    Color(0xFFFF4081), // 玫红
    Color(0xFF26C6DA), // 青
    Color(0xFF9C27B0), // 紫
    Color(0xFFFFB300), // 金
  ];

  Color get color => palette[colorIndex % palette.length];

  /// 获取课程开始时间（根据节次和周几）
  String get startTime {
    final periods = _isWeekday
        ? SchedulePresets.weekdayPeriods
        : SchedulePresets.weekendPeriods;
    final period = periods.firstWhere(
      (p) => p.index == periodIndex,
      orElse: () => const ClassPeriod(index: 1, name: '第1节', startHour: 8, startMinute: 30, endHour: 9, endMinute: 15),
    );
    return period.startTime;
  }

  /// 获取课程结束时间
  String get endTime {
    final periods = _isWeekday
        ? SchedulePresets.weekdayPeriods
        : SchedulePresets.weekendPeriods;
    final period = periods.firstWhere(
      (p) => p.index == periodIndex,
      orElse: () => const ClassPeriod(index: 1, name: '第1节', startHour: 8, startMinute: 30, endHour: 9, endMinute: 15),
    );
    return period.endTime;
  }

  /// 检查是否工作日（周一-周五）
  bool get _isWeekday => weekday >= 1 && weekday <= 5;

  /// 获取周几的中文名称
  String get weekdayName {
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekday >= 1 && weekday <= 7 ? names[weekday] : '未知';
  }

  /// 班级名称（备注作为班级）
  String get className => note ?? '未指定班级';
}

/// Hive 适配器（手动生成，避免依赖 build_runner）
class CourseEntryAdapter extends TypeAdapter<CourseEntry> {
  @override
  final int typeId = 2;

  @override
  CourseEntry read(BinaryReader reader) {
    final fields = reader.readMap();
    // 兼容旧数据：isWeekday (bool) -> weekday (int)
    int weekdayValue;
    if (fields[1] is bool) {
      weekdayValue = (fields[1] as bool) ? 1 : 6; // true=周一，false=周六
    } else {
      weekdayValue = fields[1] as int? ?? 1;
    }
    return CourseEntry(
      id: fields[0] as String,
      weekday: weekdayValue,
      periodIndex: fields[2] as int,
      courseName: fields[3] as String,
      classroom: fields[4] as String? ?? '',
      note: fields[5] as String?,
      colorIndex: fields[6] as int? ?? 0,
      weekTypeIndex: fields[7] as int? ?? 0,
      customWeeks: fields[8] != null ? (fields[8] as List).cast<int>() : null,
    );
  }

  @override
  void write(BinaryWriter writer, CourseEntry obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.weekday,
      2: obj.periodIndex,
      3: obj.courseName,
      4: obj.classroom,
      5: obj.note,
      6: obj.colorIndex,
      7: obj.weekTypeIndex,
      8: obj.customWeeks,
    });
  }
}

/// CourseProvider —— 课程数据状态管理
class CourseProvider extends ChangeNotifier {
  late Box<CourseEntry> _box;

  CourseProvider() {
    _box = Hive.box<CourseEntry>('courses');
  }

  List<CourseEntry> get all => _box.values.toList();

  /// 获取某天某节次的课程（最多1个）
  CourseEntry? getEntry(int weekday, int periodIndex) {
    try {
      return _box.values.firstWhere(
        (e) => e.weekday == weekday && e.periodIndex == periodIndex,
      );
    } catch (_) {
      return null;
    }
  }

  /// 保存（新增或覆盖）
  Future<void> save(CourseEntry entry) async {
    await _box.put(entry.id, entry);
    notifyListeners();
    // 触发小组件更新
    WidgetService.onCourseDataChanged();
  }

  /// 删除
  Future<void> remove(String id) async {
    await _box.delete(id);
    notifyListeners();
    // 触发小组件更新
    WidgetService.onCourseDataChanged();
  }

  /// 清空某天的所有课程
  Future<void> clearDay(int weekday) async {
    final keys = _box.values
        .where((e) => e.weekday == weekday)
        .map((e) => e.key)
        .toList();
    await _box.deleteAll(keys);
    notifyListeners();
    // 触发小组件更新
    WidgetService.onCourseDataChanged();
  }
}
