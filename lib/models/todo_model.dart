import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

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

  TodoItem({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.createdAt,
    this.note,
    this.priority = 0,
  });
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
      priority: fields[5] as int? ?? 0,
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

  TodoProvider() {
    _box = Hive.box<TodoItem>('todos');
  }

  void add(TodoItem item) {
    _box.put(item.id, item);
    notifyListeners();
  }

  void toggle(String id) {
    final item = _box.get(id);
    if (item != null) {
      item.isDone = !item.isDone;
      item.save();
      notifyListeners();
    }
  }

  void remove(String id) {
    _box.delete(id);
    notifyListeners();
  }

  void clearCompleted() {
    final ids = completed.map((t) => t.id).toList();
    for (final id in ids) {
      _box.delete(id);
    }
    notifyListeners();
  }
}
