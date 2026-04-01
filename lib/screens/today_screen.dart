import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../services/holiday_service.dart';
import '../services/notification_service.dart';
import '../services/calendar_service.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with TickerProviderStateMixin {
  late Timer _timer;
  late DateTime _now;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
    
    // 脉冲动画控制器 - 用于进度条闪烁效果
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 启动智能通知系统（上课前30分钟提醒 + 上课中常驻进度）
    NotificationService.instance.startSmartNotification();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    // 停止智能通知系统
    NotificationService.instance.stopSmartNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final todayWeekday = _now.weekday; // 1=周一，7=周日
    final dayType = HolidayService.instance.getDayType(_now);
    final holidayNote = HolidayService.instance.getHolidayNote(_now);
    final periods = SchedulePresets.getPeriodsForWeekday(todayWeekday);
    final modeLabel = SchedulePresets.getModeLabel(todayWeekday);

    final nowMinutes = _now.hour * 60 + _now.minute;
    ClassPeriod? currentPeriod;
    ClassPeriod? nextPeriod;
    int? minutesToNext;

    for (final period in periods) {
      final startMin = period.startHour * 60 + period.startMinute;
      final endMin = period.endHour * 60 + period.endMinute;
      if (nowMinutes >= startMin && nowMinutes < endMin) {
        currentPeriod = period;
      } else if (nowMinutes < startMin && nextPeriod == null) {
        nextPeriod = period;
        minutesToNext = startMin - nowMinutes;
      }
    }

    final passedCount = periods.where((p) {
      final endMin = p.endHour * 60 + p.endMinute;
      return nowMinutes >= endMin;
    }).length;
    final progress = periods.isEmpty ? 0.0 : passedCount / periods.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 澎湃OS3 风格顶部
            SliverToBoxAdapter(
              child: _buildHeader(context, isDark, dayType, holidayNote, modeLabel, passedCount, periods.length, progress),
            ),
            
            // 状态卡片
            SliverToBoxAdapter(
              child: _buildStatusCard(context, isDark, currentPeriod, nextPeriod, minutesToNext),
            ),
            
            // 今日课程标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text(
                      '今日课程',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '共 ${periods.length} 节',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 课程列表
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final period = periods[index];
                    final startMin = period.startHour * 60 + period.startMinute;
                    final endMin = period.endHour * 60 + period.endMinute;
                    final isActive = nowMinutes >= startMin && nowMinutes < endMin;
                    final isPast = nowMinutes >= endMin;
                    final isNext = !isActive && !isPast && nextPeriod?.index == period.index;
                    
                    final courseProvider = context.watch<CourseProvider>();
                    final course = courseProvider.getEntry(todayWeekday, period.index);

                    return _buildPeriodTile(
                      context, isDark, period, isActive, isPast, isNext, nowMinutes, course,
                    );
                  },
                  childCount: periods.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    DayType dayType,
    String? holidayNote,
    String modeLabel,
    int passedCount,
    int totalCount,
    double progress,
  ) {
    final theme = Theme.of(context);
    final weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateStr = '${_now.month}月${_now.day}日  ${weekdays[_now.weekday]}';
    final timeStr = DateFormat('HH:mm').format(_now);

    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;
    
    if (dayType == DayType.holiday) {
      badgeColor = AppTheme.accentGreen;
      badgeIcon = Icons.celebration_rounded;
      badgeLabel = holidayNote ?? '假日';
    } else if (dayType == DayType.workday && _now.weekday > 5) {
      badgeColor = AppTheme.accentOrange;
      badgeIcon = Icons.work_outline_rounded;
      badgeLabel = '调休';
    } else if (_now.weekday <= 5) {
      badgeColor = theme.colorScheme.primary;
      badgeIcon = Icons.school_rounded;
      badgeLabel = '工作日';
    } else {
      badgeColor = AppTheme.accentTeal;
      badgeIcon = Icons.weekend_rounded;
      badgeLabel = '休息日';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间 + 标签
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.displayLarge?.color,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 进度指示
          if (totalCount > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$passedCount / $totalCount 节',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],

          // 一键添加到日历按钮
          const SizedBox(height: 16),
          _buildAddToCalendarButton(context, isDark),
        ],
      ),
    );
  }

  Widget _buildAddToCalendarButton(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _onAddToCalendar(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '一键添加到日历',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '未来7天',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAddToCalendar(BuildContext context) async {
    final courseProvider = context.read<CourseProvider>();
    final courses = courseProvider.all;

    if (courses.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('还没有添加任何课程哦～'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // 显示加载提示
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('正在添加课程到日历...'),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );

    final result = await CalendarService.instance.addNextWeekCourses(courses);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.hasErrors ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(result.message)),
          ],
        ),
        backgroundColor: result.added > 0 ? Colors.green.shade700 : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: result.added > 0 ? 3 : 4),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    bool isDark,
    ClassPeriod? current,
    ClassPeriod? next,
    int? minutesToNext,
  ) {
    final theme = Theme.of(context);
    final bool isFinished = current == null && next == null;

    Color accentColor;
    IconData accentIcon;
    String labelTop;
    String labelMain;
    String labelSub;

    if (current != null) {
      accentColor = AppTheme.accentGreen;
      accentIcon = Icons.play_circle_rounded;
      labelTop = '● 上课中';
      labelMain = current.name;
      labelSub = '${current.startTime} — ${current.endTime}';
    } else if (next != null) {
      accentColor = theme.colorScheme.primary;
      accentIcon = Icons.schedule_rounded;
      labelTop = '下节课';
      labelMain = next.name;
      labelSub = '$minutesToNext 分钟后开始 · ${next.startTime}';
    } else {
      accentColor = AppTheme.accentTeal;
      accentIcon = Icons.check_circle_rounded;
      labelTop = '今日完成';
      labelMain = '好好休息';
      labelSub = '明天继续加油 ✨';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
            ? theme.colorScheme.outline.withOpacity(0.5)
            : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(accentIcon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelTop,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labelMain,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  labelSub,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTile(
    BuildContext context,
    bool isDark,
    ClassPeriod period,
    bool isActive,
    bool isPast,
    bool isNext,
    int nowMinutes,
    CourseEntry? course,
  ) {
    final theme = Theme.of(context);
    Color dotColor;
    Color cardBg;
    Color borderColor;
    Color titleColor;
    Color timeColor;

    if (isActive) {
      dotColor = AppTheme.accentGreen;
      cardBg = theme.cardColor;
      borderColor = AppTheme.accentGreen.withOpacity(0.4);
      titleColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
      timeColor = AppTheme.accentGreen;
    } else if (isPast) {
      dotColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
      cardBg = theme.cardColor.withOpacity(0.6);
      borderColor = theme.colorScheme.outline.withOpacity(0.3);
      titleColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
      timeColor = theme.textTheme.labelSmall?.color ?? Colors.grey;
    } else if (isNext) {
      dotColor = theme.colorScheme.primary;
      cardBg = theme.colorScheme.primary.withOpacity(isDark ? 0.12 : 0.06);
      borderColor = theme.colorScheme.primary.withOpacity(0.4);
      titleColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
      timeColor = theme.colorScheme.primary;
    } else {
      dotColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
      cardBg = theme.cardColor;
      borderColor = theme.colorScheme.outline.withOpacity(0.3);
      titleColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
      timeColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    }

    // 计算课程内进度
    double? inClassProgress;
    int? remainingMinutes;
    if (isActive) {
      final startMin = period.startHour * 60 + period.startMinute;
      final endMin = period.endHour * 60 + period.endMinute;
      inClassProgress = (nowMinutes - startMin) / (endMin - startMin);
      inClassProgress = inClassProgress.clamp(0.0, 1.0);
      remainingMinutes = endMin - nowMinutes;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 节次圆点
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: dotColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${period.index}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dotColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                
                // 课程信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (course != null && course.courseName.isNotEmpty)
                          ? course.courseName
                          : period.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isActive || isNext ? FontWeight.w600 : FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      if (course != null && course.classroom.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '📍 ${course.classroom}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // 时间
                Text(
                  '${period.startTime} - ${period.endTime}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: timeColor,
                  ),
                ),
                
                // 已完成标记
                if (isPast) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: timeColor.withOpacity(0.6),
                  ),
                ],
              ],
            ),
          ),
          
          // 精美进度条 - 整条横条背景+动效
          if (isActive)
            _AnimatedCourseProgressBar(
              progress: inClassProgress!,
              remainingMinutes: remainingMinutes!,
              isDark: isDark,
              pulseAnimation: _pulseAnimation,
            ),
        ],
      ),
    );
  }
}

