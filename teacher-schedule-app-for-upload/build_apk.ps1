# Flutter 教师课表应用 APK 构建脚本
# 执行此脚本前请确保已安装 Flutter 和 Android SDK

Write-Host "=== Flutter 教师课表应用 APK 构建脚本 ===" -ForegroundColor Cyan
Write-Host "开始时间: $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

# 1. 设置环境变量
$env:FLUTTER_PATH = "C:\flutter"
$env:PATH = "$env:FLUTTER_PATH\bin;$env:PATH"

# 2. 检查 Flutter
Write-Host "1. 检查 Flutter 环境..." -ForegroundColor Green
try {
    flutter --version
    Write-Host "✓ Flutter 检测成功" -ForegroundColor Green
} catch {
    Write-Host "✗ Flutter 未安装或不在 PATH 中" -ForegroundColor Red
    Write-Host "请从 https://flutter.dev 安装 Flutter" -ForegroundColor Yellow
    exit 1
}

# 3. 清理项目
Write-Host "`n2. 清理项目..." -ForegroundColor Green
flutter clean
flutter pub get

# 4. 检查依赖
Write-Host "`n3. 检查依赖..." -ForegroundColor Green
flutter pub outdated

# 5. 构建 APK
Write-Host "`n4. 构建 APK..." -ForegroundColor Green
Write-Host "构建过程可能需要几分钟，请耐心等待..." -ForegroundColor Yellow

# 选项 1: 调试版本 (无混淆，可用于测试)
Write-Host "构建调试版本 (debug)..." -ForegroundColor Cyan
flutter build apk --debug

# 选项 2: 发布版本 (混淆优化，用于正式发布)
# Write-Host "构建发布版本 (release)..." -ForegroundColor Cyan
# flutter build apk --release

# 6. 显示构建结果
Write-Host "`n5. 构建完成!" -ForegroundColor Green
Write-Host "结束时间: $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

$debugApk = "build\app\outputs\flutter-apk\app-debug.apk"
$releaseApk = "build\app\outputs\flutter-apk\app-release.apk"

if (Test-Path $debugApk) {
    $fileInfo = Get-Item $debugApk
    Write-Host "调试 APK: $debugApk" -ForegroundColor Cyan
    Write-Host "文件大小: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "安装方法:" -ForegroundColor Yellow
    Write-Host "1. 将 APK 文件传输到 Android 设备" -ForegroundColor White
    Write-Host "2. 在 Android 设备上开启 '安装来自未知来源的应用'" -ForegroundColor White
    Write-Host "3. 使用文件管理器或 ADB 安装: adb install $debugApk" -ForegroundColor White
}

Write-Host "`n=== 构建步骤总结 ===" -ForegroundColor Cyan
Write-Host "1. 安装 Flutter SDK" -ForegroundColor White
Write-Host "2. 安装 Android SDK 并设置 ANDROID_HOME" -ForegroundColor White
Write-Host "3. 接受 Android 许可证: flutter doctor --android-licenses" -ForegroundColor White
Write-Host "4. 运行此脚本: .\build_apk.ps1" -ForegroundColor White

Write-Host "`nAndroid SDK 下载地址: https://developer.android.com/studio" -ForegroundColor Yellow
Write-Host "Flutter 安装指南: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow