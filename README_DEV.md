# 教师专属日程 App 开发文档

通用教师课表管理应用，支持双城作息切换、节假日识别和 Android 桌面小组件。

## 功能概览

- 双城通勤（两个校区）
- 工作日 / 周末双作息模式
- 中国法定节假日自动识别
- Android 桌面小组件
- 浅色 / 深色主题
- 离线数据存储

## 开发环境

- Flutter SDK >= 3.0
- Android Studio / VS Code
- Android SDK

## 快速开始

```bash
# 安装依赖
flutter pub get

# 本地开发
flutter run

# 构建 Release APK
flutter build apk --release
```

## 测试

```bash
# 运行单元测试
flutter test

# 集成测试
flutter test integration_test/
```

## 演示账号

离线模式支持通用演示账号登录。

## API 模拟服务器

详见 `api_mock/` 目录。

## 项目结构

- `lib/` - Flutter 主应用代码
- `android/` - Android 原生代码（小组件）
- `api_mock/` - API 模拟服务器
- `integration_test/` - 集成测试
