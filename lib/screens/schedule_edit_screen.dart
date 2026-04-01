import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/schedule_model.dart';
import '../theme.dart';

/// 作息时间自定义页面
class ScheduleEditScreen extends StatefulWidget {
  final bool isWeekday; // true=工作日，false=周末

  const ScheduleEditScreen({super.key, required this.isWeekday});

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  late List<ClassPeriod> _periods;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // 复制当前作息表以便编辑
    _periods = widget.isWeekday
        ? List.from(SchedulePresets.weekdayPeriods)
        : List.from(SchedulePresets.weekendPeriods);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveSchedule() async {
    await SchedulePresets.saveCustomSchedule(
      weekday: widget.isWeekday ? _periods : null,
      weekend: widget.isWeekday ? null : _periods,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ 作息时间已保存'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      Navigator.pop(context, true); // 返回 true 表示有更改
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认'),
        content: const Text('确定要恢复默认作息时间吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SchedulePresets.resetToDefault();
      if (mounted) {
        setState(() {
          _periods = widget.isWeekday
              ? List.from(SchedulePresets.weekdayPeriodsDefault)
              : List.from(SchedulePresets.weekendPeriodsDefault);
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ 已恢复默认作息时间'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    }
  }

  Future<void> _editTime(int index, bool isStart) async {
    final period = _periods[index];
    final hour = isStart ? period.startHour : period.endHour;
    final minute = isStart ? period.startMinute : period.endMinute;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _periods[index] = ClassPeriod(
          index: period.index,
          name: period.name,
          startHour: isStart ? time.hour : period.startHour,
          startMinute: isStart ? time.minute : period.startMinute,
          endHour: isStart ? period.endHour : time.hour,
          endMinute: isStart ? period.endMinute : time.minute,
        );
      });
      _markChanged();
    }
  }

  Future<void> _editName(int index) async {
    final period = _periods[index];
    final controller = TextEditingController(text: period.name);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑节次名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '例如：第1-2节、上午',
          ),
          inputFormatters: [
            LengthLimitingTextInputFormatter(8),
          ],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _periods[index] = ClassPeriod(
          index: period.index,
          name: result,
          startHour: period.startHour,
          startMinute: period.startMinute,
          endHour: period.endHour,
          endMinute: period.endMinute,
        );
      });
      _markChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = widget.isWeekday ? '工作日作息' : '周末作息';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: _hasChanges ? _saveSchedule : null,
            child: Text(
              '保存',
              style: TextStyle(
                color: _hasChanges ? theme.colorScheme.primary : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '点击时间可编辑，开始时间包含该节次的提醒时间',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 作息列表
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _periods.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _periods.removeAt(oldIndex);
                  _periods.insert(newIndex, item);
                  // 重新编号
                  for (int i = 0; i < _periods.length; i++) {
                    _periods[i] = ClassPeriod(
                      index: i + 1,
                      name: _periods[i].name,
                      startHour: _periods[i].startHour,
                      startMinute: _periods[i].startMinute,
                      endHour: _periods[i].endHour,
                      endMinute: _periods[i].endMinute,
                    );
                  }
                });
                _markChanged();
              },
              itemBuilder: (context, index) {
                final period = _periods[index];
                return _buildPeriodCard(
                  key: ValueKey('period_$index'),
                  theme: theme,
                  isDark: isDark,
                  period: period,
                  index: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard({
    required Key key,
    required ThemeData theme,
    required bool isDark,
    required ClassPeriod period,
    required int index,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editName(index),
                    child: Text(
                      period.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 时间行
            Row(
              children: [
                Expanded(
                  child: _buildTimeButton(
                    theme: theme,
                    label: '开始',
                    time: period.startTime,
                    onTap: () => _editTime(index, true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ),
                Expanded(
                  child: _buildTimeButton(
                    theme: theme,
                    label: '结束',
                    time: period.endTime,
                    onTap: () => _editTime(index, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required ThemeData theme,
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
