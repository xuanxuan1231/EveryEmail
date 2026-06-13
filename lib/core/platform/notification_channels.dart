import 'package:flutter/services.dart';

/// 按账户同步 Android 通知渠道的轻量封装。
///
/// 新邮件走纯 FCM notification 推送、由系统直接弹托盘，应用拦不到、压不住。要按账户区分
/// 通知，唯一正路是用 Android 的通知渠道分组：每个账户一个分组（=「通知类别」，含该账户的
/// 「允许通知」总开关）+ 分组下一个「邮件」渠道。Worker 把通知投递到 `mail_<accountId>`，
/// 系统设置里的逐账户开关才会生效。
///
/// 渠道须在通知到达前已在设备上创建，否则 FCM 回退到自动建的 "Misc"。因此应用启动及账户
/// 增删/改名时都应调用 [sync]。iOS / 非 Android 平台原生侧为 no-op。
class NotificationChannels {
  const NotificationChannels._();

  static const MethodChannel _channel = MethodChannel(
    'com.everyemail.app/notification_channels',
  );

  /// 用当前账户集合同步渠道。原生侧会创建缺失的分组/渠道，并删除已移除账户遗留的分组。
  /// 失败（iOS 未实现 / 调用异常）静默忽略——通知渠道不可用不应影响主流程。
  static Future<void> sync(List<({String id, String name})> accounts) async {
    try {
      await _channel.invokeMethod<void>('syncChannels', {
        'accounts': [
          for (final account in accounts)
            {'id': account.id, 'name': account.name},
        ],
      });
    } catch (_) {
      // 忽略：渠道同步失败不影响其他功能。
    }
  }
}
