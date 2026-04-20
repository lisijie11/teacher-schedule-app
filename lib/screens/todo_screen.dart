import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/todo_model.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  late TabController _tabController;
  
  /// 当前选中的分类（null=全部）
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // 4个分类Tab + 全部 = 5个Tab
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    
    if (_tabController.index == 0) {
      setState(() => _selectedCategory = null);
    } else {
      final categories = ['research', 'teaching', 'teacherComp', 'studentComp'];
      setState(() => _selectedCategory = categories[_tabController.index - 1]);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<TodoProvider>();
    
    // 根据选中分类过滤
    final allPending = _selectedCategory != null 
        ? provider.pending.where((t) => t.category == _selectedCategory).toList()
        : provider.pending;
    final allCompleted = _selectedCategory != null 
        ? provider.completed.where((t) => t.category == _selectedCategory).toList()
        : provider.completed;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('工作待办'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildCategoryTabs(theme, isDark, provider),
        ),
        actions: [
          if (allCompleted.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearDialog(context, provider, allCompleted),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text('清除(${allCompleted.length})'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 输入栏 - 带分类选择
          _buildInputBar(theme, isDark, provider),

          // 统计行
          if (allPending.isNotEmpty || allCompleted.isNotEmpty)
            _buildStatsRow(theme, allPending.length, allCompleted.length, isDark),

          // 列表
          Expanded(
            child: allPending.isEmpty && allCompleted.isEmpty
                ? _buildEmpty(theme, isDark)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (allPending.isNotEmpty) ...[
                        _sectionLabel(theme, 
                            _selectedCategory != null 
                                ? (TodoCategoryMeta.names[TodoCategoryMeta.fromString(_selectedCategory!)] ?? '进行中')
                                : '进行中', 
                            allPending.length, 
                            AppTheme.primaryDark),
                        const SizedBox(height: 8),
                        ...allPending.map((t) => _buildTodoTile(context, theme, isDark, t, provider)),
                        const SizedBox(height: 16),
                      ],
                      if (allCompleted.isNotEmpty) ...[
                        _sectionLabel(theme, '已完成', allCompleted.length, AppTheme.accentGreen),
                        const SizedBox(height: 8),
                        ...allCompleted.map((t) => _buildTodoTile(context, theme, isDark, t, provider)),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 分类标签页
  Widget _buildCategoryTabs(ThemeData theme, bool isDark, TodoProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelColor: AppTheme.primaryDark,
        unselectedLabelColor: theme.textTheme.bodySmall?.color,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppTheme.primaryDark, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: 20),
        ),
        tabAlignment: TabAlignment.center,
        tabs: [
          // 全部 + 4个分类
          _buildCategoryTab(Icons.dashboard_outlined, '全部', provider.pending.length),
          _buildCategoryTab(Icons.science_outlined, '科研', 
              provider.categoryCountsStr['research'] ?? 0),
          _buildCategoryTab(Icons.school_outlined, '教改', 
              provider.categoryCountsStr['teaching'] ?? 0),
          _buildCategoryTab(Icons.emoji_events_outlined, '师赛', 
              provider.categoryCountsStr['teacherComp'] ?? 0),
          _buildCategoryTab(Icons.groups_outlined, '生赛', 
              provider.categoryCountsStr['studentComp'] ?? 0),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(IconData icon, String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isDark, TodoProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：输入框 + 发送按钮
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
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
                      fontSize: 14,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (val) => _addTodo(val, provider),
                ),
              ),
              GestureDetector(
                onTap: () => _addTodo(_ctrl.text, provider),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 17),
                ),
              ),
            ],
          ),
          
          // 第二行：分类选择
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _CategorySelector(
              selectedCategory: _selectedCategory ?? 'research',
              onChanged: (cat) => setState(() {}),
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
          Expanded(
            child: _GradientProgressBar(
              progress: progress,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
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
      category: _selectedCategory ?? 'research',
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { provider.clearCompleted(); Navigator.pop(ctx); },
            child: const Text('确认', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }

  Widget _buildTodoTile(BuildContext context, ThemeData theme, bool isDark, TodoItem todo, TodoProvider provider) {
    final catMeta = todo.todoCategory;
    final catColor = TodoCategoryMeta.colors[catMeta] ?? AppTheme.primaryDark;

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppTheme.accentRed, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => provider.remove(todo.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: todo.isDone ? Colors.transparent : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => provider.toggle(todo.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        color: todo.isDone ? AppTheme.accentGreen : (theme.textTheme.bodySmall?.color ?? Colors.grey),
                        width: 2,
                      ),
                    ),
                    child: todo.isDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),

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
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // 分类标签
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(TodoCategoryMeta.icons[catMeta], size: 11, color: catColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    TodoCategoryMeta.names[catMeta] ?? '',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: catColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_timeAgo(todo.createdAt), style: theme.textTheme.labelSmall),
                          ],
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
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded, size: 40,
                color: theme.colorScheme.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          Text('暂无待办', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('在上方输入框记录待办', style: theme.textTheme.bodySmall),
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

/// 分类选择器组件
class _CategorySelector extends StatefulWidget {
  final String selectedCategory;
  final ValueChanged<String> onChanged;
  
  const _CategorySelector({required this.selectedCategory, required this.onChanged});

  @override
  State<_CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<_CategorySelector> {
  late String _currentCat;

  @override
  void initState() {
    super.initState();
    _currentCat = widget.selectedCategory;
  }

  @override
  void didUpdateWidget(covariant _CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _currentCat = widget.selectedCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['research', 'teaching', 'teacherComp', 'studentComp'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final meta = TodoCategoryMeta.fromString(cat);
          final isSelected = _currentCat == cat;
          return GestureDetector(
            onTap: () => setState(() => _currentCat = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 7),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected 
                    ? TodoCategoryMeta.colors[meta]?.withOpacity(0.18)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? (TodoCategoryMeta.colors[meta] ?? Colors.blue).withOpacity(0.6)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    TodoCategoryMeta.icons[meta],
                    size: 13,
                    color: isSelected 
                        ? (TodoCategoryMeta.colors[meta] ?? Colors.blue)
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    TodoCategoryMeta.names[meta] ?? '',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected 
                          ? (TodoCategoryMeta.colors[meta] ?? Colors.blue)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 渐变进度条组件
class _GradientProgressBar extends StatefulWidget {
  final double progress;
  final bool isDark;

  const _GradientProgressBar({required this.progress, required this.isDark});

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
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
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
            color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryDark.withGreen(220)]),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: AppTheme.primaryDark.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                ),
              ),
              if (value > 0)
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.1)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter),
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
