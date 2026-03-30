import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../models/course_model.dart';
import '../services/holiday_service.dart';

class TodayScreen extends StatefulWidget {
  final String? facultyName;

  const TodayScreen({super.key, this.facultyName});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  late DateTime _now;
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    
    // 创建卡片交错动画
    _cardAnimations = List.generate(4, (index) => 
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(
            0.1 + index * 0.15,
            0.5 + index * 0.15,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryCtrl.forward();
    });

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
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
          child: AnimatedBuilder(
            animation: _cardAnimations[0],
            builder: (context, child) {
              final animation = _cardAnimations[0];
              return Transform.translate(
                offset: Offset(0, (1 - animation.value) * 25),
                child: Opacity(
                  opacity: animation.value,
                  child: Transform.scale(
                    scale: 0.96 + animation.value * 0.04,
                    child: child,
                  ),
                ),
              );
            },
            child: _buildWelcomeCard(context, isDark),
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _cardAnimations[1],
            builder: (context, child) {
              final animation = _cardAnimations[1];
              return Transform.translate(
                offset: Offset(0, (1 - animation.value) * 25),
                child: Opacity(
                  opacity: animation.value,
                  child: Transform.scale(
                    scale: 0.96 + animation.value * 0.04,
                    child: child,
                  ),
                ),
              );
            },
            child: _buildHeader(
                context, isDark, dayType, holidayNote, modeLabel,
                passedCount, periods.length, progress),
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _cardAnimations[0],
            builder: (context, child) {
              final animation = _cardAnimations[0];
              return Transform.translate(
                offset: Offset(0, (1 - animation.value) * 30),
                child: Opacity(
                  opacity: animation.value,
                  child: Transform.scale(
                    scale: 0.95 + animation.value * 0.05,
                    child: child,
                  ),
                ),
              );
            },
            child: _buildStatusCard(
                context, isDark, currentPeriod, nextPeriod, minutesToNext),
          ),
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

                return AnimatedBuilder(
                  animation: _cardAnimations[index % _cardAnimations.length],
                  builder: (context, child) {
                    final animation = _cardAnimations[index % _cardAnimations.length];
                    return Transform.translate(
                      offset: Offset(0, (1 - animation.value) * 30),
                      child: Opacity(
                        opacity: animation.value,
                        child: Transform.scale(
                          scale: 0.95 + animation.value * 0.05,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _buildPeriodTile(
                      context, isDark, period, isActive, isPast, isNext,
                      nowMinutes, course),
                );
              },
              childCount: periods.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context, bool isDark) {
    final facultyName = widget.facultyName ?? '广东东软学院';
    final nowHour = _now.hour;
    String greeting;
    
    if (nowHour < 6) {
      greeting = '黎明拂晓，精神饱满';
    } else if (nowHour < 12) {
      greeting = '早上好，李老师';
    } else if (nowHour < 14) {
      greeting = '中午好，午间时光';
    } else if (nowHour < 18) {
      greeting = '下午好，继续努力';
    } else if (nowHour < 22) {
      greeting = '晚上好，辛勤付出';
    } else {
      greeting = '夜深了，注意休息';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A2DC2).withOpacity(isDark ? 0.3 : 0.2),
            const Color(0xFF6A4BF2).withOpacity(isDark ? 0.25 : 0.15),
            const Color(0xFF8A6DF2).withOpacity(isDark ? 0.2 : 0.1),
          ],
        ),
        border: Border.all(
          color: Colors.deepPurple.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A2DC2).withOpacity(isDark ? 0.2 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.school,
              color: Colors.white.withOpacity(0.9),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  facultyName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.8,
              ),
            ),
            child: Text(
              '教师端',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
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

    // 增强的阴影效果
    List<BoxShadow> cardShadows = [
      BoxShadow(
        color: accentColor.withOpacity(isDark ? 0.15 : 0.12),
        blurRadius: 24,
        offset: const Offset(0, 6),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: accentColor.withOpacity(isDark ? 0.08 : 0.05),
        blurRadius: 40,
        offset: const Offset(0, 12),
        spreadRadius: -8,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.2),
        boxShadow: cardShadows,
      ),
      child: Row(
        children: [
          // 图标 + 左侧装饰条（升级版）
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.18),
                  accentColor.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.25),
                width: 1.2,
              ),
            ),
            child: current != null
                ? FadeTransition(
                    opacity: Tween<double>(begin: 0.5, end: 1.0)
                        .animate(CurvedAnimation(
                          parent: _pulseCtrl,
                          curve: Curves.easeInOut,
                        )),
                    child: Icon(accentIcon, color: accentColor, size: 26),
                  )
                : Icon(accentIcon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelTop,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labelMain,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1B30),
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  labelSub,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white.withOpacity(0.50) : Colors.black.withOpacity(0.42),
                    letterSpacing: -0.1,
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
      cardBg = isDark
          ? const Color(0xFF0D5F44).withOpacity(0.12)
          : const Color(0xFF07C160).withOpacity(0.05);
      borderColor = const Color(0xFF07C160).withOpacity(0.35);
      titleColor = isDark ? Colors.white : const Color(0xFF1A1B30);
      timeColor = const Color(0xFF07C160);
    } else if (isPast) {
      dotColor = isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12);
      cardBg = isDark
          ? AppTheme.darkCard.withOpacity(0.5)
          : Colors.white;
      borderColor = isDark
          ? AppTheme.darkBorder.withOpacity(0.4)
          : AppTheme.lightBorder.withOpacity(0.5);
      titleColor = isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.26);
      timeColor = isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.20);
    } else if (isNext) {
      dotColor = AppTheme.primaryDark;
      cardBg = isDark
          ? AppTheme.primaryDark.withOpacity(0.15)
          : AppTheme.primaryLight.withOpacity(0.08);
      borderColor = AppTheme.primaryDark.withOpacity(0.35);
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

    // 阴影效果（仅对活跃卡片）
    List<BoxShadow>? cardShadows;
    if (isActive || isNext) {
      cardShadows = [
        BoxShadow(
          color: dotColor.withOpacity(isDark ? 0.15 : 0.12),
          blurRadius: 20,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: dotColor.withOpacity(isDark ? 0.08 : 0.05),
          blurRadius: 40,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isActive ? 1.3 : 1.0),
        boxShadow: cardShadows,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // 节次圆点（升级版）
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: isActive || isNext
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              dotColor.withOpacity(0.2),
                              dotColor.withOpacity(0.1),
                            ],
                          )
                        : null,
                    color: dotColor.withOpacity(isActive || isNext ? 0.12 : 0.08),
                    shape: BoxShape.circle,
                    border: isActive || isNext
                        ? Border.all(color: dotColor.withOpacity(0.4), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${period.index}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: dotColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                          fontSize: 16,
                          fontWeight:
                              isActive || isNext ? FontWeight.w700 : FontWeight.w600,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      // 有教室信息时显示
                      if (course != null && course.classroom.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '📍 ${course.classroom}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white.withOpacity(0.42)
                                  : Colors.black.withOpacity(0.38),
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
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: timeColor,
                    letterSpacing: -0.1,
                  ),
                ),
                if (isPast) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: isDark
                          ? Colors.white.withOpacity(0.30)
                          : Colors.black.withOpacity(0.26),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 课内进度条（仅上课中显示）
          if (inClassProgress != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(17),
                bottomRight: Radius.circular(17),
              ),
              child: LinearProgressIndicator(
                value: inClassProgress,
                backgroundColor: const Color(0xFF07C160).withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF07C160)),
                minHeight: 3.5,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
