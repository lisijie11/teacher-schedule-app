import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../models/todo_model.dart';
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

    // 计算当前周数
    int currentWeek = 1;
    int totalWeeks = 20;
    try {
      final settings = Hive.box('settings');
      final semesterStartStr = settings.get('semesterStartDate', defaultValue: '');
      totalWeeks = settings.get('totalWeeks', defaultValue: 20);
      if (semesterStartStr.isNotEmpty) {
        final semesterStart = DateTime.parse(semesterStartStr);
        final daysSinceStart = _now.difference(semesterStart).inDays;
        final startWeekday = semesterStart.weekday; // 1=周一
        final adjustedDays = daysSinceStart + (startWeekday - 1);
        currentWeek = (adjustedDays / 7).floor() + 1;
        if (currentWeek < 1) currentWeek = 1;
        if (currentWeek > totalWeeks) currentWeek = totalWeeks;
      }
    } catch (e) {
      // 计算失败时使用默认值
    }

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

    // 计算今日有课程的节数
    final courseProvider = context.watch<CourseProvider>();
    final todayCourseCount = periods.where((period) {
      final course = courseProvider.getEntry(todayWeekday, period.index);
      return course != null && course.courseName.isNotEmpty;
    }).length;
    final hasNoCoursesToday = todayCourseCount == 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 澎湃OS3 风格顶部
            SliverToBoxAdapter(
              child: _buildHeader(context, isDark, dayType, holidayNote, modeLabel, passedCount, periods.length, progress, currentWeek, totalWeeks),
            ),
            
            // 状态卡片
            SliverToBoxAdapter(
              child: Consumer<CourseProvider>(
                builder: (context, courseProvider, _) {
                  // 根据是否有课程来判断当前/下一节
                  ClassPeriod? actualCurrentPeriod;
                  ClassPeriod? actualNextPeriod;
                  int? actualMinutesToNext;
                  
                  for (final period in periods) {
                    final course = courseProvider.getEntry(todayWeekday, period.index);
                    final hasCourse = course != null && course.courseName.isNotEmpty;
                    if (!hasCourse) continue;
                    
                    final startMin = period.startHour * 60 + period.startMinute;
                    final endMin = period.endHour * 60 + period.endMinute;
                    if (nowMinutes >= startMin && nowMinutes < endMin) {
                      actualCurrentPeriod = period;
                    } else if (nowMinutes < startMin && actualNextPeriod == null) {
                      actualNextPeriod = period;
                      actualMinutesToNext = startMin - nowMinutes;
                    }
                  }
                  
                  final tomorrowInfo = _getTomorrowCourseInfo(courseProvider, todayWeekday);
                  return _buildStatusCard(
                    context, isDark, actualCurrentPeriod, actualNextPeriod, actualMinutesToNext, tomorrowInfo,
                  );
                },
              ),
            ),
            
            // 今日内容区（有课显示课程，没课显示待办）
            SliverToBoxAdapter(
              child: hasNoCoursesToday 
                ? _buildTodoSection(context, isDark, nowMinutes)
                : _buildCourseSection(context, isDark, periods, todayWeekday, nowMinutes, passedCount),
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
    int currentWeek,
    int totalWeeks,
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
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
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '第$currentWeek周 / 共$totalWeeks周',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
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
          const SizedBox(height: 8),
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

    // 1. 请求日历权限
    final hasPermission = await CalendarService.instance.requestPermissions();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.block_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('需要日历权限才能添加课程')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // 2. 获取日历列表并让用户选择
    final calendars = await CalendarService.instance.getCalendars();
    if (calendars.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('没有找到可写入的日历'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // 如果只有一个日历直接使用，否则弹出选择
    final selectedCal = calendars.length == 1
        ? calendars.first
        : await CalendarService.instance.showCalendarPicker(context);

    if (selectedCal == null) return; // 用户取消选择

    // 3. 显示加载提示
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
            Expanded(child: Text('正在添加课程到「${selectedCal.name}」...')),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );

    // 4. 批量写入日历（静默，无弹窗）
    final scheduleProvider = context.read<ScheduleProvider>();
    final result = await CalendarService.instance.addNextWeekCoursesTo(
      selectedCal.id!,
      courses,
    );

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

  /// 获取明天课程信息的元组
  /// 返回: (weekday, periods, courses)
  (int, List<ClassPeriod>, List<CourseEntry>) _getTomorrowCourseInfo(CourseProvider courseProvider, int todayWeekday) {
    // 计算明天是周几
    final tomorrowWeekday = todayWeekday == 7 ? 1 : todayWeekday + 1;
    final tomorrowPeriods = SchedulePresets.getPeriodsForWeekday(tomorrowWeekday);

    // 获取明天所有有课程的节次
    final courses = <CourseEntry>[];
    for (final period in tomorrowPeriods) {
      final course = courseProvider.getEntry(tomorrowWeekday, period.index);
      if (course != null && course.courseName.isNotEmpty) {
        courses.add(course);
      }
    }
    return (tomorrowWeekday, tomorrowPeriods, courses);
  }

  Widget _buildStatusCard(
    BuildContext context,
    bool isDark,
    ClassPeriod? current,
    ClassPeriod? next,
    int? minutesToNext,
    (int, List<ClassPeriod>, List<CourseEntry>) tomorrowInfo,
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
      
      // 解构明天课程信息
      final (tomorrowWeekday, tomorrowPeriods, tomorrowCourses) = tomorrowInfo;

      if (tomorrowCourses.isNotEmpty) {
        // 计算明天日期和星期
        final tomorrowDate = DateTime.now().add(const Duration(days: 1));
        final dateStr = '${tomorrowDate.month}月${tomorrowDate.day}日';
        final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final weekdayName = weekdayNames[tomorrowDate.weekday];

        // 区分上午/下午课程
        int morningCount = 0;
        int afternoonCount = 0;
        for (final course in tomorrowCourses) {
          final period = tomorrowPeriods.firstWhere(
            (p) => p.index == course.periodIndex,
            orElse: () => tomorrowPeriods.first,
          );
          // 上午: 第1-4节, 下午: 第5-8节
          if (course.periodIndex <= 4) {
            morningCount++;
          } else {
            afternoonCount++;
          }
        }

        // 构建详细课程列表
        final courseDetails = <String>[];
        for (final course in tomorrowCourses) {
          final period = tomorrowPeriods.firstWhere(
            (p) => p.index == course.periodIndex,
            orElse: () => tomorrowPeriods.first,
          );
          final timePart = course.periodIndex <= 4 ? '上午' : '下午';
          final location = course.classroom.isNotEmpty ? ' · ${course.classroom}' : '';
          courseDetails.add('$timePart ${period.name} ${course.courseName}$location');
        }

        // 显示第一条课程作为主标题
        labelMain = tomorrowCourses.first.courseName;
        // 显示副标题：日期 + 上下午课程数 + 第一条课程节次
        final firstCourse = tomorrowCourses.first;
        final firstPeriod = tomorrowPeriods.firstWhere(
          (p) => p.index == firstCourse.periodIndex,
          orElse: () => tomorrowPeriods.first,
        );
        final firstTimePart = firstCourse.periodIndex <= 4 ? '上午' : '下午';
        final summary = <String>[];
        if (morningCount > 0) summary.add('上午$morningCount节');
        if (afternoonCount > 0) summary.add('下午$afternoonCount节');
        labelSub = '明日 $weekdayName $dateStr · ${summary.join('/')}';
        labelTop = '今日课程已结束';
      } else {
        labelTop = '今日完成';
        labelMain = '好好休息';
        labelSub = '明天继续加油 ✨';
      }
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

  /// 构建待办事项区域（今日无课程时显示）
  Widget _buildTodoSection(BuildContext context, bool isDark, int nowMinutes) {
    final theme = Theme.of(context);
    
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, _) {
        final todos = todoProvider.todos;
        
        // 获取未完成且未过期的待办
        final pendingTodos = todos.where((t) => !t.isDone).toList();
        
        // 按优先级排序（priority: 0=普通, 1=重要, 2=紧急）
        pendingTodos.sort((a, b) => b.priority.compareTo(a.priority));
        
        final displayTodos = pendingTodos.take(5).toList();
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 待办标题
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.checklist_rounded, size: 16, color: AppTheme.accentOrange),
                          const SizedBox(width: 6),
                          Text(
                            '今日待办',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${pendingTodos.length} 项待处理',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              
              // 空状态
              if (displayTodos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.self_improvement_rounded,
                          size: 48,
                          color: AppTheme.accentTeal.withOpacity(0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '今日没有课程',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '待办清单也是空的，好好休息吧 ✨',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                // 待办列表
                ...displayTodos.map((todo) => _buildTodoTile(context, isDark, todo)),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个待办事项卡片
  Widget _buildTodoTile(BuildContext context, bool isDark, TodoItem todo) {
    final theme = Theme.of(context);
    
    // priority: 0=普通, 1=重要, 2=紧急
    Color priorityColor;
    String priorityLabel;
    switch (todo.priority) {
      case 2:
        priorityColor = Colors.red;
        priorityLabel = '紧急';
        break;
      case 1:
        priorityColor = AppTheme.accentOrange;
        priorityLabel = '重要';
        break;
      default:
        priorityColor = AppTheme.accentTeal;
        priorityLabel = '一般';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // 优先级圆点
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: priorityColor,
              boxShadow: [
                BoxShadow(
                  color: priorityColor.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          
          // 待办内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: todo.isDone ? TextDecoration.lineThrough : null,
                    color: todo.isDone 
                      ? theme.textTheme.bodySmall?.color 
                      : theme.textTheme.bodyLarge?.color,
                  ),
                ),
                if (todo.note != null && todo.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      todo.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          
          // 优先级标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              priorityLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: priorityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建课程列表区域
  Widget _buildCourseSection(
    BuildContext context, 
    bool isDark, 
    List<ClassPeriod> periods, 
    int todayWeekday,
    int nowMinutes,
    int passedCount,
  ) {
    final theme = Theme.of(context);
    final courseProvider = context.watch<CourseProvider>();
    final todayCourseCount = periods.where((period) {
      final course = courseProvider.getEntry(todayWeekday, period.index);
      return course != null && course.courseName.isNotEmpty;
    }).length;
    
    // 计算当前/下一节课
    ClassPeriod? nextPeriod;
    for (final period in periods) {
      final course = courseProvider.getEntry(todayWeekday, period.index);
      final hasCourse = course != null && course.courseName.isNotEmpty;
      if (!hasCourse) continue;
      
      final startMin = period.startHour * 60 + period.startMinute;
      if (nowMinutes < startMin) {
        nextPeriod = period;
        break;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 课程标题
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
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
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '有课 $todayCourseCount 节',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 课程列表（只显示有课的节次）
          ...periods.where((period) {
            final course = courseProvider.getEntry(todayWeekday, period.index);
            return course != null && course.courseName.isNotEmpty;
          }).map((period) {
            final startMin = period.startHour * 60 + period.startMinute;
            final endMin = period.endHour * 60 + period.endMinute;
            final course = courseProvider.getEntry(todayWeekday, period.index)!;
            
            final isActive = nowMinutes >= startMin && nowMinutes < endMin;
            final isPast = nowMinutes >= endMin;
            final isNext = !isActive && !isPast && nextPeriod?.index == period.index;

            return _buildPeriodTile(
              context, isDark, period, isActive, isPast, isNext, nowMinutes, course,
            );
          }),
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
          // 进度条主体 - 使用 LayoutBuilder 获取实际宽度
          LayoutBuilder(
            builder: (context, constraints) {
              final progressBarWidth = constraints.maxWidth;
              final dotOffset = progress.clamp(0.0, 1.0) * progressBarWidth - 5;
              
              return Stack(
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
                  
                  // 进度光点 - 使用计算的精确位置
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (context, child) {
                      return Positioned(
                        left: dotOffset.clamp(0.0, progressBarWidth - 10),
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
              );
            },
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
