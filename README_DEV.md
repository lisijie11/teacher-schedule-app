# 教师课表助手 - 开发说明

## 📱 应用概述

这是一个为广东东软学院教师李思杰专门开发的课表管理应用。应用支持双城通勤（佛山/汕尾）、工作日/周末双作息模式、节假日识别和Android桌面小部件。

## 🚀 快速开始

### 1. 运行环境要求
- Flutter 3.0+
- Dart 3.0+
- Windows/Linux/macOS 开发环境
- Android/iOS 模拟器或真机

### 2. 运行应用（离线演示模式）
1. 克隆项目到本地
2. `cd teacher-schedule-app`
3. `flutter pub get` （如果无法运行flutter命令，请确保Flutter已安装）
4. 连接设备或启动模拟器
5. 构建并运行应用

### 3. 测试登录
- **用户名**: `lisijie`
- **密码**: `demo123`

应用将自动以离线模式登录，显示演示数据。

## 🏗️ 项目架构

### 目录结构
```
lib/
├── screens/                    # 页面组件
│   ├── login_screen.dart      # 登录界面（新增）
│   ├── home_screen.dart       # 主页（Tab导航）
│   ├── today_screen.dart      # 今日课程页
│   ├── schedule_screen.dart   # 课表页面
│   ├── todo_screen.dart       # 任务管理页
│   └── settings_screen.dart   # 设置页面
├── services/                   # 服务层
│   ├── api/                   # API客户端（新增）
│   │   ├── api_client.dart
│   │   ├── api_service_manager.dart
│   │   ├── api_response.dart
│   │   ├── api_exceptions.dart
│   │   └── models/
│   ├── holiday_service.dart   # 节假日服务
│   ├── notification_service.dart # 通知服务
│   └── widget_service.dart    # 桌面小部件服务
├── models/                     # 数据模型
│   ├── schedule_model.dart
│   ├── todo_model.dart
│   └── course_model.dart
└── theme.dart                 # 主题定义
```

### 核心功能模块

#### 1. API 集成系统（新增）
```dart
// 使用示例
final apiManager = ApiServiceManager.instance;
await apiManager.initialize(baseUrl: 'http://localhost:5000');

// 登录
final response = await apiManager.login(LoginRequest(
  username: 'lisijie',
  password: 'password123',
  userType: 'teacher',
));

// 获取课表
final scheduleResponse = await apiManager.getTeacherSchedule();
```

#### 2. 双重认证模式
- **在线模式**：连接教务系统API（可配置）
- **离线模式**：使用本地演示数据（默认）

#### 3. 界面系统
- Material Design 3 设计语言
- 暗色/亮色主题切换
- 交互动画效果（卡片入场、页面切换）
- 响应式布局

#### 4. 本地存储
- Hive 作为本地数据库
- 课程数据、提醒事项、用户设置
- API认证令牌持久化

#### 5. 平台特性
- Android 桌面小组件（多层渐变背景）
- 系统通知提醒
- 节假日智能识别

## 🔧 开发指南

### 添加新功能
1. 在 `lib/services/api/` 添加API端点
2. 在 `lib/models/` 添加数据模型
3. 在 `lib/screens/` 创建界面组件
4. 在主题中定义颜色和样式

### 主题定制
修改 `lib/theme.dart` 中的颜色定义：
- 主色调：`primaryDark`, `primaryLight`
- 强调色：`accentGreen`, `accentOrange`, `accentRed`, `accentTeal`
- 背景色：`darkBg0`-`darkBg3`（暗色）, `lightBg0`-`lightBg2`（亮色）

### 调试技巧
1. **日志输出**：使用 `print()` 或 `debugPrint()`
2. **API调试**：运行 `api_mock/simple_mock_server.py` 模拟API服务
3. **离线数据**：演示账号 `lisijie/demo123`

## 🔌 API 集成配置

### 连接真实教务系统
1. 修改 `lib/screens/login_screen.dart` 中的 `baseUrl`
2. 在 `lib/services/api/api_client.dart` 中添加新的API端点
3. 实现实际的认证和数据处理逻辑

### 本地开发服务器
```bash
# 安装依赖
pip install flask flask-cors

# 运行
python api_mock/simple_mock_server.py

# 服务器地址
http://127.0.0.1:5000
```

支持的端点：
- `GET /api/health` - 健康检查
- `GET /api/teacher/schedule` - 获取课表（模拟数据）
- `POST /api/auth/login` - 用户登录

## 📦 构建发布

### Android 应用
1. 配置签名密钥
2. 修改 `android/app/build.gradle` 中的版本信息
3. 构建 APK：`flutter build apk --release`

### 桌面小组件
- 更新 `android/app/src/main/res/layout/schedule_widget.xml`
- 修改 `android/app/src/main/res/drawable/widget_background.xml`
- 重新构建应用并安装

## 🐛 常见问题

### 1. Flutter 命令找不到
确保Flutter已正确安装并添加到PATH环境变量。

### 2. API连接失败
- 检查网络连接
- 确认API服务器地址正确
- 使用演示账号登录（离线模式）

### 3. Android小部件不显示
- 确保应用已安装
- 长按桌面添加小组件
- 重新启动设备

### 4. 通知不工作
- 检查应用通知权限
- 确认系统级别通知设置
- 验证 `flutter_local_notifications` 配置

## 📚 相关资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [Material Design 3 指南](https://m3.material.io)
- [Hive NoSQL 数据库](https://docs.hivedb.dev)
- [GitHub Actions CI/CD](https://docs.github.com/en/actions)

## 👥 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交代码更改
4. 创建 Pull Request

## 📄 许可证

本项目仅供个人学习使用。

---

**最后更新**: 2026-03-30
**版本**: 2.0.0 (API集成版)
**开发者**: 李思杰 - 广东东软学院 数字媒体与设计学院