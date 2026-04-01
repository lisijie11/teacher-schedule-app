import 'package:flutter/services.dart';

/// 超级岛服务 - Flutter 端调用接口
/// 伪装成音乐APP的悬浮窗提醒
class HyperIslandService {
  HyperIslandService._();
  static final HyperIslandService instance = HyperIslandService._();

  static const _channel = MethodChannel('com.teacher_schedule/hyper_island');

  /// 显示超级岛提醒
  /// [title] - 标题（会伪装成歌曲名）
  /// [body] - 内容（会伪装成艺术家/专辑）
  /// [durationSeconds] - 显示时长（秒）
  static Future<void> show({
    required String title,
    required String body,
    int durationSeconds = 10,
  }) async {
    try {
      await _channel.invokeMethod('showIsland', {
        'title': title,
        'body': body,
        'duration': durationSeconds,
      });
    } on PlatformException catch (e) {
      print('超级岛显示失败: ${e.message}');
    }
  }

  /// 隐藏超级岛
  static Future<void> hide() async {
    try {
      await _channel.invokeMethod('hideIsland');
    } on PlatformException catch (e) {
      print('超级岛隐藏失败: ${e.message}');
    }
  }

  /// 检查是否有悬浮窗权限
  static Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 请求悬浮窗权限
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      print('请求权限失败: ${e.message}');
    }
  }
}
