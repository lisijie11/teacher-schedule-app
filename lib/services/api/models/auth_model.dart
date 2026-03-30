// 认证相关模型

/// 登录请求
class LoginRequest {
  final String username;
  final String password;
  final String userType; // 'teacher' 或 'student'

  LoginRequest({
    required this.username,
    required this.password,
    this.userType = 'teacher',
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'userType': userType,
    };
  }

  @override
  String toString() {
    return 'LoginRequest(username: $username, userType: $userType)';
  }
}

/// 登录响应
class LoginResponse {
  final String token;
  final String userId;
  final String userRole;
  final String username;
  final DateTime expiresAt;
  final List<String>? permissions;

  LoginResponse({
    required this.token,
    required this.userId,
    required this.userRole,
    required this.username,
    required this.expiresAt,
    this.permissions,
  });

  /// 从JSON创建LoginResponse对象
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      userId: json['userId'] as String,
      userRole: json['userRole'] as String? ?? 'teacher',
      username: json['username'] as String? ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : DateTime.now().add(const Duration(hours: 2)),
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'] as List)
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userId': userId,
      'userRole': userRole,
      'username': username,
      'expiresAt': expiresAt.toIso8601String(),
      if (permissions != null) 'permissions': permissions,
    };
  }

  /// 检查token是否过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 获取剩余有效期（分钟）
  int get remainingMinutes => expiresAt.difference(DateTime.now()).inMinutes;

  /// 获取用户显示名称
  String get displayName {
    final roleMap = {
      'teacher': '教师',
      'student': '学生',
      'admin': '管理员',
    };
    final roleName = roleMap[userRole] ?? userRole;
    return '$username ($roleName)';
  }

  @override
  String toString() {
    return 'LoginResponse(userId: $userId, username: $username, expiresAt: $expiresAt)';
  }
}

/// 用户信息
class UserProfile {
  final String userId;
  final String username;
  final String realName;
  final String? avatarUrl;
  final String department;
  final String? phoneNumber;
  final String? email;
  final DateTime? lastLoginAt;
  final List<String> roles;

  UserProfile({
    required this.userId,
    required this.username,
    required this.realName,
    this.avatarUrl,
    required this.department,
    this.phoneNumber,
    this.email,
    this.lastLoginAt,
    this.roles = const [],
  });

  /// 从JSON创建UserProfile对象
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      username: json['username'] as String,
      realName: json['realName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      department: json['department'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      roles: json['roles'] != null
          ? List<String>.from(json['roles'] as List)
          : [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'realName': realName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'department': department,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (email != null) 'email': email,
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      'roles': roles,
    };
  }

  /// 获取简化的显示信息
  Map<String, String> get summary {
    return {
      '姓名': realName,
      '工号': userId,
      '部门': department,
      if (email != null) '邮箱': email!,
    };
  }

  /// 是否包含特定角色
  bool hasRole(String role) => roles.contains(role);

  /// 是否是教师
  bool get isTeacher => hasRole('teacher') || hasRole('teacher_admin');

  /// 是否是管理员
  bool get isAdmin => hasRole('admin');

  @override
  String toString() {
    return 'UserProfile(userId: $userId, realName: $realName, department: $department)';
  }
}