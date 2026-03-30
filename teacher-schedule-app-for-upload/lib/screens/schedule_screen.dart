import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../services/notification_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('课表'),
        actions: [
          IconButton(
            onPressed: () => _showCourseHint(context),
            icon: const Icon(Icons.help_outline_rounded, size: 20),
            tooltip: '使用说明',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBg3 : AppTheme.lightBg1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black.withOpacity(0.45),
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '工作日'),
                Tab(text: '周末'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleView(context, isDark, ScheduleMode.weekday),
          _buildScheduleView(context, isDark, ScheduleMode.weekend),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  课表视图
  // ──────────────────────────────────────────
  Widget _buildScheduleView(
      BuildContext context, bool isDark, ScheduleMode mode) {
    final periods = SchedulePresets.getPeriodsForMode(mode);
    final scheduleProvider = context.watch<ScheduleProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final reminders =
        scheduleProvider.getRemindersForMode(mode == ScheduleMode.weekday);
    final isWeekday = mode == ScheduleMode.weekday;

    final amPeriods = periods.where((p) => p.startHour < 12).toList();
    final pmPeriods = periods.where((p) => p.startHour >= 12).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const BouncingScrollPhysics(),
      children: [
        // 提示横幅
        _buildEditHint(isDark),
        const SizedBox(height: 12),

        // 上午
        if (amPeriods.isNotEmpty) ...[
          _sectionHeader(isDark, '上午', Icons.wb_sunny_outlined),
          const SizedBox(height: 8),
          ...amPeriods.map((p) => _buildPeriodCard(
              context, isDark, p, isWeekday, courseProvider)),
          const SizedBox(height: 16),
        ],

        // 下午
        if (pmPeriods.isNotEmpty) ...[
          _sectionHeader(isDark, '下午', Icons.wb_twilight_outlined),
          const SizedBox(height: 8),
          ...pmPeriods.map((p) => _buildPeriodCard(
              context, isDark, p, isWeekday, courseProvider)),
          const SizedBox(height: 16),
        ],

        // 自定义提醒
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader(isDark, '自定义提醒', Icons.alarm_rounded),
            TextButton.icon(
              onPressed: () => _showAddReminderDialog(context,
                  forWeekday: mode == ScheduleMode.weekday),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('添加'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (reminders.isEmpty)
          _buildEmptyReminders(isDark)
        else
          ...reminders.map((r) => _buildReminderTile(context, isDark, r)),

        const SizedBox(height: 90),
      ],
    );
  }

  // ──────────────────────────────────────────
  //  编辑提示横幅
  // ──────────────────────────────────────────
  Widget _buildEditHint(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryDark.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded,
              size: 16, color: AppTheme.primaryDark.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '点击节次卡片，可为该节课填写课程名称和教室',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.primaryDark.withOpacity(0.85)
                    : AppTheme.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  节次卡片（可点击录入）
  // ──────────────────────────────────────────
  Widget _buildPeriodCard(
    BuildContext context,
    bool isDark,
    ClassPeriod period,
    bool isWeekday,
    CourseProvider courseProvider,
  ) {
    final hues = [
      AppTheme.primaryDark,
      const Color(0xFF5B8AF5),
      const Color(0xFF7B68EE),
      const Color(0xFF9370DB),
      const Color(0xFF5B8AF5),
      AppTheme.primaryDark,
      const Color(0xFF7B68EE),
      const Color(0xFF5B8AF5),
    ];
    final accentColor = hues[(period.index - 1) % hues.length];

    final course = courseProvider.getEntry(isWeekday, period.index);
    final hasCourse = course != null && course.courseName.isNotEmpty;

    return GestureDetector(
      onTap: () => _showCourseEditSheet(context, isDark, period, isWeekday,
          courseProvider, course),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: hasCourse
              ? (course.color).withOpacity(isDark ? 0.08 : 0.05)
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasCourse
                ? course.color.withOpacity(0.35)
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // 节次序号
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (hasCourse ? course.color : accentColor)
                      .withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${period.index}',
                    style: TextStyle(
                      color: hasCourse ? course.color : accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 中间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 课程名称（有则显示，无则显示节次名）
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasCourse ? course.courseName : period.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: hasCourse
                                  ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1B30))
                                  : (isDark
                                      ? const Color(0xFFCDD0FF)
                                      : const Color(0xFF1A1B30)),
                            ),
                          ),
                        ),
                        if (hasCourse)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: course.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '已填写',
                              style: TextStyle(
                                fontSize: 10,
                                color: course.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // 教室 or 时长
                    Text(
                      hasCourse && course.classroom.isNotEmpty
                          ? '📍 ${course.classroom}  ·  ${period.duration.inMinutes}分钟'
                          : '时长 ${period.duration.inMinutes} 分钟  ·  点击填写课程',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.38),
                      ),
                    ),
                  ],
                ),
              ),

              // 右侧时间
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    period.startTime,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFCDD0FF)
                          : const Color(0xFF2A2B50),
                    ),
                  ),
                  Text(
                    period.endTime,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.38),
                    ),
                  ),
                ],
              ),

              // 编辑箭头
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  课程录入底部弹窗
  // ──────────────────────────────────────────
  void _showCourseEditSheet(
    BuildContext context,
    bool isDark,
    ClassPeriod period,
    bool isWeekday,
    CourseProvider courseProvider,
    CourseEntry? existing,
  ) {
    final nameCtrl =
        TextEditingController(text: existing?.courseName ?? '');
    final roomCtrl =
        TextEditingController(text: existing?.classroom ?? '');
    final noteCtrl =
        TextEditingController(text: existing?.note ?? '');
    int selectedColor = existing?.colorIndex ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final sheetDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
            decoration: BoxDecoration(
              color: sheetDark ? AppTheme.darkBg2 : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽条
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 标题行
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CourseEntry.palette[selectedColor]
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '第${period.index}节',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: CourseEntry.palette[selectedColor],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existing != null ? '编辑课程' : '填写课程信息',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${period.startTime} — ${period.endTime}  ·  ${period.duration.inMinutes}分钟',
                            style: TextStyle(
                              fontSize: 12,
                              color: sheetDark
                                  ? Colors.white.withOpacity(0.45)
                                  : Colors.black.withOpacity(0.38),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 删除按钮（已有课程时显示）
                    if (existing != null)
                      IconButton(
                        onPressed: () {
                          courseProvider.remove(existing.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('已清除该节课程'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 20),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // 颜色选择
                Text(
                  '颜色标记',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sheetDark ? Colors.white60 : Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(
                    CourseEntry.palette.length,
                    (i) => GestureDetector(
                      onTap: () => setS(() => selectedColor = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 10),
                        width: selectedColor == i ? 30 : 24,
                        height: selectedColor == i ? 30 : 24,
                        decoration: BoxDecoration(
                          color: CourseEntry.palette[i],
                          shape: BoxShape.circle,
                          border: selectedColor == i
                              ? Border.all(
                                  color: Colors.white, width: 2.5)
                              : null,
                          boxShadow: selectedColor == i
                              ? [
                                  BoxShadow(
                                    color: CourseEntry.palette[i]
                                        .withOpacity(0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: selectedColor == i
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 课程名称
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '课程名称',
                    hintText: '如：数字合成技术、传播学...',
                    prefixIcon:
                        Icon(Icons.book_rounded, size: 18),
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // 教室
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(
                    labelText: '教室 / 地点',
                    hintText: '如：A304、实验楼201...',
                    prefixIcon:
                        Icon(Icons.room_outlined, size: 18),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // 备注（可选）
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: '备注（可选）',
                    hintText: '如：记得带教材...',
                    prefixIcon:
                        const Icon(Icons.notes_rounded, size: 18),
                    suffixText: '选填',
                    suffixStyle: TextStyle(
                      fontSize: 11,
                      color:
                          sheetDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.26),
                    ),
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 20),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          CourseEntry.palette[selectedColor],
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('请填写课程名称'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        );
                        return;
                      }
                      final entry = CourseEntry(
                        id: existing?.id ??
                            '${isWeekday ? "w" : "e"}_${period.index}',
                        isWeekday: isWeekday,
                        periodIndex: period.index,
                        courseName: name,
                        classroom: roomCtrl.text.trim(),
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        colorIndex: selectedColor,
                      );
                      courseProvider.save(entry);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ 第${period.index}节课已保存'),
                          backgroundColor: CourseEntry.palette[selectedColor],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: Text(
                      existing != null ? '保存修改' : '保存课程',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  //  提醒相关组件
  // ──────────────────────────────────────────
  Widget _buildEmptyReminders(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.alarm_add_rounded,
              size: 36,
              color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.20)),
          const SizedBox(height: 10),
          Text(
            '还没有自定义提醒',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.38),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右上角「添加」设置提醒',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.26),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(
      BuildContext context, bool isDark, ReminderItem reminder) {
    final provider = context.read<ScheduleProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: reminder.isEnabled
                ? AppTheme.primaryDark.withOpacity(0.12)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.alarm_rounded,
            color: reminder.isEnabled ? AppTheme.primaryDark : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: reminder.isEnabled
                ? null
                : (isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.30)),
          ),
        ),
        subtitle: Text(
          reminder.timeString,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.38),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.isEnabled,
              onChanged: (_) => provider.toggleReminder(reminder.id),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18,
                  color: isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.26)),
              onPressed: () {
                provider.removeReminder(reminder.id);
                NotificationService.instance.cancel(reminder.id.hashCode);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(bool isDark, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon,
            size: 14, color: AppTheme.primaryDark.withOpacity(0.8)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  void _showAddReminderDialog(BuildContext context, {bool forWeekday = true}) {
    final titleCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isWeekday = forWeekday;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBg2 : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text('新建提醒',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '提醒名称',
                    hintText: '如：准备上课、打印讲义...',
                    prefixIcon: Icon(Icons.edit_rounded, size: 18),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (t != null) setS(() => selectedTime = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBg3 : AppTheme.lightBg1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 18, color: AppTheme.primaryDark),
                        const SizedBox(width: 10),
                        Text(
                          '提醒时间：${selectedTime.format(context)}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color:
                                isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.26)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('适用于：',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        )),
                    const SizedBox(width: 10),
                    _filterChip(isDark, '工作日', isWeekday,
                        () => setS(() => isWeekday = true)),
                    const SizedBox(width: 8),
                    _filterChip(isDark, '周末', !isWeekday,
                        () => setS(() => isWeekday = false)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final reminder = ReminderItem(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        title: titleCtrl.text.trim(),
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                        isWeekday: isWeekday,
                        advanceMinutes: 0,
                      );
                      context.read<ScheduleProvider>().addReminder(reminder);
                      NotificationService.instance.scheduleWeeklyNotification(
                        id: reminder.id.hashCode,
                        title: reminder.title,
                        body: '提醒时间：${reminder.timeString}',
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                        weekdays: isWeekday ? [1, 2, 3, 4, 5] : [6, 7],
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('保存提醒',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(
      bool isDark, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryDark
              : (isDark ? AppTheme.darkBg3 : AppTheme.lightBg1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primaryDark
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  void _showCourseHint(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppTheme.primaryDark, size: 22),
            SizedBox(width: 8),
            Text('课程录入说明'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📌 点击节次卡片 → 弹出编辑窗口'),
            SizedBox(height: 8),
            Text('✏️ 填写课程名称、教室、备注'),
            SizedBox(height: 8),
            Text('🎨 选择颜色标记不同课程'),
            SizedBox(height: 8),
            Text('🗑️ 已填写的课程可在编辑窗口删除'),
            SizedBox(height: 8),
            Text('💾 数据本地保存，重启不丢失'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('明白了'),
          ),
        ],
      ),
    );
  }
}
