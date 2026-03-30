import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../services/notification_service.dart';
import 'dart:math';

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
        title: const Text(
          '课表',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '工作日（东软学院）'),
            Tab(text: '周末学校'),
          ],
          labelColor: AppTheme.primaryDark,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryDark,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleView(context, isDark, ScheduleMode.weekday),
          _buildScheduleView(context, isDark, ScheduleMode.weekend),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context),
        icon: const Icon(Icons.add_alarm),
        label: const Text('添加提醒'),
      ),
    );
  }

  Widget _buildScheduleView(
      BuildContext context, bool isDark, ScheduleMode mode) {
    final periods = SchedulePresets.getPeriodsForMode(mode);
    final provider = context.watch<ScheduleProvider>();
    final reminders = provider.getRemindersForMode(mode == ScheduleMode.weekday);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 课程表卡片
        _sectionTitle(isDark, '课程节次'),
        ...periods.map((p) => _buildPeriodCard(isDark, p)),

        const SizedBox(height: 16),

        // 自定义提醒
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitleWidget(isDark, '自定义提醒'),
            TextButton.icon(
              onPressed: () => _showAddReminderDialog(context,
                  forWeekday: mode == ScheduleMode.weekday),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加'),
            ),
          ],
        ),

        if (reminders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.alarm_add,
                      size: 36,
                      color: isDark ? Colors.white30 : Colors.black26),
                  const SizedBox(height: 8),
                  Text(
                    '还没有自定义提醒\n点击右上角添加',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...reminders.map((r) => _buildReminderTile(context, isDark, r)),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionTitle(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _sectionTitleWidget(bool isDark, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }

  Widget _buildPeriodCard(bool isDark, ClassPeriod period) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${period.index}',
                style: const TextStyle(
                    color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              period.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${period.startTime} - ${period.endTime}',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 13,
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
        leading: Icon(
          Icons.alarm,
          color: reminder.isEnabled ? AppTheme.primaryDark : Colors.grey,
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            color: reminder.isEnabled
                ? null
                : (isDark ? Colors.white38 : Colors.black38),
          ),
        ),
        subtitle: Text(reminder.timeString),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.isEnabled,
              onChanged: (_) => provider.toggleReminder(reminder.id),
              activeColor: AppTheme.primaryDark,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
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

  void _showAddReminderDialog(BuildContext context, {bool forWeekday = true}) {
    final titleCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isWeekday = forWeekday;
    int advanceMinutes = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('新建提醒',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: '提醒名称',
                  border: OutlineInputBorder(),
                  hintText: '如：准备上课、批改作业...',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text('提醒时间：${selectedTime.format(context)}'),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (t != null) setS(() => selectedTime = t);
                },
              ),
              Row(
                children: [
                  const Text('适用于：'),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('工作日'),
                    selected: isWeekday,
                    onSelected: (v) => setS(() => isWeekday = v),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('周末'),
                    selected: !isWeekday,
                    onSelected: (v) => setS(() => isWeekday = !v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (titleCtrl.text.isEmpty) return;
                    final reminder = ReminderItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleCtrl.text,
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      isWeekday: isWeekday,
                      advanceMinutes: advanceMinutes,
                    );
                    context.read<ScheduleProvider>().addReminder(reminder);

                    // 安排通知
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
                  child: const Text('保存提醒', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
