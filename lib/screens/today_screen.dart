import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../services/holiday_service.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  late DateTime _now;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeekday = HolidayService.instance.getTodayIsWeekday();
    final dayType = HolidayService.instance.getDayType(_now);
    final holidayNote = HolidayService.instance.getHolidayNote(_now);
    final mode = isWeekday ? ScheduleMode.weekday : ScheduleMode.weekend;
    final periods = SchedulePresets.getPeriodsForMode(mode);
    final modeLabel = SchedulePresets.getModeLabel(mode);

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

    // 今日完成进度
    final passedCount = periods.where((p) {
      final endMin = p.endHour * 60 + p.endMinute;
      return nowMinutes >= endMin;
    }).length;
    final progress = periods.isEmpty ? 0.0 : passedCount / periods.length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(
              context, isDark, dayType, holidayNote, modeLabel,
              passedCount, periods.length, progress),
        ),
        SliverToBoxAdapter(
          child: _buildStatusCard(
              context, isDark, currentPeriod, nextPeriod, minutesToNext),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Text(
                  '今日课程',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF333355),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '共${periods.length}节',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.primaryDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final period = periods[index];
                final startMin =
                    period.startHour * 60 + period.startMinute;
                final endMin = period.endHour * 60 + period.endMinute;
                final isActive =
                    nowMinutes >= startMin && nowMinutes < endMin;
                final isPast = nowMinutes >= endMin;
                final isNext =
                    !isActive && !isPast && nextPeriod?.index == period.index;
                // 读取用户填写的课程信息
                final courseProvider = context.watch<CourseProvider>();
                final course =
                    courseProvider.getEntry(isWeekday, period.index);

                return _buildPeriodTile(
                    context, isDark, period, isActive, isPast, isNext,
                    nowMinutes, course);
              },
              childCount: periods.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
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
    final weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateStr = '${_now.month}月${_now.day}日  ${weekdays[_now.weekday]}';
    final timeStr = DateFormat('HH:mm').format(_now);

    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;
    if (dayType == DayType.holiday) {
      badgeColor = const Color(0xFF07C160);
      badgeIcon = Icons.celebration_rounded;
      badgeLabel = holidayNote ?? '假日';
    } else if (dayType == DayType.workday && _now.weekday > 5) {
      badgeColor = AppTheme.accentOrange;
      badgeIcon = Icons.work_outline_rounded;
      badgeLabel = '调休上班';
    } else if (_now.weekday <= 5) {
      badgeColor = AppTheme.primaryDark;
      badgeIcon = Icons.school_rounded;
      badgeLabel = '工作日';
    } else {
      badgeColor = AppTheme.accentTeal;
      badgeIcon = Icons.weekend_rounded;
      badgeLabel = '休息日';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0C0D1A), const Color(0xFF14152B)]
              : [const Color(0xFFF0F2FF), const Color(0xFFFFFFFF)],
        ),
      ),
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
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1B30),
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withOpacity(0.54) : Colors.black.withOpacity(0.38),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.12)
                          : AppTheme.primaryDark.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? AppTheme.accentTeal
                              : AppTheme.primaryDark),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$passedCount / $totalCount 节',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.38),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
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
    final bool isFinished = current == null && next == null;

    Color accentColor;
    IconData accentIcon;
    String labelTop;
    String labelMain;
    String labelSub;

    if (current != null) {
      accentColor = const Color(0xFF07C160);
      accentIcon = Icons.play_circle_filled_rounded;
      labelTop = '● 上课中';
      labelMain = current.name;
      labelSub = '${current.startTime} — ${current.endTime}';
    } else if (next != null) {
      accentColor = AppTheme.primaryDark;
      accentIcon = Icons.schedule_rounded;
      labelTop = '下节课';
      labelMain = next.name;
      labelSub = '$minutesToNext 分钟后 · ${next.startTime}';
    } else {
      accentColor = AppTheme.accentTeal;
      accentIcon = Icons.check_circle_rounded;
      labelTop = '今日完成';
      labelMain = '好好休息';
      labelSub = '明日继续加油 ✨';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.08 : 0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 图标 + 左侧装饰条
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: current != null
                ? FadeTransition(
                    opacity: Tween<double>(begin: 0.5, end: 1.0)
                        .animate(_pulseCtrl),
                    child: Icon(accentIcon, color: accentColor, size: 24),
                  )
                : Icon(accentIcon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelTop,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  labelMain,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1B30),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  labelSub,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.38),
                  ),
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
    Color dotColor;
    Color cardBg;
    Color borderColor;
    Color titleColor;
    Color timeColor;

    if (isActive) {
      dotColor = const Color(0xFF07C160);
      cardBg = const Color(0xFF07C160).withOpacity(isDark ? 0.08 : 0.05);
      borderColor = const Color(0xFF07C160).withOpacity(0.3);
      titleColor = isDark ? Colors.white : const Color(0xFF1A1B30);
      timeColor = const Color(0xFF07C160);
    } else if (isPast) {
      dotColor = isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12);
      cardBg = isDark ? AppTheme.darkCard.withOpacity(0.5) : Colors.white;
      borderColor = isDark
          ? AppTheme.darkBorder.withOpacity(0.5)
          : AppTheme.lightBorder.withOpacity(0.5);
      titleColor = isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.26);
      timeColor = isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.20);
    } else if (isNext) {
      dotColor = AppTheme.primaryDark;
      cardBg = AppTheme.primaryDark.withOpacity(isDark ? 0.12 : 0.06);
      borderColor = AppTheme.primaryDark.withOpacity(0.3);
      titleColor = isDark ? Colors.white : const Color(0xFF1A1B30);
      timeColor = AppTheme.primaryDark;
    } else {
      dotColor = AppTheme.primaryDark.withOpacity(0.5);
      cardBg = isDark ? AppTheme.darkCard : Colors.white;
      borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
      titleColor = isDark ? const Color(0xFFCCD0FF) : const Color(0xFF2A2B40);
      timeColor = isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.38);
    }

    // 计算课程内进度（上课中时显示）
    double? inClassProgress;
    if (isActive) {
      final startMin = period.startHour * 60 + period.startMinute;
      final endMin = period.endHour * 60 + period.endMinute;
      inClassProgress = (nowMinutes - startMin) / (endMin - startMin);
      inClassProgress = inClassProgress.clamp(0.0, 1.0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // 节次圆点
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: dotColor.withOpacity(isActive || isNext ? 0.15 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${period.index}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: dotColor,
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
                        // 优先显示用户填写的课程名，否则显示节次名
                        (course != null && course.courseName.isNotEmpty)
                            ? course.courseName
                            : period.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isActive || isNext ? FontWeight.w600 : FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      // 有教室信息时显示
                      if (course != null && course.classroom.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '📍 ${course.classroom}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.38),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${period.startTime} - ${period.endTime}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: timeColor,
                  ),
                ),
                if (isPast) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_outline_rounded,
                      size: 15,
                      color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.20)),
                ],
              ],
            ),
          ),
          // 课内进度条（仅上课中显示）
          if (inClassProgress != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: LinearProgressIndicator(
                value: inClassProgress,
                backgroundColor: const Color(0xFF07C160).withOpacity(0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF07C160)),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}
