import 'package:flutter/services.dart';

/// 本地新邮件通知。
///
/// IMAP 没有统一可用的云推送通道；当客户端通过 IDLE/轮询同步到新邮件时，走这里
/// 发本机通知。当前 Android 原生侧实现，其他平台为 no-op。
class LocalMailNotifications {
  const LocalMailNotifications._();

  static const MethodChannel _channel = MethodChannel(
    'com.everyemail.app/local_mail_notifications',
  );

  static Future<void> showNewMail({
    required String accountId,
    required String accountName,
    required String messageId,
    required String subject,
    required String? senderName,
    required String? senderEmail,
    required String preview,
    required bool playSound,
    required bool enableVibration,
  }) async {
    try {
      await _channel.invokeMethod<void>('showNewMailNotification', {
        'accountId': accountId,
        'accountName': accountName,
        'messageId': messageId,
        'subject': subject,
        'senderName': senderName,
        'senderEmail': senderEmail,
        'preview': preview,
        'playSound': playSound,
        'enableVibration': enableVibration,
      });
    } catch (_) {
      // 平台未实现、权限未授予或通知管理器异常都不应影响同步主流程。
    }
  }
}
