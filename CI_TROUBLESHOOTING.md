# Flutter Android CI 编译修复全记录

> 项目：teacher-schedule-app  
> 时间：2026-03-30  
> 目标：Flutter 3.22.3 + GitHub Actions 自动编译 APK 并发布 Release  
> 最终结果：✅ Run #21 全部步骤通过，自动发布 Release 成功

---

## 问题背景

将 Flutter Android 项目接入 GitHub Actions CI 后，连续出现多个编译错误，以下是逐一排查和修复的完整过程。

---

## 修复一：`Could not get unknown property 'flutterRoot'`

### 错误信息
```
Could not get unknown property 'flutterRoot' for project ':app' of type org.gradle.api.Project.
```

### 原因
Flutter 3.22+ 不再自动向 Gradle 注入 `flutterRoot` 属性，旧式写法 `project.ext.flutterRoot` 在 CI 环境失效。

### 修复
在 `android/app/build.gradle` 文件顶部手动从 `local.properties` 读取：

```groovy
// 读取 local.properties
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}
```

---

## 修复二：`Could not get unknown property 'flutterVersionCode'`

### 错误信息
```
Could not get unknown property 'flutterVersionCode' for project ':app'.
```

### 原因
Flutter 3.22+ 同样不再自动注入 `flutterVersionCode` 和 `flutterVersionName`。

### 修复
在 `android/app/build.gradle` 的 `defaultConfig` 中改用固定值：

```groovy
defaultConfig {
    // ...
    versionCode 1          // 原来是 flutterVersionCode.toInteger()
    versionName "1.0.0"    // 原来是 flutterVersionName
}
```

---

## 修复三：CI 环境缺少 `local.properties`

### 错误信息
```
assert localPropertiesFile.exists()
```

### 原因
`local.properties` 是本地开发文件，通常在 `.gitignore` 中，CI 环境没有这个文件。

### 修复一：修改 `android/settings.gradle`，用条件判断替代 assert

```groovy
// 旧写法（会 assert 失败）
// assert localPropertiesFile.exists()

// 新写法
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}
```

### 修复二：在 `.github/workflows/build-apk.yml` 中添加生成步骤

```yaml
- name: Generate local.properties
  run: |
    echo "flutter.sdk=$FLUTTER_ROOT" > android/local.properties
    echo "sdk.dir=$ANDROID_SDK_ROOT" >> android/local.properties
    cat android/local.properties
```

---

## 修复四：`home_widget` 包版本不兼容

### 错误信息
```
home_widget 0.4.1: No named parameter 'size'
```
以及：
```
home_widget >=0.9.0 requires SDK version >=3.5.0 <4.0.0
```

### 原因
- `home_widget 0.4.1` 与 Flutter 3.22 的新 API 不兼容
- `home_widget >=0.9.0` 要求 Dart SDK >= 3.5.0，而 Flutter 3.22.3 自带 Dart 3.4.x

### 修复
在 `pubspec.yaml` 中指定兼容版本：

```yaml
dependencies:
  home_widget: ^0.7.0   # 原来是 ^0.4.1
```

---

## 修复五：pubspec.yaml 引用了空 assets 目录

### 错误信息
```
Error: unable to find directory entry in pubspec.yaml: .../assets/
```

### 原因
`pubspec.yaml` 中声明了 `assets/` 目录，但该目录实际上是空的（或不存在）。

### 修复
删除 `pubspec.yaml` 中的空目录引用：

```yaml
# flutter:
#   assets:
#     - assets/        # 删掉这行（目录为空时不能引用）
```

---

## 修复六：Android 缺少 LaunchTheme / NormalTheme 样式

### 错误信息
```
resource style/LaunchTheme not found
resource style/NormalTheme not found
```

### 原因
Flutter 项目的 `AndroidManifest.xml` 引用了这两个主题，但 `res/values/styles.xml` 不存在。

### 修复
新建两个文件：

**`android/app/src/main/res/values/styles.xml`**
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@android:color/white</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@android:color/white</item>
    </style>
</resources>
```

**`android/app/src/main/res/values-night/styles.xml`**
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@android:color/black</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@android:color/black</item>
    </style>
</resources>
```

---

## 修复七：Create Release 权限不足

### 错误信息
```
Error: Resource not accessible by integration
https://docs.github.com/rest/releases/releases#create-a-release
```

### 原因
GitHub Actions 的 `GITHUB_TOKEN` 默认权限是只读，workflow 中没有声明写权限，无法创建 Release。

### 修复
在 `.github/workflows/build-apk.yml` 的 `jobs` 前加上权限声明：

```yaml
permissions:
  contents: write
```

---

## 额外优化：消除 Node.js 20 废弃警告

### 警告信息
```
Node.js 20 actions are deprecated... Actions will be forced to run with Node.js 24 by default starting June 2nd, 2026.
```

### 修复
在 `env` 块中加入：

```yaml
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

---

## 最终 workflow 文件

```yaml
name: Build APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: write

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.3'
          channel: 'stable'
          cache: true

      - name: Generate local.properties
        run: |
          echo "flutter.sdk=$FLUTTER_ROOT" > android/local.properties
          echo "sdk.dir=$ANDROID_SDK_ROOT" >> android/local.properties

      - name: Get dependencies
        run: flutter pub get

      - name: Build APK (release)
        run: flutter build apk --release --no-tree-shake-icons

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: teacher-schedule-release
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 30

      - name: Create Release
        uses: softprops/action-gh-release@v2
        if: github.ref == 'refs/heads/main'
        with:
          tag_name: v1.0.${{ github.run_number }}
          name: "教师日程助手 v1.0.${{ github.run_number }}"
          files: build/app/outputs/flutter-apk/app-release.apk
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 错误速查表

| 错误关键词 | 对应修复 |
|-----------|---------|
| `unknown property 'flutterRoot'` | app/build.gradle 手动读 local.properties |
| `unknown property 'flutterVersionCode'` | versionCode/Name 改固定值 |
| `assert localPropertiesFile.exists()` | CI workflow 中生成 local.properties |
| `home_widget: No named parameter 'size'` | home_widget 升级到 ^0.7.0 |
| `unable to find directory entry in pubspec.yaml` | 删除空 assets 目录引用 |
| `resource style/LaunchTheme not found` | 新建 values/styles.xml |
| `Resource not accessible by integration` | workflow 加 `permissions: contents: write` |
| `Node.js 20 actions are deprecated` | 加 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` |

---

## 注意事项

1. **Flutter 版本升级后记得检查 Gradle 配置**：Flutter 3.22+ 对 Gradle 注入行为有较大变化。
2. **第三方包升级要验证 Dart SDK 兼容性**：`flutter --version` 确认当前 Dart 版本后再选包版本。
3. **CI 环境没有 local.properties**：任何依赖本地文件的 Gradle 配置都需要在 workflow 中手动生成。
4. **GitHub Release 需要显式写权限**：所有需要创建/修改 Release、Issue、PR 的 workflow 都需要在顶层声明 `permissions`。
