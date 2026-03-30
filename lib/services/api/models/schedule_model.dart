// API 课程模型（正方教务系统格式）
class Course {
  final String id;
  final String courseId; // 课程编号
  final String courseName; // 课程名称
  final String courseType; // 课程类型：必修/选修/通识等
  final String teacherId; // 教师ID
  final String teacherName; // 教师姓名
  final int semester; // 学期：1-1, 1-2, 2-1, 2-2 等
  final int weekDay; // 星期：1-星期一 7-星期日
  final int weekNum; // 教学周
  final int periodStart; // 节次起始
  final int periodEnd; // 节次结束
  final String building; // 教学楼
  final String classroom; // 教室
  final int credit; // 学分
  final int studentCount; // 选课人数
  final String? examDate; // 考试日期
  final String? examLocation; // 考试地点
  final String? remarks; // 备注

  Course({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseType,
    required this.teacherId,
    required this.teacherName,
    this.semester = 20262, // 默认2026学年第2学期
    required this.weekDay,
    required this.weekNum,
    required this.periodStart,
    required this.periodEnd,
    required this.building,
    required this.classroom,
    this.credit = 2,
    this.studentCount = 0,
    this.examDate,
    this.examLocation,
    this.remarks,
  });

  /// 从JSON创建Course对象
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      courseType: json['courseType'] as String? ?? '必修',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      semester: json['semester'] as int? ?? 20262,
      weekDay: json['weekDay'] as int? ?? 1,
      weekNum: json['weekNum'] as int? ?? 1,
      periodStart: json['periodStart'] as int? ?? 1,
      periodEnd: json['periodEnd'] as int? ?? 2,
      building: json['building'] as String? ?? '',
      classroom: json['classroom'] as String? ?? '',
      credit: json['credit'] as int? ?? 2,
      studentCount: json['studentCount'] as int? ?? 0,
      examDate: json['examDate'] as String?,
      examLocation: json['examLocation'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'courseName': courseName,
      'courseType': courseType,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'semester': semester,
      'weekDay': weekDay,
      'weekNum': weekNum,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
      'building': building,
      'classroom': classroom,
      'credit': credit,
      'studentCount': studentCount,
      if (examDate != null) 'examDate': examDate,
      if (examLocation != null) 'examLocation': examLocation,
      if (remarks != null) 'remarks': remarks,
    };
  }

  /// 获取时间字符串
  String get timeString {
    final periodMap = <int, String>{
      1: '08:30-09:15',
      2: '09:20-10:05',
      3: '10:25-11:10',
      4: '11:15-12:00',
      5: '14:00-14:45',
      6: '14:50-15:35',
      7: '15:55-16:40',
      8: '16:45-17:30',
      9: '19:00-19:45',
      10: '19:55-20:40',
    };

    if (periodStart == periodEnd) {
      return periodMap[periodStart] ?? '$periodStart节';
    }

    final start = periodMap[periodStart]?.split('-').first ?? '$periodStart';
    final end = periodMap[periodEnd]?.split('-').last ?? '$periodEnd';
    return '$start-$end';
  }

  /// 获取星期几中文显示
  String get weekDayString {
    const days = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return days[weekDay];
  }

  /// 获取地点全称（教学楼+教室）
  String get fullLocation {
    if (building.isEmpty && classroom.isEmpty) return '地点未定';
    if (classroom.isEmpty) return building;
    if (building.isEmpty) return classroom;
    return '$building-$classroom';
  }

  /// 获取学期显示（2026-2 转为 2026学年第2学期）
  String get semesterString {
    final year = semester ~/ 10;
    final term = semester % 10;
    return '${year}学年第$term学期';
  }

  @override
  String toString() {
    return '$courseName ($timeString, $fullLocation)';
  }
}