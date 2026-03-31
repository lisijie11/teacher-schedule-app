# 教师专属日程 App APK 构建指南

## 环境要求

- Flutter SDK >= 3.0
- Android Studio 或命令行工具
- Android SDK

## 本地构建

```bash
# 1. 安装依赖
flutter pub get

# 2. 构建 Debug APK
flutter build apk --debug

# 3. 构建 Release APK
flutter build apk --release
```

APK 输出位置：`build/app/outputs/flutter-apk/`

## GitHub Actions 自动构建

项目已配置 GitHub Actions，push 到 master 分支会自动构建 APK。
