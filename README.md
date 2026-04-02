# 教师专属日程 App

教师专用 Android 日程管理应用，支持课表管理、提醒通知、桌面小组件。

## 功能特性

- 🔔 **智能提醒**：课程前 N 分钟原生通知，可自定义提前时间
- 🇨🇳 **节假日识别**：自动识别中国法定节假日与调休（接入 timor.tech API）
- 📱 **桌面小组件**：显示当前/下节课信息，点击直接打开 App
- ✅ **待办清单**：简洁高效的 Todo 管理
- 🌓 **主题切换**：浅色/暗色模式，支持跟随系统

## 本地编译

```bash
flutter pub get
flutter build apk --release
```

## 开发

项目使用 Flutter 构建，支持 Android 小组件（Kotlin）和 iOS widget。
