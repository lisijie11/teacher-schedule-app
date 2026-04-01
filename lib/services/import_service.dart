import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/course_model.dart';

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

  /// 导出课表备份并通过系统分享
  static Future<bool> exportAndShare(CourseProvider courseProvider) async {
    try {
      final courses = courseProvider.all;
      
      if (courses.isEmpty) {
        return false;
      }

      // 构建导出数据
      final exportData = {
        'app': 'teacher_schedule_backup',
        'version': '1.0',
        'exportTime': DateTime.now().toIso8601String(),
        'courses': courses.map((c) => {
          'id': c.id,
          'weekday': c.weekday,
          'periodIndex': c.periodIndex,
          'courseName': c.courseName,
          'classroom': c.classroom,
          'note': c.note,
          'colorIndex': c.colorIndex,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 保存到临时目录
      final directory = await getTemporaryDirectory();
      final fileName = '课表备份_${_formatDateTime()}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      debugPrint('课表已导出到: ${file.path}');

      // 使用系统分享
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '教师课表助手 - 课表备份',
        text: '这是我的课表备份文件，可以通过剪贴板导入恢复',
      );

      return true;
    } catch (e) {
      debugPrint('导出分享失败: $e');
      return false;
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
        'version': '1.0',
        'exportTime': DateTime.now().toIso8601String(),
        'courses': courses.map((c) => {
          'id': c.id,
          'weekday': c.weekday,
          'periodIndex': c.periodIndex,
          'courseName': c.courseName,
          'classroom': c.classroom,
          'note': c.note,
          'colorIndex': c.colorIndex,
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

  /// 从本应用备份格式导入
  static Future<int> _importFromBackup(
    Map<String, dynamic> data,
    CourseProvider courseProvider,
  ) async {
    final courses = data['courses'] as List<dynamic>?;
    if (courses == null || courses.isEmpty) {
      return 0;
    }

    int importedCount = 0;
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
        );
        await courseProvider.save(entry);
        importedCount++;
      } catch (e) {
        debugPrint('导入备份课程失败: $e');
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
