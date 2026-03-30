# 李思杰教师课表应用 APK 构建指南

## 应用信息
- **应用名称**: 李老师日程
- **版本**: 1.0.0+1
- **功能**: 教师课表管理、桌面小组件、节假日识别、双城通勤支持

## 快速构建方法

### 方法1: 本地构建 (推荐用于测试)

#### 1. 环境准备
```powershell
# 1. 下载 Flutter SDK
# 访问 https://flutter.dev/docs/get-started/install/windows 下载
# 解压到 C:\flutter

# 2. 下载 Android Studio
# 访问 https://developer.android.com/studio 下载安装
# 安装时选择 "Android SDK"

# 3. 设置环境变量
setx ANDROID_HOME "C:\Users\%USERNAME%\AppData\Local\Android\Sdk"
setx PATH "%PATH%;C:\flutter\bin"

# 4. 接受 Android 许可证
flutter doctor --android-licenses
```

#### 2. 一键构建脚本
运行项目根目录中的 `build_apk.ps1`:
```powershell
cd "C:\Users\Administrator\WorkBuddy\Claw\teacher-schedule-app"
powershell -ExecutionPolicy Bypass -File .\build_apk.ps1
```

### 方法2: 使用在线构建服务

#### 1. Codemagic (免费版)
1. 访问 https://codemagic.io
2. 连接 GitHub 仓库 (lisijie11/teacher-schedule-app)
3. 选择 Flutter 项目
4. 自动构建 APK

#### 2. GitHub Actions
在 GitHub 仓库中添加 `.github/workflows/build.yml`:
```yaml
name: Build APK

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
    - run: flutter pub get
    - run: flutter build apk --release
    - uses: actions/upload-artifact@v3
      with:
        name: app-release
        path: build/app/outputs/flutter-apk/app-release.apk
```

### 方法3: 使用 Android Studio

1. 打开 Android Studio
2. 导入项目: `teacher-schedule-app/android`
3. 从 Build 菜单选择 `Build > Build Bundle(s) / APK(s) > Build APK(s)`
4. 等待构建完成

## 构建配置详情

### APK 类型
- **调试版 (debug)**: 用于测试，未混淆，包含调试信息
- **发布版 (release)**: 用于正式发布，已混淆和优化

### 签名配置 (发布版需要)
在 `android/app/build.gradle` 中添加:
```gradle
signingConfigs {
    release {
        storeFile file("my-release-key.jks")
        storePassword "密码"
        keyAlias "my-key-alias"
        keyPassword "密码"
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### 生成签名密钥
```bash
keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
```

## 项目功能模块

### 1. Android 桌面小组件
- **v4版**: 基础版，显示时间和今日课程
- **v5版**: 增强版，支持多课程显示和用户个性化

### 2. Flutter UI 界面
- 主页页面指示器
- 上下文感知浮动按钮
- 交互动画效果
- 今日课程卡片

### 3. 数据管理
- Hive 本地存储
- API 缓存系统
- 离线支持
- 节假日识别

## 常见问题解决

### 1. Android SDK 找不到
```
错误: Unable to locate Android SDK
解决: 
1. 安装 Android Studio: https://developer.android.com/studio
2. 设置 ANDROID_HOME 环境变量
3. 运行: flutter config --android-sdk "SDK路径"
```

### 2. 许可证未接受
```
错误: Android licenses not accepted
解决: flutter doctor --android-licenses (按 y 接受所有)
```

### 3. 构建失败
```
错误: Gradle build failed
解决:
1. 清理项目: flutter clean
2. 更新依赖: flutter pub get
3. 检查 Android 版本: 确保 compileSdkVersion 正确
```

## 文件输出位置

### 调试版 APK
```
build/app/outputs/flutter-apk/app-debug.apk
```

### 发布版 APK
```
build/app/outputs/flutter-apk/app-release.apk
```

### AAB 包 (Google Play)
```
build/app/outputs/bundle/release/app-release.aab
```

## 测试安装

### 通过 ADB 安装
```bash
# 连接 Android 设备并开启 USB 调试
adb devices
adb install app-debug.apk
```

### 通过文件管理器
1. 将 APK 复制到 Android 设备
2. 在设备上允许 "安装来自未知来源的应用"
3. 使用文件管理器打开 APK 文件

---

## 立即测试方案

如果你想立即测试应用，有以下方案：

### 方案A: Web 版本测试
1. 安装 Flutter: `choco install flutter`
2. 运行: `flutter run -d chrome`
3. 在 Chrome 浏览器中测试完整功能

### 方案B: 使用现有 APK
联系我获取预构建的调试版 APK 用于测试

### 方案C: GitHub 自动构建
将项目推送到 GitHub，使用 GitHub Actions 自动构建

---

## 技术支持
如有问题，请联系:
- 开发者: 李思杰
- 助手: 温野火
- 项目: GitHub @lisijie11/teacher-schedule-app

---

*最后更新: 2026-03-30*