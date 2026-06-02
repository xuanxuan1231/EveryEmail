import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';
import '../local/database/app_database.dart';
import '../sync/sync_service.dart';
import 'webhook_service.dart';

/// Webhook 管理器：管理 Microsoft Graph 订阅生命周期 + 处理 FCM 推送。
///
/// 设计要点：
/// - 只服务于 microsoftGraph 账户；Gmail 走 IMAP IDLE，不进这里。
/// - access token 全部走 [SyncService.getAccessToken]，共享单飞缓存。
///   绝不在这里自己 refresh——Microsoft Entra 滚动 refresh token 撑不住并发刷新。
/// - 订阅元数据存 SharedPreferences（key: `webhook.subscription.<accountId>`）。
///   订阅 ID 不是核心数据，丢了下次启动重建即可。
/// - 每个账户独立的续订定时器（每 2 天一次，Graph 订阅有效期 3 天）。
class WebhookManager {
  WebhookManager({
    required this.webhookService,
    required this.syncService,
    required this.db,
  });

  final WebhookService webhookService;
  final SyncService syncService;
  final AppDatabase db;

  /// 每账户独立的续订定时器。
  final Map<String, Timer> _renewTimers = {};

  static const String _prefsKeyPrefix = 'webhook.subscription.';

  /// 订阅参数格式版本。改动订阅创建参数（changeType / includeResourceData 等）
  /// 时递增；App 启动发现旧版本会自动删除并重建订阅。
  /// v2: 只订阅 created + 富通知加密（去重 + 通知含主题/发件人）。
  static const int _subscriptionSchemaVersion = 2;

  // ---------- 单账户启用/禁用 ----------

  /// 为单个 microsoftGraph 账户启用 webhook 推送。
  /// 非 Microsoft 账户直接返回 false（不报错）。
  Future<bool> enableWebhook(AccountConfig account) async {
    if (account.type != AccountType.microsoftGraph) {
      return false;
    }
    try {
      debugPrint('=== 启用 Webhook 推送 ===');
      debugPrint('账户: ${account.email}');

      final accessToken = await syncService.getAccessToken(account);

      final result = await webhookService.createSubscription(
        accessToken: accessToken,
        userId: account.id,
        accountId: account.id,
      );

      if (!result.success) {
        debugPrint('创建订阅失败: ${result.error}');
        return false;
      }

      debugPrint('订阅创建成功: ${result.subscriptionId}');
      debugPrint('过期时间: ${result.expirationDateTime}');

      await _saveSubscription(
        account.id,
        result.subscriptionId!,
        result.expirationDateTime!,
      );

      _startAutoRenew(account);
      return true;
    } catch (e) {
      debugPrint('启用 Webhook 失败: $e');
      return false;
    }
  }

  /// 禁用 webhook 推送。
  Future<bool> disableWebhook(AccountConfig account) async {
    if (account.type != AccountType.microsoftGraph) {
      return true;
    }
    try {
      debugPrint('=== 禁用 Webhook 推送 ===');
      debugPrint('账户: ${account.email}');

      _renewTimers.remove(account.id)?.cancel();

      final subscriptionId = await _getSubscriptionId(account.id);
      if (subscriptionId == null) {
        debugPrint('未找到订阅信息，跳过远端删除');
        return true;
      }

      String accessToken;
      try {
        accessToken = await syncService.getAccessToken(account);
      } catch (e) {
        debugPrint('获取 access token 失败：$e；仍然清理本地订阅元数据');
        await _deleteSubscription(account.id);
        return false;
      }

      final success = await webhookService.deleteSubscription(
        accessToken: accessToken,
        subscriptionId: subscriptionId,
        userId: account.id,
      );

      // 不管远端 200 还是 404，本地都清，避免下次启用时拿着过期 ID 续订失败。
      await _deleteSubscription(account.id);

      if (success) {
        debugPrint('订阅删除成功');
      }
      return success;
    } catch (e) {
      debugPrint('禁用 Webhook 失败: $e');
      return false;
    }
  }

  // ---------- 批量入口（启动时调用） ----------

  /// 为所有 microsoftGraph 账户启用或续订订阅。
  /// 应用启动时调用一次：现有订阅会自动续订，缺订阅的账户会新建。
  Future<void> enableForAllMicrosoftAccounts() async {
    final accounts = await _loadMicrosoftAccounts();
    for (final account in accounts) {
      final existingId = await _getSubscriptionId(account.id);
      if (existingId != null) {
        final version = await _getSubscriptionSchemaVersion(account.id);
        if (version != _subscriptionSchemaVersion) {
          // 旧格式订阅（旧 changeType / 无加密）。续订只 PATCH 过期时间，不会更新
          // 这些参数，必须删掉重建一次，才能启用去重 + 富通知。
          debugPrint('订阅 schema 过旧($version→$_subscriptionSchemaVersion)，重建');
          await disableWebhook(account);
          await enableWebhook(account);
        } else {
          // 已是最新格式：续订即可，并把续订定时器拉起来。
          await _renewSubscription(account);
          _startAutoRenew(account);
        }
      } else {
        await enableWebhook(account);
      }
    }
  }

