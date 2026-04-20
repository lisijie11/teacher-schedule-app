import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _widgetChannel = MethodChannel('com.lisijie.teacher_schedule/widget_data');

/// 待办分类枚举
enum TodoCategory {
  research,   // 科研课题
  teaching,   // 教改课题
  teacherComp,// 教师比赛
  studentComp,// 学生比赛
}

/// 分类元信息（图标、颜色、名称）
class TodoCategoryMeta {
  static const Map<TodoCategory, String> names = {
    TodoCategory.research: '科研课题',
    TodoCategory.teaching: '教改课题',
    TodoCategory.teacherComp: '教师比赛',
    TodoCategory.studentComp: '学生比赛',
  };

  static const Map<TodoCategory, IconData> icons = {
    TodoCategory.research: Icons.science_outlined,
    TodoCategory.teaching: Icons.school_outlined,
    TodoCategory.teacherComp: Icons.emoji_events_outlined,
    TodoCategory.studentComp: Icons.groups_outlined,
  };

  static const Map<TodoCategory, Color> colors = {
    TodoCategory.research: Color(0xFF6C63FF), // 紫蓝
    TodoCategory.teaching: Color(0xFF07C160), // 绿
    TodoCategory.teacherComp: Color(0xFFFF7043), // 橙
    TodoCategory.studentComp: Color(0xFF1D9BF0), // 蓝
  };

  static const Map<String, TodoCategory> nameToEnum = {
    'research': TodoCategory.research,
    'teaching': TodoCategory.teaching,
    'teacherComp': TodoCategory.teacherComp,
    'studentComp': TodoCategory.studentComp,
  };

  static TodoCategory fromString(String s) => nameToEnum[s] ?? TodoCategory.research;
}

@HiveType(typeId: 1)
class TodoItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isDone;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String? note;

  @HiveField(5)
  int priority; // 0=普通, 1=重要, 2=紧急

  @HiveField(6)
  String category; // "research" | "teaching" | "teacherComp" | "studentComp"

  TodoItem({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.createdAt,
    this.note,
    this.priority = 0,
    this.category = 'research',
  });

  TodoCategory get todoCategory => TodoCategoryMeta.fromString(category);
}

class TodoItemAdapter extends TypeAdapter<TodoItem> {
  @override
  final int typeId = 1;

  @override
  TodoItem read(BinaryReader reader) {
    final fields = reader.readMap();
    return TodoItem(
      id: fields[0] as String,
      title: fields[1] as String,
      isDone: fields[2] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      note: fields[4] as String?,
      priority: (fields[5] as int?) ?? 0,
      category: (fields[6] as String?) ?? 'research',
    );
  }

  @override
  void write(BinaryWriter writer, TodoItem obj) {
    writer.writeMap({
      0: obj.id,
      1: obj.title,
      2: obj.isDone,
      3: obj.createdAt.millisecondsSinceEpoch,
      4: obj.note,
      5: obj.priority,
      6: obj.category,
    });
  }
}

class TodoProvider extends ChangeNotifier {
  late Box<TodoItem> _box;

  List<TodoItem> get todos => _box.values.toList()
    ..sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      return b.createdAt.compareTo(a.createdAt);
    });

  List<TodoItem> get pending => todos.where((t) => !t.isDone).toList();
  List<TodoItem> get completed => todos.where((t) => t.isDone).toList();

  /// 按分类获取待办（字符串版，兼容旧代码）
  List<TodoItem> getByCategoryStr(String category) =>
      todos.where((t) => t.category == category).toList();

  /// 按分类获取待办
  List<TodoItem> getByCategory(TodoCategory cat) =>
      todos.where((t) => t.todoCategory == cat).toList();

  /// 按分类获取未完成
  List<TodoItem> getPendingByCategory(TodoCategory cat) =>
      pending.where((t) => t.todoCategory == cat).toList();

  /// 各分类统计（枚举版）
  Map<TodoCategory, int> get categoryCounts {
    final counts = <TodoCategory, int>{};
    for (final c in TodoCategory.values) {
      counts[c] = pending.where((t) => t.todoCategory == c).length;
    }
    return counts;
  }

  /// 各分类统计（字符串key版，供UI使用）
  Map<String, int> get categoryCountsStr {
    final counts = <String, int>{};
    for (final c in TodoCategory.values) {
      counts[c.name] = pending.where((t) => t.todoCategory == c).length;
    }
    return counts;
  }

  TodoProvider() {
    _box = Hive.box<TodoItem>('todos');
  }

  void add(TodoItem item) {
    _box.put(item.id, item);
    notifyListeners();
    _refreshTodoWidget();
  }

  void toggle(String id) {
    final item = _box.get(id);
    if (item != null) {
      item.isDone = !item.isDone;
      item.save();
      notifyListeners();
      _refreshTodoWidget();
    }
  }

  void remove(String id) {
    _box.delete(id);
    notifyListeners();
    _refreshTodoWidget();
  }

  void clearCompleted() {
    final ids = completed.map((t) => t.id).toList();
    for (final id in ids) {
      _box.delete(id);
    }
    notifyListeners();
    _refreshTodoWidget();
  }

  /// 待办变更后刷新待办小部件数据（四分类格式）
  void _refreshTodoWidget() {
    try {
      final allTodos = _box.values.toList();
      allTodos.sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        if (a.priority != b.priority) return b.priority.compareTo(a.priority);
        return b.createdAt.compareTo(a.createdAt);
      });

      final pending = allTodos.where((t) => !t.isDone).toList();
      final done    = allTodos.where((t) => t.isDone).toList();
      final total   = allTodos.length;
      final progress = total == 0 ? 0.0 : done.length / total;

      // 四分类数据
      final categories = <String, dynamic>{};
      for (final cat in TodoCategory.values) {
        final catName = TodoCategoryMeta.names[cat]!;
        final catPending = pending.where((t) => t.todoCategory == cat).toList();
        categories[cat.name] = {
          'name': catName,
          'count': catPending.length,
          'items': catPending.take(4).map((t) => {
            'title': t.title,
            'priority': t.priority,
            'isDone': t.isDone,
          }).toList(),
        };
      }

      // 未完成项列表（最多8条，带分类）
      final items = pending.take(8).map((t) => {
        'title': t.title,
        'priority': t.priority,
        'category': t.category,
      }).toList();

      final json = '{"totalCount":$total,"doneCount":${done.length},"pendingCount":${pending.length},'
          '"progress":$progress,'
          '"categories":${const JsonEncoder().convert(categories)},'
          '"items":${const JsonEncoder().convert(items)},'
          '"timestamp":${DateTime.now().millisecondsSinceEpoch}}';

      _widgetChannel.invokeMethod('saveWidgetData', {'key': 'todo_json', 'value': json});
      _widgetChannel.invokeMethod('updateWidget', {'widgetName': 'todo'});
    } catch (_) {}
  }
}
