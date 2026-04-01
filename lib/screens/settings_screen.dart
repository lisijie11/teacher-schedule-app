import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/import_service.dart';
import '../services/keep_alive_service.dart';
import '../services/hyper_island_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _reminderMinutes;
  late Map<int, bool> _weekdayReminders; // 1=周一，7=周日
  late bool _weekSummaryNotification;
  late String _userName;
  late String _userLocation;
  late String _userAvatarPath;
  bool _isKeepAliveRunning = false;
  bool _isAccessibilityEnabled = false;

  static const List<String> _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkKeepAliveStatus();
  }

  Future<void> _checkKeepAliveStatus() async {
    final isRunning = await KeepAliveService.isRunning();
    final hasAccessibility = await KeepAliveService.isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        _isKeepAliveRunning = isRunning;
        _isAccessibilityEnabled = hasAccessibility;
      });
    }
  }

  void _loadSettings() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final settings = Hive.box('settings');

    _reminderMinutes = scheduleProvider.reminderAdvanceMinutes;
    
    // 加载每天的提醒开关
    _weekdayReminders = {};
    for (int i = 1; i <= 7; i++) {
      _weekdayReminders[i] = settings.get('reminder_day_$i', defaultValue: true);
    }
    
    _weekSummaryNotification = settings.get('weekSummaryNotification', defaultValue: true);
    _userName = settings.get('userName', defaultValue: '');
    _userLocation = settings.get('userLocation', defaultValue: '待定');
    _userAvatarPath = settings.get('userAvatarPath', defaultValue: '');
  }

  Future<void> _saveSettings() async {
    final settings = Hive.box('settings');
    final scheduleProvider = context.read<ScheduleProvider>();

    // 保存每天的提醒开关
    for (int i = 1; i <= 7; i++) {
      await settings.put('reminder_day_$i', _weekdayReminders[i] ?? true);
    }
    await settings.put('weekSummaryNotification', _weekSummaryNotification);
    await settings.put('userName', _userName);
    await settings.put('userLocation', _userLocation);
    await settings.put('userAvatarPath', _userAvatarPath);

    // 更新课表提醒
    scheduleProvider.setAdvanceMinutes(_reminderMinutes);

    // 重新安排所有通知
    await _rescheduleAllNotifications();

    // 更新小组件
    await WidgetService.updateWidget();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ 设置已保存'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _rescheduleAllNotifications() async {
    await NotificationService.instance.cancelAll();

    // 按天安排提醒
    for (int day = 1; day <= 7; day++) {
      if (_weekdayReminders[day] ?? true) {
        final periods = isWeekday(day) 
            ? SchedulePresets.weekdayPeriods 
            : SchedulePresets.weekendPeriods;

        await NotificationService.instance.scheduleClassReminders(
          periods: periods,
          weekdays: [day],
          advanceMinutes: _reminderMinutes,
          courseName: '课程',
          location: _userLocation,
        );
      }
    }

    // 周总结通知
    if (_weekSummaryNotification) {
      await NotificationService.instance.scheduleWeekSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text('保存', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ═══════════════════════════════════
          // 个人信息
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '个人信息'),
          _buildCard(
            theme,
            children: [
              _buildAvatarTile(theme),
              _buildDivider(isDark),
              _buildTextTile(
                theme: theme,
                icon: Icons.person_outline_rounded,
                title: '姓名',
                value: _userName.isEmpty ? '未设置' : _userName,
                onTap: () => _showTextInputDialog('姓名', _userName, (value) {
                  setState(() => _userName = value);
                }),
              ),
              _buildDivider(isDark),
              _buildTextTile(
                theme: theme,
                icon: Icons.location_on_outlined,
                title: '常用地点',
                value: _userLocation,
                onTap: () => _showTextInputDialog('常用地点', _userLocation, (value) {
                  setState(() => _userLocation = value);
                }),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════
          // 外观
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '外观'),
          _buildCard(
            theme,
            children: [
              _buildThemeTile(theme, themeProvider),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════
          // 课程提醒
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '课程提醒'),
          _buildCard(
            theme,
            children: [
              _buildReminderTimeTile(theme),
              _buildDivider(isDark),
              _buildWeekdayReminderSection(theme),
              _buildDivider(isDark),
              _buildWeekSummaryTile(theme),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════
          // 后台保活
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '后台保活'),
          _buildCard(
            theme,
            children: [
              _buildKeepAliveTile(theme),
              _buildDivider(isDark),
              _buildAccessibilityTile(theme),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════
          // 超级岛测试
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '超级岛测试'),
          _buildCard(
            theme,
            children: [
              _buildHyperIslandTestTile(theme),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════
          // 桌面小组件
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '桌面小组件'),
          _buildCard(
            theme,
            children: [
              _buildInfoTile(
                theme: theme,
                icon: Icons.widgets_outlined,
                title: '添加小组件',
                subtitle: '长按桌面 → 添加小组件 → 教师日程',
              ),
              _buildDivider(isDark),
              _buildActionTile(
                theme: theme,
                icon: Icons.refresh_rounded,
                title: '刷新小组件',
                subtitle: '点击刷新小组件显示',
                onTap: () async {
                  await WidgetService.updateWidget();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ 小组件已刷新')),
                    );
                  }
                },
              ),
              _buildDivider(isDark),
              _buildActionTile(
                theme: theme,
                icon: Icons.notifications_active_outlined,
                title: '通知进度测试',
                subtitle: '测试通知栏课程进度显示',
                onTap: () async {
                  // 模拟课程进度通知
                  final now = DateTime.now();
                  final startTime = now.subtract(const Duration(minutes: 15));
                  final endTime = now.add(const Duration(minutes: 30));
                  
                  NotificationService.instance.startClassProgressTracking(
                    courseName: '语文（测试）',
                    timeRange: '08:30-10:05',
                    location: 'A101教室',
                    startTime: startTime,
                    endTime: endTime,
                  );
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ 课程进度通知已显示，请查看通知栏')),
                    );
                  }
                  
                  // 30秒后自动停止
                  Future.delayed(const Duration(seconds: 30), () {
                    NotificationService.instance.hideClassProgress();
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════
          // 课表导入导出
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '课表导入导出'),
          _buildCard(
            theme,
            children: [
              _buildImportTile(theme),
              const Divider(height: 1),
              _buildExportTile(theme),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════
          // 关于
          // ═══════════════════════════════════
          _buildSectionTitle(theme, '关于'),
          _buildCard(
            theme,
            children: [
              _buildInfoTile(
                theme: theme,
                icon: Icons.info_outline_rounded,
                title: '版本',
                subtitle: '1.1.7',
              ),
              _buildDivider(isDark),
              _buildInfoTile(
                theme: theme,
                icon: Icons.person_outline_rounded,
                title: '制作者',
                subtitle: '李思杰',
              ),
              _buildDivider(isDark),
              _buildInfoTile(
                theme: theme,
                icon: Icons.school_outlined,
                title: '教师课表助手',
                subtitle: '专为教师设计',
              ),
            ],
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 周几提醒开关区域
  // ═══════════════════════════════════════════════
  Widget _buildWeekdayReminderSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('每日提醒', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text('开启/关闭具体某天的提醒', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 工作日（周一到周五）
          Row(
            children: [
              _buildWeekdaySwitch(theme, '周一', 1),
              _buildWeekdaySwitch(theme, '周二', 2),
              _buildWeekdaySwitch(theme, '周三', 3),
              _buildWeekdaySwitch(theme, '周四', 4),
              _buildWeekdaySwitch(theme, '周五', 5),
            ],
          ),
          const SizedBox(height: 8),
          // 周末（周六、周日）
          Row(
            children: [
              _buildWeekdaySwitch(theme, '周六', 6),
              _buildWeekdaySwitch(theme, '周日', 7),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaySwitch(ThemeData theme, String label, int day) {
    final isEnabled = _weekdayReminders[day] ?? true;
    final isWeekend = day >= 6;
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => setState(() {
            _weekdayReminders[day] = !isEnabled;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isEnabled
                ? (isWeekend ? AppTheme.accentOrange.withOpacity(0.15) : theme.colorScheme.primary.withOpacity(0.15))
                : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isEnabled
                  ? (isWeekend ? AppTheme.accentOrange.withOpacity(0.5) : theme.colorScheme.primary.withOpacity(0.5))
                  : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                      ? (isWeekend ? AppTheme.accentOrange : theme.colorScheme.primary)
                      : theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  isEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                  size: 16,
                  color: isEnabled
                    ? (isWeekend ? AppTheme.accentOrange : theme.colorScheme.primary)
                    : theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSummaryTile(ThemeData theme) {
    return _buildSwitchTile(
      theme: theme,
      icon: Icons.summarize_outlined,
      title: '周总结通知',
      subtitle: '每周五 17:00',
      value: _weekSummaryNotification,
      onChanged: (value) => setState(() => _weekSummaryNotification = value),
    );
  }

  // ═══════════════════════════════════════════════
  // 保活服务开关
  // ═══════════════════════════════════════════════
  Widget _buildKeepAliveTile(ThemeData theme) {
    return _buildSwitchTile(
      theme: theme,
      icon: Icons.battery_charging_full_rounded,
      title: '后台保活服务',
      subtitle: _isKeepAliveRunning ? '正在运行' : '已停止',
      value: _isKeepAliveRunning,
      onChanged: (value) async {
        if (value) {
          await KeepAliveService.start();
        } else {
          await KeepAliveService.stop();
        }
        await _checkKeepAliveStatus();
      },
    );
  }

  // ═══════════════════════════════════════════════
  // 超级岛测试区域
  // ═══════════════════════════════════════════════
  Widget _buildHyperIslandTestTile(ThemeData theme) {
    return Column(
      children: [
        // 状态检查
        _buildIslandStatusTile(theme),
        _buildDivider(Theme.of(context).brightness == Brightness.dark),
        // 课程提醒测试
        _buildIslandTestItem(
          theme: theme,
          icon: Icons.school_outlined,
          title: '课程提醒测试',
          subtitle: '模拟上课提醒通知',
          color: AppTheme.accentBlue,
          onTap: () => _testIsland('课程提醒测试', '高等数学 @ A301', 10),
        ),
        _buildDivider(Theme.of(context).brightness == Brightness.dark),
        // 倒计时测试
        _buildIslandTestItem(
          theme: theme,
          icon: Icons.timer_outlined,
          title: '倒计时测试',
          subtitle: '模拟10秒倒计时',
          color: AppTheme.accentOrange,
          onTap: () => _testIsland('下课倒计时', '还剩 45 分钟', 10),
        ),
        _buildDivider(Theme.of(context).brightness == Brightness.dark),
        // 会议提醒测试
        _buildIslandTestItem(
          theme: theme,
          icon: Icons.meeting_room_outlined,
          title: '会议提醒测试',
          subtitle: '模拟会议通知',
          color: AppTheme.accentGreen,
          onTap: () => _testIsland('教研会议', '下午 2:00 @ 会议室B', 10),
        ),
      ],
    );
  }

  Widget _buildIslandStatusTile(ThemeData theme) {
    return FutureBuilder<bool>(
      future: HyperIslandService.hasOverlayPermission(),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? false;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasPermission 
                      ? AppTheme.accentGreen.withOpacity(0.1)
                      : AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasPermission ? Icons.check_circle_outline : Icons.warning_outlined,
                  color: hasPermission ? AppTheme.accentGreen : AppTheme.accentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('悬浮窗权限', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      hasPermission ? '已授权，超级岛可正常显示' : '未授权，点击下方测试会提示开启',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasPermission ? AppTheme.accentGreen : AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasPermission)
                GestureDetector(
                  onTap: () async {
                    await HyperIslandService.requestOverlayPermission();
                    setState(() {}); // 刷新状态
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '授权',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIslandTestItem({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_outline_rounded,
              color: color,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testIsland(String title, String body, int duration) async {
    // 检查权限
    final hasPermission = await HyperIslandService.hasOverlayPermission();
    if (!hasPermission) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要悬浮窗权限'),
            content: const Text('超级岛功能需要悬浮窗权限才能在屏幕上显示。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  HyperIslandService.requestOverlayPermission();
                },
                child: const Text('去开启'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    // 显示超级岛
    await HyperIslandService.show(
      title: title,
      body: body,
      durationSeconds: duration,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $title 已显示'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════
  // 无障碍服务开关
  // ═══════════════════════════════════════════════
  Widget _buildAccessibilityTile(ThemeData theme) {
    return InkWell(
      onTap: () async {
        await KeepAliveService.openAccessibilitySettings();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isAccessibilityEnabled
                    ? AppTheme.accentGreen.withOpacity(0.1)
                    : AppTheme.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.accessibility_new_rounded,
                color: _isAccessibilityEnabled ? AppTheme.accentGreen : AppTheme.accentOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('无障碍保活', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    _isAccessibilityEnabled
                        ? '已开启，保活效果最佳'
                        : '未开启，建议开启以确保提醒送达',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isAccessibilityEnabled
                    ? AppTheme.accentGreen.withOpacity(0.1)
                    : AppTheme.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isAccessibilityEnabled ? '已开启' : '去开启',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _isAccessibilityEnabled ? AppTheme.accentGreen : AppTheme.accentOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 组件构建方法
  // ═══════════════════════════════════════════════

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAvatarTile(ThemeData theme) {
    return InkWell(
      onTap: () => _showAvatarPicker(),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // 头像圆形
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.1),
                image: _userAvatarPath.isNotEmpty && File(_userAvatarPath).existsSync()
                    ? DecorationImage(
                        image: FileImage(File(_userAvatarPath)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _userAvatarPath.isEmpty || !File(_userAvatarPath).existsSync()
                  ? Icon(Icons.person, color: theme.colorScheme.primary, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('头像', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    _userAvatarPath.isNotEmpty && File(_userAvatarPath).existsSync()
                        ? '点击更换头像'
                        : '点击设置头像',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // 相机图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.camera_alt_outlined, color: theme.colorScheme.primary, size: 16),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodySmall?.color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAvatarPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              if (_userAvatarPath.isNotEmpty) ...[
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red[400]),
                  title: Text('移除头像', style: TextStyle(color: Colors.red[400])),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _userAvatarPath = '');
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) {
        // 复制到应用目录
        final appDir = await getApplicationDocumentsDirectory();
        final avatarDir = Directory('${appDir.path}/avatars');
        if (!avatarDir.existsSync()) {
          avatarDir.createSync(recursive: true);
        }
        final ext = picked.path.split('.').last;
        final targetPath = '${avatarDir.path}/avatar.$ext';
        // 删除旧头像
        final oldFile = File(_userAvatarPath);
        if (oldFile.existsSync()) oldFile.deleteSync();
        // 复制新头像
        File(picked.path).copySync(targetPath);
        setState(() => _userAvatarPath = targetPath);
      }
    } catch (e) {
      print('[Settings] 选择头像失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择头像失败: $e')),
        );
      }
    }
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
    );
  }

  Widget _buildTextTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodySmall?.color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodySmall?.color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTimeTile(ThemeData theme) {
    final reminderOptions = {
      0: '准时',
      5: '提前5分钟',
      10: '提前10分钟',
      15: '提前15分钟',
      20: '提前20分钟',
      30: '提前30分钟',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('提前提醒', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(reminderOptions[_reminderMinutes] ?? '提前$_reminderMinutes分钟', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<int>(
            initialValue: _reminderMinutes,
            onSelected: (v) => setState(() => _reminderMinutes = v),
            itemBuilder: (context) => reminderOptions.entries
              .map((e) => PopupMenuItem(
                value: e.key,
                child: Text(e.value),
              ))
              .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reminderOptions[_reminderMinutes] ?? '$_reminderMinutes分钟',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(ThemeData theme, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('主题模式', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  themeProvider.themeMode == ThemeMode.system
                    ? '跟随系统'
                    : (themeProvider.themeMode == ThemeMode.light ? '浅色' : '深色'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeChip(theme, '系统', ThemeMode.system, themeProvider),
                _buildThemeChip(theme, '浅', ThemeMode.light, themeProvider),
                _buildThemeChip(theme, '深', ThemeMode.dark, themeProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeChip(ThemeData theme, String label, ThemeMode mode, ThemeProvider provider) {
    final isSelected = provider.themeMode == mode;
    return GestureDetector(
      onTap: () => provider.setTheme(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  void _showTextInputDialog(String title, String initialValue, Function(String) onSave) {
    final controller = TextEditingController(text: initialValue);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(context);
            },
            child: Text('保存', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  /// 导入课表区域
  Widget _buildImportTile(ThemeData theme) {
    return Column(
      children: [
        // 从剪贴板导入
        InkWell(
          onTap: _importFromClipboard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.content_paste_rounded, color: AppTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('从剪贴板导入', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 2),
                      Text(
                        '复制课表 JSON 后粘贴导入',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.textTheme.bodySmall?.color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 导出课表区域
  Widget _buildExportTile(ThemeData theme) {
    return Column(
      children: [
        // 分享到其他应用
        InkWell(
          onTap: _exportAndShare,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.share_rounded, color: AppTheme.accentOrange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('分享备份文件', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 2),
                      Text(
                        '导出并通过微信/QQ等分享',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.textTheme.bodySmall?.color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        _buildDivider(Theme.of(context).brightness == Brightness.dark),
        // 复制到剪贴板
        InkWell(
          onTap: _exportToClipboard,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.copy_rounded, color: AppTheme.accentGreen, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('复制到剪贴板', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 2),
                      Text(
                        '导出 JSON 到剪贴板，方便粘贴',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.textTheme.bodySmall?.color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 从剪贴板导入课表
  Future<void> _importFromClipboard() async {
    final courseProvider = context.read<CourseProvider>();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从剪贴板导入'),
        content: const Text(
          '支持两种导入方式：\n\n'
          '1. 从超级课表 App 导出 JSON 复制导入\n'
          '2. 从本应用导出的备份 JSON 导入\n\n'
          '请先复制课表数据，然后点击确定导入。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定导入'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在导入...'),
          ],
        ),
      ),
    );

    final result = await ImportService.importFromClipboard(courseProvider);
    
    if (!mounted) return;
    Navigator.pop(context);

    if (result > 0) {
      courseProvider.notifyListeners();
      await WidgetService.updateWidget();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ 成功导入 $result 门课程'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } else if (result == -2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板为空，请先复制课表数据')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导入失败，请确保复制的是正确的课表 JSON 数据'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 导出并分享
  Future<void> _exportAndShare() async {
    final courseProvider = context.read<CourseProvider>();
    
    if (courseProvider.all.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无课程，无法导出')),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在准备分享...'),
          ],
        ),
      ),
    );

    final result = await ImportService.exportAndShare(courseProvider);
    
    if (!mounted) return;
    Navigator.pop(context);

    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ 请选择分享方式'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导出失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 导出到剪贴板
  Future<void> _exportToClipboard() async {
    final courseProvider = context.read<CourseProvider>();
    
    if (courseProvider.all.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无课程，无法导出')),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在导出...'),
          ],
        ),
      ),
    );

    final result = await ImportService.exportToClipboard(courseProvider);
    
    if (!mounted) return;
    Navigator.pop(context);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ 课表数据已复制到剪贴板'),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导出失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
