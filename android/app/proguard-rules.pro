# Flutter Wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保持 Kotlin 原生服务
-keep class com.lisijie.teacher_schedule.** { *; }

# 保持 Hive 数据模型
-keep class * extends hive.** { *; }

# 保持 MethodChannel 通信
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# Gson/Retrofit (如果有)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# 通用优化
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# Google Play Core (Flutter 分架构打包需要)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
