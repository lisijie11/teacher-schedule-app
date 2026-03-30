// 任务模型

/// 任务状态枚举
enum TaskStatus {
  pending,    // 待处理
  inProgress, // 进行中
  completed,  // 已完成
  cancelled,  // 已取消
}

/// 任务优先级枚举
enum TaskPriority {
  low,      // 低
  medium,   // 中
  high,     // 高
  urgent,   // 紧急
}

/// 任务类型枚举
enum TaskType {
  teaching,     // 教学相关
  research,     // 科研相关
  meeting,      // 会议
  administration, // 行政事务
  other,        // 其他
}

/// 任务模型
class Task {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final TaskType type;
  final String teacherId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? courseId; // 关联课程ID（如果是教学相关任务）
  final List<String> tags;
  final Map<String, dynamic>? metadata; // 扩展元数据

  Task({
    required this.id,
    required this.title,
    this.description,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    this.type = TaskType.other,
    required this.teacherId,
    required this.createdBy,
    DateTime? createdAt,
    this.dueDate,
    this.completedAt,
    this.courseId,
    this.tags = const [],
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从JSON创建Task对象
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.values[(json['status'] as int? ?? 0)],
      priority: TaskPriority.values[(json['priority'] as int? ?? 1)],
      type: TaskType.values[(json['type'] as int? ?? TaskType.other.index)],
      teacherId: json['teacherId'] as String,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      courseId: json['courseId'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'status': status.index,
      'priority': priority.index,
      'type': type.index,
      'teacherId': teacherId,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (courseId != null) 'courseId': courseId,
      'tags': tags,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// 检查任务是否已过期
  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == TaskStatus.completed || status == TaskStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(dueDate!);
  }

  /// 检查任务是否今天到期
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  /// 获取任务剩余天数
  int? get remainingDays {
    if (dueDate == null) return null;
    final diff = dueDate!.difference(DateTime.now());
    return diff.inDays;
  }

  /// 获取状态显示文本
  String get statusText {
    return switch (status) {
      TaskStatus.pending => '待处理',
      TaskStatus.inProgress => '进行中',
      TaskStatus.completed => '已完成',
      TaskStatus.cancelled => '已取消',
    };
  }

  /// 获取优先级显示文本
  String get priorityText {
    return switch (priority) {
      TaskPriority.low => '低',
      TaskPriority.medium => '中',
      TaskPriority.high => '高',
      TaskPriority.urgent => '紧急',
    };
  }

  /// 获取类型显示文本
  String get typeText {
    return switch (type) {
      TaskType.teaching => '教学',
      TaskType.research => '科研',
      TaskType.meeting => '会议',
      TaskType.administration => '行政',
      TaskType.other => '其他',
    };
  }

  /// 获取优先级颜色代码
  int get priorityColor {
    return switch (priority) {
      TaskPriority.low => 0xFF4CAF50, // 绿色
      TaskPriority.medium => 0xFF2196F3, // 蓝色
      TaskPriority.high => 0xFFFF9800, // 橙色
      TaskPriority.urgent => 0xFFF44336, // 红色
    };
  }

  /// 创建新任务副本并更新状态
  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    TaskType? type,
    String? teacherId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? completedAt,
    String? courseId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      teacherId: teacherId ?? this.teacherId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      courseId: courseId ?? this.courseId,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, status: $status, dueDate: $dueDate)';
  }
}