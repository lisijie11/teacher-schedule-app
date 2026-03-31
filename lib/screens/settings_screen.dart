import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../services/notification_service.dart';
import '../services/holiday_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const SettingsScreen({super.key, this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: ListView(
        children: [
          _sectionHeader('外观'),
          _settingTile(
            isDark,
            icon: Icons.brightness_6,
            title: '主题模式',
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 16)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 16)),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (s) => themeProvider.setTheme(s.first),
              style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),

          _sectionHeader('提醒设置'),
          _settingTile(
            isDark,
            icon: Icons.notifications_active,
            title: '课程提前提醒',
            subtitle: '距上课开始前几分钟发出通知',
            trailing: DropdownButton<int>(
              value: scheduleProvider.reminderAdvanceMinutes,
              underline: const SizedBox(),
              items: [0, 5, 10, 15, 20, 30].map((v) {
                return DropdownMenuItem(
                  value: v,
                  child: Text(v == 0 ? '准时' : '提前$v分钟'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  scheduleProvider.setAdvanceMinutes(v);
                  _rescheduleAllNotifications(scheduleProvider, v);
                }
              },
            ),
          ),
          _settingTile(
            isDark,
            icon: Icons.alarm_on,
            title: '立即刷新所有提醒',
            subtitle: '重新安排工作日和周末的课程通知',
            onTap: () => _rescheduleAllNotifications(
                scheduleProvider, scheduleProvider.reminderAdvanceMinutes),
          ),

          _sectionHeader('节假日'),
          _settingTile(
            isDark,
            icon: Icons.celebration,
            title: '中国节假日数据',
            subtitle: '自动识别法定假日和调休，每次启动更新',
            trailing: TextButton(
              onPressed: () => HolidayService.instance.init(),
              child: const Text('手动刷新'),
            ),
          ),

          _sectionHeader('关于'),
          _settingTile(
            isDark,
            icon: Icons.person,
            title: '教师专属日程助手',
            subtitle: '支持课表管理、提醒通知、桌面小组件',
          ),
          _settingTile(
            isDark,
            icon: Icons.info_outline,
            title: '版本',
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),

          _sectionHeader('账户安全'),
          if (widget.onLogout != null)
            _settingTile(
              isDark,
              icon: Icons.logout,
              title: '退出登录',
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.red,
              ),
              onTap: widget.onLogout,
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryDark,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _settingTile(
    bool isDark, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryDark, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Future<void> _rescheduleAllNotifications(
      ScheduleProvider provider, int advanceMinutes) async {
    await NotificationService.instance.cancelAll();

    // 安排工作日课程通知
    final weekdayPeriods = SchedulePresets.weekdayPeriods.map((p) => {
          'name': p.name,
          'startTime': p.startTime,
          'endTime': p.endTime,
          'hour': p.startHour,
          'minute': p.startMinute,
        }).toList();

    await NotificationService.instance.scheduleAllClassReminders(
      periods: weekdayPeriods,
      weekdays: [1, 2, 3, 4, 5],
      advanceMinutes: advanceMinutes,
      isWeekday: true,
    );

    // 安排周末课程通知
    final weekendPeriods = SchedulePresets.weekendPeriods.map((p) => {
          'name': p.name,
          'startTime': p.startTime,
          'endTime': p.endTime,
          'hour': p.startHour,
          'minute': p.startMinute,
        }).toList();

    await NotificationService.instance.scheduleAllClassReminders(
      periods: weekendPeriods,
      weekdays: [6, 7],
      advanceMinutes: advanceMinutes,
      isWeekday: false,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 所有课程提醒已重新安排'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
    }
  }
}
