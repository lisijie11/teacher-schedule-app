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
  
  /// 当前选择的截止日期（必填）
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
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
        title: const Text('\u5de5\u4f5c\u5f85\u529e'),
        actions: [
          if (allCompleted.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearDialog(context, provider, allCompleted),
              icon: const Icon(Icons.delete_sweep_rounded, size: 16),
              label: Text('\u6e05\u9664(${allCompleted.length})', style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
            ),
        ],
      ),
      body: Column(
        children: [
          // 分类筛选标签栏
          _buildFilterChips(theme, isDark, provider),

          // 输入栏
          _buildInputBar(theme, isDark, provider),

          // 统计行 + 紧迫提示
          if (allPending.isNotEmpty || allCompleted.isNotEmpty)
            _buildStatsBar(theme, allPending, allCompleted.length, isDark),

          // 列表
          Expanded(
            child: allPending.isEmpty && allCompleted.isEmpty
                ? _buildEmpty(theme, isDark)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (allPending.isNotEmpty) ...[
                        _sectionLabel(theme, 
                            _selectedCategory != null 
                                ? (TodoCategoryMeta.names[TodoCategoryMeta.fromString(_selectedCategory!)] ?? '\u8fdb\u884c\u4e2d')
                                : '\u8fdb\u884c\u4e2d', 
                            allPending.length, 
                            AppTheme.primaryDark),
                        const SizedBox(height: 5),
                        ...allPending.map((t) => _buildTodoCard(context, theme, isDark, t, provider)),
                        const SizedBox(height: 12),
                      ],
                      if (allCompleted.isNotEmpty) ...[
                        _sectionLabel(theme, '\u5df2\u5b8c\u6210', allCompleted.length, AppTheme.accentGreen),
                        const SizedBox(height: 5),
                        ...allCompleted.map((t) => _buildTodoCard(context, theme, isDark, t, provider)),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== 分类筛选标签（SegmentedChip 风格）====================
  
  Widget _buildFilterChips(ThemeData theme, bool isDark, TodoProvider provider) {
    final chipBg = isDark ? AppTheme.darkBg2 : AppTheme.lightBg1;
    final chipInactiveBg = isDark ? AppTheme.darkBg3 : AppTheme.lightBg3;
    final inactiveText = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    
    final items = [
      _FilterItem(null, '\u5168\u90e8', provider.pending.length),
      _FilterItem('research', '\u79d1\u7814', provider.categoryCountsStr['research'] ?? 0),
      _FilterItem('teaching', '\u6559\u6539', provider.categoryCountsStr['teaching'] ?? 0),
      _FilterItem('teacherComp', '\u5e08\u8d5b', provider.categoryCountsStr['teacherComp'] ?? 0),
      _FilterItem('studentComp', '\u751f\u8d5b', provider.categoryCountsStr['studentComp'] ?? 0),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: chipInactiveBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: items.map((item) {
          final isActive = _selectedCategory == item.category;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectCategory(item.category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive 
                      ? [BoxShadow(color: AppTheme.primaryDark.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? Colors.white : inactiveText,
                      ),
                    ),
                    if (item.count > 0) ...[
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? Colors.white.withOpacity(0.25) 
                              : (isDark ? AppTheme.primaryDark.withOpacity(0.15) : AppTheme.primaryDark.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : AppTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _selectCategory(String? category) {
    setState(() => _selectedCategory = category);
    // 同步 TabController
    if (category == null) {
      _tabController.animateTo(0);
    } else {
      final idx = ['research', 'teaching', 'teacherComp', 'studentComp'].indexOf(category);
      if (idx >= 0) _tabController.animateTo(idx + 1);
    }
  }

  /// 分类角标文字（保留兼容）
  String _catBadge(int? count) {
    if (count == null || count <= 0) return '';
    if (count > 99) return ' 99+';
    return ' $count';
  }

  // ==================== 输入区（精致毛玻璃风格）====================

  Widget _buildInputBar(ThemeData theme, bool isDark, TodoProvider provider) {
    final hasDeadline = _selectedDeadline != null;
    final canAdd = _ctrl.text.trim().isNotEmpty && hasDeadline;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder.withOpacity(0.4) : AppTheme.lightBorder.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：输入框 + 添加按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBg3.withOpacity(0.5) : AppTheme.lightBg3.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18, color: theme.colorScheme.primary.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focusNode,
                          style: TextStyle(fontSize: 15, height: 1.4, color: isDark ? AppTheme.darkText : AppTheme.lightText),
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: '\u8f93\u5165\u5f85\u529e\u5185\u5bb9...',
                            hintStyle: TextStyle(fontSize: 14, color: isDark ? AppTheme.darkTextHint : AppTheme.lightTextHint),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (val) => _addTodo(val, provider),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 添加按钮
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: canAdd 
                      ? LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryDark.withOpacity(0.85)])
                      : null,
                  color: canAdd ? null : (isDark ? AppTheme.darkBg3 : AppTheme.lightBg3),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: canAdd 
                      ? [BoxShadow(color: AppTheme.primaryDark.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: IconButton(
                  onPressed: () => _addTodo(_ctrl.text, provider),
                  icon: Icon(Icons.arrow_upward_rounded, size: 18, color: canAdd ? Colors.white : (isDark ? AppTheme.darkTextHint : AppTheme.lightTextHint)),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 第二行：截止日期 + 分类（精美 chip 样式）
          Row(
            children: [
              // 截止日期 chip
              _buildDeadlineChip(theme, isDark, hasDeadline),
              
              const SizedBox(width: 7),

              // 分类选择 chip
              _buildCategoryChip(theme, isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// 截止日期选择 chip
  Widget _buildDeadlineChip(ThemeData theme, bool isDark, bool hasDeadline) {
    final dlColor = hasDeadline ? _getDeadlineColor(_selectedDeadline!) : AppTheme.accentRed;
    
    return GestureDetector(
      onTap: () => _pickDeadline(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: dlColor.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: dlColor.withOpacity(isDark ? 0.3 : 0.2), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasDeadline ? Icons.event_available_rounded : Icons.calendar_today_rounded, size: 13, color: dlColor),
            const SizedBox(width: 4),
            Text(
              hasDeadline ? _formatDeadlineShort(_selectedDeadline!) : '\u622a\u6b62\u65e5\u671f *',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: dlColor),
            ),
            if (hasDeadline) ...[
              const SizedBox(width: 3),
              GestureDetector(
                onTap: () => setState(() => _selectedDeadline = null),
                child: Icon(Icons.close_rounded, size: 12, color: isDark ? AppTheme.darkTextHint : AppTheme.lightTextHint),
              ),
            ] else ...[
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 12, color: dlColor.withOpacity(0.6)),
            ],
          ],
        ),
      ),
    );
  }

  /// 分类选择 chip（带弹出菜单）
  Widget _buildCategoryChip(ThemeData theme, bool isDark) {
    final catKey = _selectedCategory ?? 'research';
    final catMeta = TodoCategoryMeta.fromString(catKey);
    final catColor = TodoCategoryMeta.colors[catMeta] ?? AppTheme.primaryDark;
    final shortNames = {'research': '\u79d1\u7814', 'teaching': '\u6559\u6539', 'teacherComp': '\u5e08\u8d5b', 'studentComp': '\u751f\u8d5b'};
    final catLabel = shortNames[catKey] ?? '\u79d1\u7814';

    return GestureDetector(
      onTap: () => _showCategoryPicker(theme, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: catColor.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: catColor.withOpacity(isDark ? 0.3 : 0.2), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TodoCategoryMeta.icons[catMeta], size: 13, color: catColor),
            const SizedBox(width: 4),
            Text(catLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: catColor)),
            const SizedBox(width: 2),
            Icon(Icons.unfold_more_rounded, size: 12, color: catColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  /// 分类弹出选择器
  void _showCategoryPicker(ThemeData theme, bool isDark) {
    final categories = [
      ('research', '\u79d1\u7814\u8bfe\u9898', Icons.science_outlined),
      ('teaching', '\u6559\u6539\u9879\u76ee', Icons.school_outlined),
      ('teacherComp', '\u6559\u5e08\u6bd4\u8d5b', Icons.emoji_events_outlined),
      ('studentComp', '\u5b66\u751f\u6bd4\u8d5b', Icons.groups_outlined),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkBg2 : AppTheme.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkBg3 : AppTheme.lightBg3, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text('\u9009\u62e9\u5206\u7c7b', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppTheme.darkText : AppTheme.lightText)),
              const SizedBox(height: 12),
              ...categories.map((item) {
                final isSelected = (_selectedCategory ?? 'research') == item.$1;
                final catMeta = TodoCategoryMeta.fromString(item.$1);
                final catColor = TodoCategoryMeta.colors[catMeta] ?? AppTheme.primaryDark;
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(item.$3, color: catColor, size: 22),
                  title: Text(item.$2, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isDark ? AppTheme.darkText : AppTheme.lightText)),
                  trailing: isSelected ? Icon(Icons.check_circle, color: catColor, size: 20) : null,
                  selectedTileColor: catColor.withOpacity(0.06),
                  selected: isSelected,
                  onTap: () {
                    setState(() => _selectedCategory = item.$1);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// 短格式截止日期显示：如 "4/25(剩3天)"
  String _formatDeadlineShort(DateTime d) {
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '${d.month}/${d.day}';
    if (days == 0) return '${d.month}/${d.day}\u4eca\u5929';
    if (days <= 30) return '${d.month}/${d.day}(\u5269${days}\u5929)';
    return '${d.month}/${d.day}';
  }

  static Color _getDeadlineBgColor(DateTime d) {
    final days = d.difference(DateTime.now()).inDays;
    if (days <= 3) return const Color(0xFFFEE2E2);
    if (days <= 7) return const Color(0xFFFFF7ED);
    return const Color(0xFFEFF6FF);
  }

  static Color _getDeadlineBorderColor(DateTime d) {
    final days = d.difference(DateTime.now()).inDays;
    if (days <= 3) return const Color(0xFFFECACA);
    if (days <= 7) return const Color(0xFFFED7AA);
    return const Color(0xFFBFDBFE);
  }

  // ==================== 统计条（紧凑版）====================

  Widget _buildStatsBar(ThemeData theme, List<TodoItem> pending, int doneCount, bool isDark) {
    final total = pending.length + doneCount;
    final progress = total == 0 ? 0.0 : doneCount / total;
    final percent = (progress * 100).round();

    // 计算最紧急的截止日期
    DateTime? nearestDeadline;
    int? minDaysLeft;
    for (final t in pending) {
      if (t.deadline != null && t.deadline!.isAfter(DateTime.now())) {
        final days = t.deadline!.difference(DateTime.now()).inDays;
        if (minDaysLeft == null || days < minDaysLeft!) {
          minDaysLeft = days;
          nearestDeadline = t.deadline;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        children: [
          // 进度条行
          Row(
            children: [
              Expanded(child: _GradientProgressBar(progress: progress, isDark: isDark)),
              const SizedBox(width: 10),
              Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
            ],
          ),
          // 紧急提示
          if (nearestDeadline != null && minDaysLeft != null && minDaysLeft! <= 7)
            Padding(padding: const EdgeInsets.only(top: 6), child: _UrgencyBanner(daysLeft: minDaysLeft!, deadline: nearestDeadline!, isDark: isDark)),
        ],
      ),
    );
  }

  // ==================== 待办卡片（重新设计）====================

  Widget _buildTodoCard(BuildContext context, ThemeData theme, bool isDark, TodoItem todo, TodoProvider provider) {
    final catMeta = todo.todoCategory;
    final catColor = TodoCategoryMeta.colors[catMeta] ?? AppTheme.primaryDark;
    final dlDays = todo.deadline != null ? todo.deadline!.difference(DateTime.now()).inDays : null;
    final urgency = dlDays != null ? _getUrgencyLevel(dlDays) : null;

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('删除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除待办'),
            content: Text('确定删除「${todo.title}」？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认删除', style: TextStyle(color: AppTheme.accentRed)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => provider.remove(todo.id),
      child: GestureDetector(
        onTap: () => provider.toggle(todo.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: todo.isDone 
                  ? Colors.transparent 
                  : (urgency == UrgencyLevel.overdue || urgency == UrgencyLevel.critical
                      ? Color(0xFFEF4444).withOpacity(0.3)
                      : theme.colorScheme.outline.withOpacity(0.25)),
              width: urgency == UrgencyLevel.overdue || urgency == UrgencyLevel.critical ? 1.3 : 1,
            ),
            boxShadow: [
              if (!todo.isDone && (urgency == UrgencyLevel.critical || urgency == UrgencyLevel.warning))
                BoxShadow(
                  color: _getUrgencyColor(urgency!).withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 左侧颜色条（根据紧急程度）
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: urgency != null 
                        ? _getUrgencyColor(urgency)
                        : (todo.isDone ? AppTheme.accentGreen : catColor.withOpacity(0.6)),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：勾选框 + 标题
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 勾选框
                        GestureDetector(
                          onTap: () => provider.toggle(todo.id),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: todo.isDone 
                                  ? AppTheme.accentGreen 
                                  : Colors.transparent,
                              border: Border.all(
                                color: todo.isDone 
                                    ? AppTheme.accentGreen 
                                    : (theme.textTheme.bodySmall?.color ?? Colors.grey).withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: todo.isDone
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 9),

                        // 标题
                        Expanded(
                          child: Text(
                            todo.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: todo.isDone ? FontWeight.w400 : FontWeight.w600,
                              decoration: todo.isDone ? TextDecoration.lineThrough : null,
                              height: 1.35,
                              color: todo.isDone
                                  ? theme.textTheme.bodySmall?.color
                                  : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // 第二行：标签区
                    Row(
                      children: [
                        // 分类标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(TodoCategoryMeta.icons[catMeta], size: 11, color: catColor),
                              const SizedBox(width: 3),
                              Text(
                                TodoCategoryMeta.names[catMeta] ?? '',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: catColor),
                              ),
                            ],
                          ),
                        ),

                        // 截止日期/倒计时标签
                        if (dlDays != null) ...[
                          const SizedBox(width: 7),
                          _CountdownBadge(daysLeft: dlDays, deadline: todo.deadline!, isOverdue: todo.isDone),
                        ],

                        // 创建时间
                        const Spacer(),
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _timeAgo(todo.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 业务逻辑 ====================

  void _addTodo(String text, TodoProvider provider) {
    final t = text.trim();
    if (t.isEmpty) return;

    // 截止日期未设置时提示
    if (_selectedDeadline == null) {
      _pickDeadline(context);
      _focusNode.requestFocus();
      return;
    }

    provider.add(TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: t,
      createdAt: DateTime.now(),
      category: _selectedCategory ?? 'research',
      deadline: _selectedDeadline,
    ));
    _ctrl.clear();
    setState(() => _selectedDeadline = null);
  }

  Future<void> _pickDeadline(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 3),
      locale: const Locale('zh', 'CN'),
      helpText: '选择截止日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primaryDark),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDeadline = date);
    }
  }

  void _showClearDialog(BuildContext context, TodoProvider provider, List<TodoItem> completed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除已完成'),
        content: Text('将删除 ${completed.length} 条已完成事项，此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { provider.clearCompleted(); Navigator.pop(ctx); },
            child: const Text('确认清除', style: TextStyle(color: AppTheme.accentRed)),
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
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
          child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded, 
              size: 42,
              color: theme.colorScheme.primary.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 22),
          Text('暂无待办事项', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('添加待办时请设置截止日期\n将自动按时间排序并显示倒计时', 
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
              )),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '\u521a\u521a';
    if (diff.inHours < 1) return '${diff.inMinutes} \u5206\u949f\u524d';
    if (diff.inDays < 1) return '${diff.inHours} \u5c0f\u65f6\u524d';
    return '${diff.inDays} \u5929\u524d';
  }

  // ==================== 工具方法 ====================

  static Color _getDeadlineColor(DateTime deadline) {
    final days = deadline.difference(DateTime.now()).inDays;
    if (days < 0) return const Color(0xFF9CA3AF); // 已过期灰色
    if (days <= 3) return const Color(0xFFEF4444); // 红
    if (days <= 7) return const Color(0xFFF59E0B); // 橙
    return const Color(0xFF3B82F6); // 蓝
  }

  static UrgencyLevel? _getUrgencyLevel(int daysLeft) {
    if (daysLeft < 0) return UrgencyLevel.overdue;
    if (daysLeft == 0) return UrgencyLevel.today;
    if (daysLeft <= 3) return UrgencyLevel.critical;
    if (daysLeft <= 7) return UrgencyLevel.warning;
    return UrgencyLevel.normal;
  }

  static Color _getUrgencyColor(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.overdone:
      case UrgencyLevel.overdue:
        return const Color(0xFF9CA3AF);
      case UrgencyLevel.today:
      case UrgencyLevel.critical:
        return const Color(0xFFEF4444);
      case UrgencyLevel.warning:
        return const Color(0xFFF59E0B);
      case UrgencyLevel.normal:
        return const Color(0xFF3B82F6);
    }
  }
}

// ==================== 枚举 & 子组件 ====================

enum UrgencyLevel { overdone, overdue, today, critical, warning, normal }

/// 筛选项数据
class _FilterItem {
  final String? category;
  final String label;
  final int count;
  const _FilterItem(this.category, this.label, this.count);
}

/// 倒计时徽章组件
class _CountdownBadge extends StatelessWidget {
  final int daysLeft;
  final DateTime deadline;
  final bool isOverdue;

  const _CountdownBadge({
    required this.daysLeft,
    required this.deadline,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isOverdue || daysLeft < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '\u2705 \u5df2\u5b8c\u6210',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        ),
      );
    }

    Color bgColor, textColor;
    IconData icon;
    String label;

    if (daysLeft == 0) {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      icon = Icons.timer_rounded;
      label = '\u4eca\u5929';
    } else if (daysLeft <= 3) {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      icon = Icons.timer_outlined;
      label = '\u5269$daysLeft\u5929';
    } else if (daysLeft <= 7) {
      bgColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFFD97706);
      icon = Icons.schedule_rounded;
      label = '$daysLeft\u5929';
    } else {
      bgColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF2563EB);
      icon = Icons.event_rounded;
      label = '$daysLeft\u5929';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: textColor),
          const SizedBox(width: 2.5),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
        ],
      ),
    );
  }
}

/// 紧急提示横幅
class _UrgencyBanner extends StatelessWidget {
  final int daysLeft;
  final DateTime deadline;
  final bool isDark;

  const _UrgencyBanner({required this.daysLeft, required this.deadline, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isCritical = daysLeft <= 3;
    final baseColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor.withOpacity(0.08), baseColor.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 17,
            color: baseColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                children: [
                  TextSpan(text: isCritical ? '\u26a0\ufe0f \u7d27\u6025\uff1a' : '\uD83D\uDCCB '),
                  TextSpan(
                    text: isCritical 
                        ? '\u6709 $daysLeft \u9879\u5f85\u529e\u5c06\u5728 3 \u5929\u5185\u6230\u671f'
                        : '\u6700\u7d27\u6025\u9879\u76ee\u8fd8\u5269 $daysLeft \u5929',
                    style: TextStyle(fontWeight: FontWeight.w600, color: baseColor),
                  ),
                  TextSpan(text: '\uff0c\u622a\u6b62\u65e5\u671f '),
                  TextSpan(
                    text: '${deadline.month}/${deadline.day}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: baseColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 渐变进度条组件
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
    if (_oldProgress != widget.progress) {
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
