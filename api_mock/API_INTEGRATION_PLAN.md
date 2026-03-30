# 教师教务系统API对接方案

## 背景
思杰（李思杰老师）作为广东东软学院的教师，需要将手机应用与学校教务系统对接，实现课表同步、教学任务管理等功能。

## 调研结果

### 1. 现有教务系统情况
大多数中国高校使用以下教务系统：
- **正方教务管理系统**（最普遍）
- **强智科技教务系统**
- **青果教务系统**
- **学校自建系统**

### 2. API接入选择
基于调研，建议采用以下方案：

#### 方案A：使用开源API库（推荐）
- **项目**：zfn_api (新正方教务系统API) 
- **GitHub**: https://github.com/openschoolcn/zfn_api
- **语言**：Python
- **支持功能**：
  - 登录验证（自动识别验证码）
  - 个人信息查询
  - 成绩查询
  - 课表查询
  - 考试信息
  - 空教室查询

#### 方案B：官方API（如有）
- 联系学校信息中心获取官方API文档
- 需要学校开放权限

#### 方案C：Mock API（开发测试用）
- 本地模拟API服务
- 用于开发阶段测试

## Mock API设计

### 服务器配置
- **技术栈**：Flask + Python
- **端口**：5000
- **启动命令**：`python mock_server.py`

### 核心API端点

#### 1. 教师信息
```
GET /api/teacher/info
```
返回教师基本信息（姓名、学院、职务等）

#### 2. 课程列表
```
GET /api/teacher/courses?semester=2024-2025-2
```
返回当前学期所授课程列表

#### 3. 课表查询
```
GET /api/schedule/weekly?teacher_id=LSJ2024
```
返回整周课表（区分工作日/周末模式）

```
GET /api/schedule/daily?date=2025-03-30
```
返回指定日期课程安排

#### 4. 教学任务
```
GET /api/tasks?status=进行中&course_id=DM101
```
返回教学任务列表，支持状态/课程过滤

#### 5. 可用教室
```
GET /api/classrooms/available?date=2025-03-30&period=2&building=教学楼A
```
查询指定时间地点的可用教室

## Flutter端集成方案

### 1. API客户端封装
创建统一的API服务类：

```dart
class EducationService {
  static const String _baseUrl = 'http://127.0.0.1:5000'; // 开发环境
  
  Future<TeacherInfo> getTeacherInfo() async { ... }
  Future<List<Course>> getTeacherCourses(String semester) async { ... }
  Future<WeeklySchedule> getWeeklySchedule(String teacherId) async { ... }
  Future<List<Task>> getTasks({String? status, String? courseId}) async { ... }
}
```

### 2. 数据模型
与现有模型保持一致：
- `CourseEntry` -> 课程信息
- `ClassPeriod` -> 上课时间段
- `TodoItem` -> 教学任务
- `ScheduleProvider` -> 课表数据状态管理

### 3. 同步策略
- **定时同步**：每天凌晨自动同步次日课表
- **手动同步**：下拉刷新更新数据
- **增量更新**：只更新变化的数据

## 安全考虑

### 1. 认证机制
```dart
// 存储教师凭据
final box = await Hive.openBox('auth');
await box.put('teacher_id', teacherId);
await box.put('password', encryptedPassword);
```

### 2. 数据加密
- 使用HTTPS传输
- 本地敏感数据加密存储
- API密钥保护

### 3. 错误处理
- 网络异常重试机制
- 数据完整性验证
- 离线模式支持

## 开发计划

### 阶段一：Mock API集成
1. 完成Mock API服务开发 ✅
2. Flutter端API客户端封装
3. 数据模型映射
4. 基本UI集成测试

### 阶段二：真实API对接
1. 确定学校教务系统类型
2. 获取API访问权限
3. 实现真实登录接口
4. 数据同步功能

### 阶段三：高级功能
1. 课表变化自动提醒
2. 教学进度跟踪
3. 学生成绩管理
4. 教室预约功能

## 佛山-汕尾双校区支持

### 数据模型扩展
```dart
class CourseEntry {
  String courseId;
  String courseName;
  String campus; // 'foshan' 或 'shanwei'
  String classroom;
  // ... 其他字段
}
```

### 日程计算
- 工作日：佛山校区课程
- 周末：汕尾校区课程（周五晚-周日）
- 智能识别当前所在校区

## 测试计划

### 单元测试
```dart
test('API客户端正确解析教师信息', () async {
  final service = EducationService();
  final info = await service.getTeacherInfo();
  expect(info.name, equals('李思杰'));
});
```

### 集成测试
1. Mock API服务测试
2. Flutter端网络请求测试
3. 数据解析和状态管理测试
4. UI更新测试

### 真实环境测试
1. 学校Wi-Fi环境下测试
2. 移动网络环境下测试
3. 离线模式测试

## 部署方案

### 开发环境
- 本地Mock API服务器
- Flutter Debug模式

### 测试环境
- 云服务器部署Mock API
- Flutter测试版本

### 生产环境
- 学校服务器部署API网关
- Flutter正式版本发布

## 技术风险与应对

### 风险1：API兼容性
- 风险：不同学校教务系统API不同
- 应对：抽象API接口层，支持多种系统适配

### 风险2：网络稳定性
- 风险：校园网络波动
- 应对：实现离线缓存和增量同步

### 风险3：授权问题
- 风险：学校API访问权限限制
- 应对：准备备用方案（手动导入/WebView方案）

## 扩展性设计

### 插件化架构
```dart
// API适配器接口
abstract class EduSystemAdapter {
  Future<TeacherInfo> login(String username, String password);
  Future<List<Course>> fetchCourses(String semester);
  // ... 其他方法
}

// 正方系统适配器
class ZhengfangAdapter implements EduSystemAdapter { ... }

// 强智系统适配器  
class QiangzhiAdapter implements EduSystemAdapter { ... }
```

### 配置管理
通过配置文件选择使用的API适配器：
```json
{
  "edu_system": "zhengfang",
  "api_base_url": "https://jwxt.gdcp.cn",
  "teacher_id": "LSJ2024"
}
```

## 总结
本方案提供了从Mock API开发到真实系统对接的完整路径，兼顾佛山-汕尾双校区教学特点，为教师提供了便捷的日程管理工具。