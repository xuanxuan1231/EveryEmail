import 'package:flutter/foundation.dart';

import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';
import '../local/database/app_database.dart';
import '../secure/token_store.dart';
import 'gmail_push_service.dart';
import 'webhook_service.dart';

/// Gmail watch 管理器：管理 Gmail API `users.watch` 推送的启用/拆除 + FCM token 注册。
///
/// 与 [WebhookManager]（Microsoft Graph）平行，但有两点不同：
/// - **不做续订**：watch 最长 7 天过期，续订交给 Worker 的 Cron Trigger 服务端处理
///   （遍历 KV 重新 watch），App 长期不打开也不会断。这里只在启动/新增账户时建立 watch。
/// - **refresh token 上送**：方案要求 Worker 在 App 被杀时也能调 Gmail API 拉邮件内容，
///   故启用 watch 时把账户 refresh token 交给 Worker（Worker AES-GCM 加密后存 KV）。
///
/// FCM token 的注册/注销端点（`/api/register-fcm`）与 provider 无关，复用 [WebhookService]。
/// 收到推送后的客户端处理（触发增量同步）走 [WebhookManager.handlePushNotification]，
/// 那条路径本就只看 accountId，对 Gmail 账户同样适用，无需在此重复。
class GmailWatchManager {
  GmailWatchManager({
    required this.gmailPushService,
    required this.webhookService,
    required this.tokenStore,
    required this.db,
  });

  final GmailPushService gmailPushService;
  final WebhookService webhookService;
  final TokenStore tokenStore;
  final AppDatabase db;

  // ---------- 单账户启用 ----------

  /// 为单个 gmailOAuth 账户启用 watch 推送。非 Gmail 账户直接返回 false（不报错）。
  Future<bool> enableWatch(AccountConfig account) async {
    if (account.type != AccountType.gmailOAuth) {
      return false;
    }
    if (account.secretRef == null) {
      debugPrint('Gmail 账户缺少 secretRef，跳过 watch: ${account.email}');
      return false;
    }
    try {
      debugPrint('=== 启用 Gmail watch ===');
      debugPrint('账户: ${account.email}');

      final refreshToken = await tokenStore.readRefreshToken(account.secretRef!);
      if (refreshToken == null) {
        debugPrint('未找到 refresh token，跳过 watch: ${account.email}');
        return false;
      }

      final result = await gmailPushService.startWatch(
        refreshToken: refreshToken,
        userId: account.id,
        accountId: account.id,
        email: account.email,
      );

      if (!result.success) {
        debugPrint('启用 Gmail watch 失败: ${result.error}');
        return false;
      }

      debugPrint('Gmail watch 启用成功，historyId=${result.historyId}');
      return true;
    } catch (e) {
      debugPrint('启用 Gmail watch 异常: $e');
      return false;
    }
  }

  // ---------- 批量入口（启动时调用） ----------

  /// 为所有 gmailOAuth 账户启用 watch。应用启动时调用一次：
  /// Worker 端 upsert 幂等，重复启用会顺带重置 7 天有效期。
  Future<void> enableForAllGmailAccounts() async {
    final accounts = await _loadGmailAccounts();
    for (final account in accounts) {
      await enableWatch(account);
    }
  }

  /// 为所有 gmailOAuth 账户注册当前 FCM token。每次 token 刷新都应再调一次。
  Future<void> registerFcmTokenForAllGmailAccounts(String fcmToken) async {
    final accounts = await _loadGmailAccounts();
    for (final account in accounts) {
      try {
        await webhookService.registerFCMToken(
          userId: account.id,
          accountId: account.id,
          fcmToken: fcmToken,
        );
      } catch (e) {
        debugPrint('注册 FCM token 失败（${account.email}）：$e');
      }
    }
  }

  /// 注册 FCM token（单账户）。
  Future<bool> registerFCMToken(String accountId, String fcmToken) async {
    try {
      return await webhookService.registerFCMToken(
        userId: accountId,
        accountId: accountId,
        fcmToken: fcmToken,
      );
    } catch (e) {
      debugPrint('注册 FCM token 失败: $e');
      return false;
    }
  }

  /// 注销 FCM token（单账户）。
  Future<bool> unregisterFCMToken(String accountId) async {
    try {
      return await webhookService.unregisterFCMToken(
        userId: accountId,
        accountId: accountId,
      );
    } catch (e) {
      debugPrint('注销 FCM token 失败: $e');
      return false;
    }
  }

  /// 删除账户时的完整推送拆除：停 watch（含 Worker 端清 KV / 加密 refresh token）+ 注销 FCM 映射。
  ///
  /// 非 Gmail 账户只是无 watch 可停，调用安全。
  Future<void> tearDownForAccount(AccountConfig account) async {
    if (account.type == AccountType.gmailOAuth) {
      try {
        await gmailPushService.stopWatch(
          userId: account.id,
          accountId: account.id,
          email: account.email,
        );
      } catch (e) {
        debugPrint('停止 Gmail watch 失败（${account.email}）：$e');
      }
    }
    await unregisterFCMToken(account.id);
  }

  // ---------- 内部 ----------

  Future<List<AccountConfig>> _loadGmailAccounts() async {
    final rows = await db.accountDao.getAccounts();
    return rows
        .where((r) => r.accountType == AccountType.gmailOAuth)
        .map(_rowToConfig)
        .toList();
  }

  AccountConfig _rowToConfig(Account row) {
    return AccountConfig(
      id: row.id,
      email: row.email,
      displayName: row.displayName,
      type: row.accountType,
      authType: row.authType,
      secretRef: row.secretRef,
      imap: row.imapHost != null
          ? ServerConfig(
              host: row.imapHost!,
              port: row.imapPort ?? 993,
              socketType: row.imapSocketType!,
            )
          : null,
      smtp: row.smtpHost != null
          ? ServerConfig(
              host: row.smtpHost!,
              port: row.smtpPort ?? 465,
              socketType: row.smtpSocketType!,
            )
          : null,
      loginName: row.loginName,
      colorValue: row.colorValue,
    );
  }
}
