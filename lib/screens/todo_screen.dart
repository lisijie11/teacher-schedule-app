import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/todo_model.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TodoProvider>();
    final pending = provider.pending;
    final completed = provider.completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          if (completed.isNotEmpty)
            TextButton(
              onPressed: () => provider.clearCompleted(),
              child: Text(
                '清除已完成(${completed.length})',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 输入栏
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    color: AppTheme.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: '添加待办事项...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) => _addTodo(val, provider),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryDark),
                  onPressed: () => _addTodo(_ctrl.text, provider),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: pending.isEmpty && completed.isEmpty
                ? _buildEmpty(isDark)
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (pending.isNotEmpty) ...[
                        _sectionLabel(isDark, '进行中', pending.length),
                        ...pending.map((t) => _buildTodoTile(
                            context, isDark, t, provider)),
                      ],
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _sectionLabel(isDark, '已完成', completed.length),
                        ...completed.map((t) => _buildTodoTile(
                            context, isDark, t, provider)),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _addTodo(String text, TodoProvider provider) {
    final t = text.trim();
    if (t.isEmpty) return;
    provider.add(TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: t,
      createdAt: DateTime.now(),
    ));
    _ctrl.clear();
  }

  Widget _sectionLabel(bool isDark, String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoTile(BuildContext context, bool isDark, TodoItem todo,
      TodoProvider provider) {
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => provider.remove(todo.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: ListTile(
          leading: GestureDetector(
            onTap: () => provider.toggle(todo.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.isDone
                    ? AppTheme.primaryDark
                    : Colors.transparent,
                border: Border.all(
                  color: todo.isDone ? AppTheme.primaryDark : Colors.grey,
                  width: 2,
                ),
              ),
              child: todo.isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              decoration:
                  todo.isDone ? TextDecoration.lineThrough : null,
              color: todo.isDone
                  ? (isDark ? Colors.white38 : Colors.black38)
                  : null,
            ),
          ),
          subtitle: Text(
            _timeAgo(todo.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            '没有待办事项\n享受轻松的时光 ✨',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
