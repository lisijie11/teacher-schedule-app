import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// 课程条目 —— 对应某节次在某天的课程信息
/// 用户可以手动为每个节次填写课程名称、地点、备注
@HiveType(typeId: 2)
class CourseEntry extends HiveObject {
  @HiveField(0)
  String id; // 唯一 ID

  @HiveField(1)
  bool isWeekday; // true = 工作日，false = 周末

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

  CourseEntry({
    required this.id,
    required this.isWeekday,
    required this.periodIndex,
    required this.courseName,
    required this.classroom,
    this.note,
    this.colorIndex = 0,
  });

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
}

/// Hive 适配器（手动生成，避免依赖 build_runner）
class CourseEntryAdapter extends TypeAdapter<CourseEntry> {
  @override
  final int typeId = 2;

  @override
  CourseEntry read(BinaryReader reader) {
    final fields = reader.readMap();
    return CourseEntry(
      id: fields[0] as String,
      isWeekday: fields[1] as bool,
      periodIndex: fields[2] as int,
      courseName: fields[3] as String,
      classroom: fields[4] as String? ?? '',
      note: fields[5] as String?,
      colorIndex: fields[6] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, CourseEntry obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.isWeekday,
      2: obj.periodIndex,
      3: obj.courseName,
      4: obj.classroom,
      5: obj.note,
      6: obj.colorIndex,
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

  /// 获取某模式下某节次的课程（最多1个）
  CourseEntry? getEntry(bool isWeekday, int periodIndex) {
    try {
      return _box.values.firstWhere(
        (e) => e.isWeekday == isWeekday && e.periodIndex == periodIndex,
      );
    } catch (_) {
      return null;
    }
  }

  /// 保存（新增或覆盖）
  Future<void> save(CourseEntry entry) async {
    await _box.put(entry.id, entry);
    notifyListeners();
  }

  /// 删除
  Future<void> remove(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  /// 清空某模式的所有课程
  Future<void> clearMode(bool isWeekday) async {
    final keys = _box.values
        .where((e) => e.isWeekday == isWeekday)
        .map((e) => e.key)
        .toList();
    await _box.deleteAll(keys);
    notifyListeners();
  }
}