/// 精美动效课程进度条组件
class _AnimatedCourseProgressBar extends StatelessWidget {
  final double progress;
  final int remainingMinutes;
  final bool isDark;
  final Animation<double> pulseAnimation;

  const _AnimatedCourseProgressBar({
    required this.progress,
    required this.remainingMinutes,
    required this.isDark,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
        // 背景
        color: AppTheme.accentGreen.withOpacity(0.08),
      ),
      child: Column(
        children: [
          // 进度条主体
          Stack(
            children: [
              // 背景轨道
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: AppTheme.accentGreen.withOpacity(0.15),
                ),
              ),
              
              // 渐变进度条
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentGreen,
                            AppTheme.accentGreen.withGreen(200).withBlue(220),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGreen.withOpacity(0.4 + pulseAnimation.value * 0.2),
                            blurRadius: 6 + pulseAnimation.value * 4,
                            spreadRadius: pulseAnimation.value * 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // 进度光点
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  final offset = progress.clamp(0.0, 1.0);
                  return Positioned(
                    left: offset * (MediaQuery.of(context).size.width - 64) - 4,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGreen.withOpacity(0.8),
                            blurRadius: 6 + pulseAnimation.value * 4,
                            spreadRadius: pulseAnimation.value * 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          
          // 底部信息栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                // 左侧 - 进度百分比
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // 中间 - 已过时间
                Expanded(
                  child: Text(
                    '剩余 $remainingMinutes 分钟',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                
                // 右侧 - 脉冲点动画
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (context, child) {
                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentGreen.withOpacity(0.5 + pulseAnimation.value * 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '进行中',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.accentGreen.withOpacity(0.8 + pulseAnimation.value * 0.2),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
