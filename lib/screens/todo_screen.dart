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
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TodoProvider>();
    final pending = provider.pending;
    final completed = provider.completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
        actions: [
          if (completed.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清除已完成'),
                    content: Text('将删除 ${completed.length} 条已完成事项'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      TextButton(
                        onPressed: () {
                          provider.clearCompleted();
                          Navigator.pop(ctx);
                        },
                        child: const Text('确认',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_sweep_rounded, size: 16),
              label: Text('清除(${completed.length})'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 输入栏
          _buildInputBar(isDark, provider),

          // 统计行
          if (pending.isNotEmpty || completed.isNotEmpty)
            _buildStatsRow(isDark, pending.length, completed.length),

          // 列表
          Expanded(
            child: pending.isEmpty && completed.isEmpty
                ? _buildEmpty(isDark)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (pending.isNotEmpty) ...[
                        _sectionLabel(isDark, '进行中', pending.length,
                            const Color(0xFF6C63FF)),
                        const SizedBox(height: 6),
                        ...pending.map((t) => _buildTodoTile(
                            context, isDark, t, provider)),
                        const SizedBox(height: 12),
                      ],
                      if (completed.isNotEmpty) ...[
                        _sectionLabel(isDark, '已完成', completed.length,
                            const Color(0xFF07C160)),
                        const SizedBox(height: 6),
                        ...completed.map((t) => _buildTodoTile(
                            context, isDark, t, provider)),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, TodoProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded,
                color: AppTheme.primaryDark, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '记录一件待办事项...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.26),
                  fontSize: 14,
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (val) {
                _addTodo(val, provider);
                _focusNode.requestFocus();
              },
            ),
          ),
          GestureDetector(
            onTap: () => _addTodo(_ctrl.text, provider),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, int pendingCount, int doneCount) {
    final total = pendingCount + doneCount;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.12)
                    : AppTheme.primaryDark.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? const Color(0xFF07C160)
                        : AppTheme.primaryDark),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$doneCount / $total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.38),
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

  Widget _sectionLabel(
      bool isDark, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white.withOpacity(0.60) : Colors.black.withOpacity(0.54),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color),
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
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => provider.remove(todo.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: todo.isDone
                ? Colors.transparent
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => provider.toggle(todo.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  // 勾选框
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: todo.isDone
                          ? const Color(0xFF07C160)
                          : Colors.transparent,
                      border: Border.all(
                        color: todo.isDone
                            ? const Color(0xFF07C160)
                            : (isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.26)),
                        width: 1.5,
                      ),
                    ),
                    child: todo.isDone
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 13)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: todo.isDone
                                ? FontWeight.normal
                                : FontWeight.w500,
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: todo.isDone
                                ? (isDark
                                    ? Colors.white.withOpacity(0.30)
                                    : Colors.black.withOpacity(0.30))
                                : (isDark
                                    ? const Color(0xFFDDE0FF)
                                    : const Color(0xFF1A1B30)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(todo.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.26),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 38,
              color: AppTheme.primaryDark.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无待办',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.38),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '在上方输入框记录待办事项',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.26),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}
