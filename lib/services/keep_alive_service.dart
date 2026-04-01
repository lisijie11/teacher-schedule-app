import 'package:flutter/services.dart';

/// 保活服务 - Flutter 端调用接口
/// 参考 mikcb 项目实现：
/// - 无障碍服务 + 前台服务双重保活
/// - 确保课程提醒及时送达
class KeepAliveService {
  KeepAliveService._();
  static final KeepAliveService instance = KeepAliveService._();

  static const _channel = MethodChannel('com.teacher_schedule/hyper_island');

  /// 启动保活服务
  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startKeepAliveService');
    } on PlatformException catch (e) {
      print('启动保活服务失败: ${e.message}');
    }
  }

  /// 停止保活服务
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopKeepAliveService');
    } on PlatformException catch (e) {
      print('停止保活服务失败: ${e.message}');
    }
  }

  /// 检查保活服务是否正在运行
  static Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isKeepAliveServiceRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 检查无障碍服务是否已启用
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 打开无障碍服务设置页面
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print('打开无障碍设置失败: ${e.message}');
    }
  }

  /// 一键开启保活（启动服务并提示开启无障碍）
  static Future<void> enableKeepAlive() async {
    // 启动前台服务
    await start();

    // 检查无障碍服务
    final hasAccessibility = await isAccessibilityEnabled();
    if (!hasAccessibility) {
      // 提示用户开启无障碍服务
      await openAccessibilitySettings();
    }
  }
}
