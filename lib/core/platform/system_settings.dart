import 'package:flutter/services.dart';

/// 调用原生打开系统设置页的轻量封装。
///
/// 改用纯 FCM notification 推送后，通知的声音/震动/重要性/开关由系统通知渠道
/// 管理，应用内不再自管这些选项——设置页提供入口跳到系统通知设置即可。
class SystemSettings {
  const SystemSettings._();

  static const MethodChannel _channel = MethodChannel(
    'com.everyemail.app/system_settings',
  );

  /// 打开本应用的系统通知设置页。失败（iOS 未实现 / 个别设备无入口）时静默忽略。
  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {
      // 忽略：跳转失败不影响其他功能。
    }
  }
}
