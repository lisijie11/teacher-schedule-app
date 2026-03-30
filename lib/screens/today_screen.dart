import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../theme.dart';
import '../models/schedule_model.dart';
import '../services/holiday_service.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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

    // 计算当前/下节课
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

    return CustomScrollView(
      slivers: [
        // 顶部大标题区
        SliverToBoxAdapter(
          child: _buildHeader(context, isDark, dayType, holidayNote, modeLabel),
        ),

        // 当前状态卡片
        SliverToBoxAdapter(
          child: _buildStatusCard(
              context, isDark, currentPeriod, nextPeriod, minutesToNext),
        ),

        // 今日时间轴
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              '今日课程安排',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final period = periods[index];
              final startMin = period.startHour * 60 + period.startMinute;
              final endMin = period.endHour * 60 + period.endMinute;
              final isActive = nowMinutes >= startMin && nowMinutes < endMin;
              final isPast = nowMinutes >= endMin;

              return _buildPeriodTile(
                  context, isDark, period, isActive, isPast);
            },
            childCount: periods.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, DayType dayType,
      String? holidayNote, String modeLabel) {
    final weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateStr =
        '${_now.month}月${_now.day}日 ${weekdays[_now.weekday]}';
    final timeStr = DateFormat('HH:mm').format(_now);

    Color modeColor;
    IconData modeIcon;
    if (dayType == DayType.holiday) {
      modeColor = Colors.green;
      modeIcon = Icons.celebration;
    } else if (dayType == DayType.workday && _now.weekday > 5) {
      modeColor = Colors.orange;
      modeIcon = Icons.work;
    } else if (_now.weekday <= 5) {
      modeColor = AppTheme.primaryDark;
      modeIcon = Icons.school;
    } else {
      modeColor = Colors.teal;
      modeIcon = Icons.weekend;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppTheme.darkBg0, AppTheme.darkBg2]
              : [const Color(0xFFEEF0FF), Colors.white],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.darkBg0,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: modeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: modeColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(modeIcon, color: modeColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      holidayNote ?? modeLabel.split('（').first,
                      style: TextStyle(
                        color: modeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, bool isDark,
      ClassPeriod? current, ClassPeriod? next, int? minutesToNext) {
    final bg = isDark ? AppTheme.darkCard : Colors.white;

    Widget content;
    if (current != null) {
      // 上课中
      content = Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '上课中',
                  style: TextStyle(
                      fontSize: 12, color: Colors.greenAccent),
                ),
                Text(
                  current.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            '${current.startTime} - ${current.endTime}',
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black45),
          ),
        ],
      );
    } else if (next != null) {
      // 下节课
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.access_time,
                color: AppTheme.primaryDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下节课 · $minutesToNext 分钟后',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.primaryDark),
                ),
                Text(
                  next.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            next.startTime,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark),
          ),
        ],
      );
    } else {
      // 今日结束
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.check_circle, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日课程已全部结束',
                    style: TextStyle(fontSize: 12, color: Colors.teal)),
                Text('好好休息 🌙',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildPeriodTile(BuildContext context, bool isDark, ClassPeriod period,
      bool isActive, bool isPast) {
    final Color dotColor = isActive
        ? Colors.greenAccent
        : isPast
            ? (isDark ? Colors.white24 : Colors.black12)
            : AppTheme.primaryDark;

    final Color textColor = isPast
        ? (isDark ? Colors.white38 : Colors.black26)
        : (isDark ? Colors.white : Colors.black87);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryDark.withOpacity(0.15)
            : isDark
                ? AppTheme.darkCard
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: AppTheme.primaryDark.withOpacity(0.4))
            : Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              period.name,
              style: TextStyle(
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: textColor,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            '${period.startTime} - ${period.endTime}',
            style: TextStyle(
              color: isActive
                  ? AppTheme.primaryDark
                  : (isDark ? Colors.white54 : Colors.black38),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