  /// 为所有 microsoftGraph 账户注册当前 FCM token。
  /// 每次 token 刷新都应再调一次。
  Future<void> registerFcmTokenForAllMicrosoftAccounts(String fcmToken) async {
    final accounts = await _loadMicrosoftAccounts();
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

  /// 注销 FCM token（单账户）。删除账户时清理 Worker KV 映射。
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

  /// 删除账户时的完整推送拆除：删 Graph 订阅 + 清本地订阅元数据 + 注销 FCM 映射。
  ///
  /// 必须在账户凭据（secretRef）仍可用时调用——删订阅需要 access token。
  /// 非 Microsoft 账户只是无订阅可删，调用安全。
  Future<void> tearDownForAccount(AccountConfig account) async {
    await disableWebhook(account);
    await unregisterFCMToken(account.id);
  }

  // ---------- 推送处理 ----------

  /// 处理推送通知。Worker 通过 FCM 投递的 data payload 至少应含 `accountId`。
  Future<void> handlePushNotification(Map<String, dynamic> data) async {
    try {
      debugPrint('=== 收到推送通知 ===');
      debugPrint('数据: $data');

      final accountId = data['accountId'] as String?;
      if (accountId == null) {
        debugPrint('推送通知缺少 accountId');
        return;
      }

      final accountData = await db.accountDao.getAccount(accountId);
      if (accountData == null) {
        debugPrint('账户不存在: $accountId');
        return;
      }

      final account = _rowToConfig(accountData);

      debugPrint('触发增量同步...');
      await syncService.syncAccount(account);
      debugPrint('同步完成');
    } catch (e) {
      debugPrint('处理推送通知失败: $e');
    }
  }

  // ---------- 内部 ----------

  void _startAutoRenew(AccountConfig account) {
    _renewTimers.remove(account.id)?.cancel();
    _renewTimers[account.id] = Timer.periodic(const Duration(days: 2), (_) async {
      debugPrint('自动续订订阅: ${account.email}');
      await _renewSubscription(account);
    });
  }

  Future<void> _renewSubscription(AccountConfig account) async {
    try {
      final subscriptionId = await _getSubscriptionId(account.id);
      if (subscriptionId == null) {
        debugPrint('未找到订阅信息，改走新建');
        await enableWebhook(account);
        return;
      }

      final accessToken = await syncService.getAccessToken(account);

      final result = await webhookService.renewSubscription(
        accessToken: accessToken,
        subscriptionId: subscriptionId,
      );

      if (result.success) {
        debugPrint('订阅续订成功，新过期时间: ${result.expirationDateTime}');
        await _saveSubscription(
          account.id,
          subscriptionId,
          result.expirationDateTime!,
        );
      } else {
        debugPrint('订阅续订失败: ${result.error}；改走新建');
        await _deleteSubscription(account.id);
        await enableWebhook(account);
      }
    } catch (e) {
      debugPrint('续订订阅失败: $e');
    }
  }

  Future<List<AccountConfig>> _loadMicrosoftAccounts() async {
    final rows = await db.accountDao.getAccounts();
    return rows
        .where((r) => r.accountType == AccountType.microsoftGraph)
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

  // ---------- SharedPreferences 持久化 ----------

  String _prefsKey(String accountId) => '$_prefsKeyPrefix$accountId';

  Future<void> _saveSubscription(
    String accountId,
    String subscriptionId,
    DateTime expirationDateTime,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'subscriptionId': subscriptionId,
      'expirationDateTime': expirationDateTime.toIso8601String(),
      'schemaVersion': _subscriptionSchemaVersion,
    });
    await prefs.setString(_prefsKey(accountId), payload);
    debugPrint('保存订阅信息: $subscriptionId');
  }

  Future<String?> _getSubscriptionId(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(accountId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['subscriptionId'] as String?;
    } catch (e) {
      debugPrint('解析订阅信息失败，清理: $e');
      await prefs.remove(_prefsKey(accountId));
      return null;
    }
  }

  /// 读取已存订阅的格式版本；旧数据无该字段时视为 1（需要重建）。
  Future<int> _getSubscriptionSchemaVersion(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(accountId));
    if (raw == null) return 0;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['schemaVersion'] as int? ?? 1;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _deleteSubscription(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(accountId));
    debugPrint('删除订阅信息: $accountId');
  }

  // ---------- 生命周期 ----------

  /// 停止所有续订定时器。
  void dispose() {
    for (final timer in _renewTimers.values) {
      timer.cancel();
    }
    _renewTimers.clear();
  }
}
