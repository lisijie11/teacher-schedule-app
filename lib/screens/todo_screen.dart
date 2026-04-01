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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<TodoProvider>();
    final pending = provider.pending;
    final completed = provider.completed;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('待办'),
        actions: [
          if (completed.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearDialog(context, provider, completed),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text('清除(${completed.length})'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 输入栏 - 澎湃OS3风格
          _buildInputBar(theme, isDark, provider),

          // 统计行 - 优化后的进度条
          if (pending.isNotEmpty || completed.isNotEmpty)
            _buildStatsRow(theme, pending.length, completed.length, isDark),

          // 列表
          Expanded(
            child: pending.isEmpty && completed.isEmpty
              ? _buildEmpty(theme, isDark)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _sectionLabel(theme, '进行中', pending.length, AppTheme.primaryDark),
                      const SizedBox(height: 8),
                      ...pending.map((t) => _buildTodoTile(context, theme, isDark, t, provider)),
                      const SizedBox(height: 16),
                    ],
                    if (completed.isNotEmpty) ...[
                      _sectionLabel(theme, '已完成', completed.length, AppTheme.accentGreen),
                      const SizedBox(height: 8),
                      ...completed.map((t) => _buildTodoTile(context, theme, isDark, t, provider)),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isDark, TodoProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '记录待办事项...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 15,
                ),
              ),
              style: const TextStyle(fontSize: 15),
              onSubmitted: (val) {
                _addTodo(val, provider);
                _focusNode.requestFocus();
              },
            ),
          ),
          GestureDetector(
            onTap: () => _addTodo(_ctrl.text, provider),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // 优化后的进度条 - 渐变+动画+百分比
  Widget _buildStatsRow(ThemeData theme, int pendingCount, int doneCount, bool isDark) {
    final total = pendingCount + doneCount;
    final progress = total == 0 ? 0.0 : doneCount / total;
    final percent = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // 精美的渐变进度条
          Expanded(
            child: _GradientProgressBar(
              progress: progress,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          // 百分比文字
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$percent%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
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

  void _showClearDialog(BuildContext context, TodoProvider provider, List<TodoItem> completed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除已完成'),
        content: Text('将删除 ${completed.length} 条已完成事项'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.clearCompleted();
              Navigator.pop(ctx);
            },
            child: const Text('确认', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoTile(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    TodoItem todo,
    TodoProvider provider,
  ) {
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.accentRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => provider.remove(todo.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: todo.isDone
              ? Colors.transparent
              : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => provider.toggle(todo.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // 勾选框
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: todo.isDone ? AppTheme.accentGreen : Colors.transparent,
                      border: Border.all(
                        color: todo.isDone
                          ? AppTheme.accentGreen
                          : theme.textTheme.bodySmall?.color ?? Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: todo.isDone
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                  ),
                  const SizedBox(width: 14),

                  // 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: todo.isDone ? FontWeight.w400 : FontWeight.w500,
                            decoration: todo.isDone ? TextDecoration.lineThrough : null,
                            color: todo.isDone
                              ? theme.textTheme.bodySmall?.color
                              : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(todo.createdAt),
                          style: theme.textTheme.labelSmall,
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

  Widget _buildEmpty(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无待办',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '在上方输入框记录待办',
            style: theme.textTheme.bodySmall,
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

// 渐变进度条组件
class _GradientProgressBar extends StatefulWidget {
  final double progress;
  final bool isDark;

  const _GradientProgressBar({
    required this.progress,
    required this.isDark,
  });

  @override
  State<_GradientProgressBar> createState() => _GradientProgressBarState();
}

class _GradientProgressBarState extends State<_GradientProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _GradientProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _oldProgress = _animation.value;
      _animation = Tween<double>(begin: _oldProgress, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryDark,
                        AppTheme.primaryDark.withGreen(220),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryDark.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // 发光效果
              if (value > 0)
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
