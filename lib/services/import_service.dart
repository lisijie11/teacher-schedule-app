import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/course_model.dart';
import '../models/schedule_model.dart';

/// 课表导入导出服务
/// 支持：
/// 1. 从剪贴板导入（超级课表 JSON 格式）
/// 2. 导出备份并通过系统分享
/// 3. 导出到 Downloads 目录（Android）
class ImportService {
  
  /// 从剪贴板导入课表
  static Future<int> importFromClipboard(CourseProvider courseProvider) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      
      if (text == null || text.isEmpty) {
        return -2; // 剪贴板为空
      }
      
      return await importFromJson(text, courseProvider);
    } catch (e) {
      debugPrint('从剪贴板导入失败: $e');
      return -1;
    }
  }

  /// 导出完整备份并通过系统分享（包含课程、作息、提醒、设置）
  static Future<bool> exportAndShare(CourseProvider courseProvider) async {
    try {
      final courses = courseProvider.all;
      
      if (courses.isEmpty) {
        return false;
      }

      // 构建完整的导出数据
      final exportData = {
        'app': 'teacher_schedule_backup',
        'version': '2.0',  // 升级版本号
        'exportTime': DateTime.now().toIso8601String(),
        // 课程数据
        'courses': courses.map((c) => {
          'id': c.id,
          'weekday': c.weekday,
          'periodIndex': c.periodIndex,
          'courseName': c.courseName,
          'classroom': c.classroom,
          'note': c.note,
          'colorIndex': c.colorIndex,
          'weekTypeIndex': c.weekTypeIndex,
          'customWeeks': c.customWeeks,
        }).toList(),
        // 作息时间数据
        'schedule': {
          'weekdayPeriods': SchedulePresets.weekdayPeriods.map((p) => {
            'index': p.index,
            'name': p.name,
            'startHour': p.startHour,
            'startMinute': p.startMinute,
            'endHour': p.endHour,
            'endMinute': p.endMinute,
          }).toList(),
          'weekendPeriods': SchedulePresets.weekendPeriods.map((p) => {
            'index': p.index,
            'name': p.name,
            'startHour': p.startHour,
            'startMinute': p.startMinute,
            'endHour': p.endHour,
            'endMinute': p.endMinute,
          }).toList(),
        },
        // 提醒数据
        'reminders': ScheduleProvider().reminders.map((r) => {
          'id': r.id,
          'title': r.title,
          'hour': r.hour,
          'minute': r.minute,
          'weekday': r.weekday,
          'isEnabled': r.isEnabled,
          'advanceMinutes': r.advanceMinutes,
        }).toList(),
        // 用户设置数据
        'settings': {
          'semesterStartDate': _getSettings('semesterStartDate'),
          'totalWeeks': _getSettings('totalWeeks'),
          'userName': _getSettings('userName'),
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 保存到临时目录
      final directory = await getTemporaryDirectory();
      final fileName = '教师课表完整备份_${_formatDateTime()}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      debugPrint('完整备份已导出到: ${file.path}');

      // 使用系统分享
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '教师课表助手 - 完整备份',
        text: '包含课程、作息时间、自定义提醒等全部数据',
      );

      return true;
    } catch (e) {
      debugPrint('导出分享失败: $e');
      return false;
    }
  }

  /// 获取设置数据
  static dynamic _getSettings(String key) {
    try {
      final box = Hive.box('settings');
      return box.get(key);
    } catch (e) {
      return null;
    }
  }

  /// 导出课表到文本（方便用户复制）
  static Future<String?> exportToClipboard(CourseProvider courseProvider) async {
    try {
      final courses = courseProvider.all;
      
      if (courses.isEmpty) {
        return null;
      }

      final exportData = {
        'app': 'teacher_schedule_backup',
        'version': '2.0',
        'exportTime': DateTime.now().toIso8601String(),
        'courses': courses.map((c) => {
          'id': c.id,
          'weekday': c.weekday,
          'periodIndex': c.periodIndex,
          'courseName': c.courseName,
          'classroom': c.classroom,
          'note': c.note,
          'colorIndex': c.colorIndex,
          'weekTypeIndex': c.weekTypeIndex,
          'customWeeks': c.customWeeks,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // 复制到剪贴板
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      return jsonString;
    } catch (e) {
      debugPrint('导出到剪贴板失败: $e');
      return null;
    }
  }

  /// 从 JSON 字符串导入课表
  static Future<int> importFromJson(
    String jsonString,
    CourseProvider courseProvider,
  ) async {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // 检查是否是本应用备份格式
      if (data['app'] == 'teacher_schedule_backup') {
        return await _importFromBackup(data, courseProvider);
      }

      // 检查是否是超级课表格式
      final app = data['app'] as String?;
      if (app != 'mikcb') {
        debugPrint('不是支持的课表格式');
        return -1;
      }

      // 获取课程列表
      List<Map<String, dynamic>> courses = [];
      
      if (data.containsKey('courses')) {
        final rootCourses = data['courses'] as List<dynamic>?;
        if (rootCourses != null) {
          courses = rootCourses.cast<Map<String, dynamic>>();
        }
      } else if (data.containsKey('profiles')) {
        final profiles = data['profiles'] as List<dynamic>?;
        if (profiles != null && profiles.isNotEmpty) {
          final activeProfile = profiles.first as Map<String, dynamic>;
          final profileCourses = activeProfile['courses'] as List<dynamic>?;
          if (profileCourses != null) {
            courses = profileCourses.cast<Map<String, dynamic>>();
          }
        }
      }

      if (courses.isEmpty) {
        debugPrint('没有找到课程数据');
        return 0;
      }

      // 转换并保存课程
      int importedCount = 0;
      for (final course in courses) {
        final converted = _convertMikcbCourse(course);
        if (converted != null) {
          await courseProvider.save(converted);
          importedCount++;
        }
      }

      debugPrint('成功导入 $importedCount 门课程');
      return importedCount;
    } catch (e) {
      debugPrint('导入失败: $e');
      return -1;
    }
  }

  /// 从本应用备份格式导入（v2.0 完整导入）
  static Future<int> _importFromBackup(
    Map<String, dynamic> data,
    CourseProvider courseProvider,
  ) async {
    int importedCount = 0;
    
    // 导入课程数据
    final courses = data['courses'] as List<dynamic>?;
    if (courses != null && courses.isNotEmpty) {
      for (final course in courses) {
        try {
          final entry = CourseEntry(
            id: course['id'] as String,
            weekday: course['weekday'] as int,
            periodIndex: course['periodIndex'] as int,
            courseName: course['courseName'] as String,
            classroom: course['classroom'] as String? ?? '',
            note: course['note'] as String?,
            colorIndex: course['colorIndex'] as int? ?? 0,
            weekTypeIndex: course['weekTypeIndex'] as int? ?? 0,
            customWeeks: course['customWeeks'] != null 
                ? (course['customWeeks'] as List).cast<int>() 
                : null,
          );
          await courseProvider.save(entry);
          importedCount++;
        } catch (e) {
          debugPrint('导入备份课程失败: $e');
        }
      }
    }
    
    // 导入作息时间数据
    final schedule = data['schedule'] as Map<String, dynamic>?;
    if (schedule != null) {
      try {
        final weekdayPeriods = (schedule['weekdayPeriods'] as List?)
            ?.map((p) => ClassPeriod(
              index: p['index'] as int,
              name: p['name'] as String,
              startHour: p['startHour'] as int,
              startMinute: p['startMinute'] as int,
              endHour: p['endHour'] as int,
              endMinute: p['endMinute'] as int,
            ))
            .toList();
        
        final weekendPeriods = (schedule['weekendPeriods'] as List?)
            ?.map((p) => ClassPeriod(
              index: p['index'] as int,
              name: p['name'] as String,
              startHour: p['startHour'] as int,
              startMinute: p['startMinute'] as int,
              endHour: p['endHour'] as int,
              endMinute: p['endMinute'] as int,
            ))
            .toList();
        
        if (weekdayPeriods != null || weekendPeriods != null) {
          await SchedulePresets.saveCustomSchedule(
            weekday: weekdayPeriods,
            weekend: weekendPeriods,
          );
          debugPrint('作息时间已导入');
        }
      } catch (e) {
        debugPrint('导入作息时间失败: $e');
      }
    }
    
    // 导入提醒数据
    final reminders = data['reminders'] as List<dynamic>?;
    if (reminders != null && reminders.isNotEmpty) {
      try {
        final scheduleProvider = ScheduleProvider();
        for (final r in reminders) {
          final reminder = ReminderItem(
            id: r['id'] as String,
            title: r['title'] as String,
            hour: r['hour'] as int,
            minute: r['minute'] as int,
            weekday: r['weekday'] as int,
            isEnabled: r['isEnabled'] as bool? ?? true,
            advanceMinutes: r['advanceMinutes'] as int? ?? 0,
          );
          scheduleProvider.addReminder(reminder);
        }
        debugPrint('提醒已导入 ${reminders.length} 条');
      } catch (e) {
        debugPrint('导入提醒失败: $e');
      }
    }
    
    // 导入设置数据
    final settings = data['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      try {
        final settingsBox = Hive.box('settings');
        if (settings['semesterStartDate'] != null) {
          await settingsBox.put('semesterStartDate', settings['semesterStartDate']);
        }
        if (settings['totalWeeks'] != null) {
          await settingsBox.put('totalWeeks', settings['totalWeeks']);
        }
        if (settings['userName'] != null) {
          await settingsBox.put('userName', settings['userName']);
        }
        debugPrint('设置已导入');
      } catch (e) {
        debugPrint('导入设置失败: $e');
      }
    }

    return importedCount;
  }

  /// 将 mikcb 课程转换为 CourseEntry
  static CourseEntry? _convertMikcbCourse(Map<String, dynamic> course) {
    try {
      final name = course['name'] as String? ?? '';
      if (name.isEmpty) return null;

      final dayOfWeek = course['dayOfWeek'] as int? ?? 1;
      final startSection = course['startSection'] as int? ?? 1;
      final endSection = course['endSection'] as int? ?? 1;
      final location = course['location'] as String? ?? '';
      final colorStr = course['color'] as String? ?? '#6C63FF';
      final colorIndex = _parseColorToIndex(colorStr);
      
      final shortName = course['shortName'] as String?;
      final teacher = course['teacher'] as String?;
      final note = shortName?.isNotEmpty == true 
          ? shortName 
          : (teacher?.isNotEmpty == true ? teacher : null);

      final id = course['id'] as String? ?? 
          '${dayOfWeek}_${startSection}_${name.hashCode}';

      // 映射节次到 4 大节
      int periodIndex;
      if (endSection <= 2) {
        periodIndex = 1;
      } else if (endSection <= 4) {
        periodIndex = 2;
      } else if (endSection <= 6) {
        periodIndex = 3;
      } else {
        periodIndex = 4;
      }

      return CourseEntry(
        id: id,
        weekday: dayOfWeek,
        periodIndex: periodIndex,
        courseName: name,
        classroom: location,
        note: note,
        colorIndex: colorIndex,
      );
    } catch (e) {
      debugPrint('转换课程失败: $e');
      return null;
    }
  }

  /// 解析颜色字符串为颜色索引
  static int _parseColorToIndex(String colorStr) {
    final hex = colorStr.replaceFirst('#', '').toUpperCase();
    
    const colorMap = {
      '2196F3': 1,
      '4CAF50': 2,
      'FF9800': 3,
      '9C27B0': 6,
      'FF5722': 4,
      'F44336': 4,
      '00BCD4': 5,
      'E91E63': 4,
      '3F51B5': 1,
      '673AB7': 6,
    };
    
    return colorMap[hex] ?? 0;
  }

  /// 格式化日期时间用于文件名
  static String _formatDateTime() {
    final now = DateTime.now();
    return '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_'
           '${_twoDigits(now.hour)}${_twoDigits(now.minute)}';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
