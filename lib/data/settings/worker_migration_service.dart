import 'package:flutter/foundation.dart';

import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';
import '../local/database/app_database.dart';
import '../secure/token_store.dart';
import '../sync/sync_service.dart';
import '../webhook/gmail_push_service.dart';
import '../webhook/gmail_watch_manager.dart';
import '../webhook/webhook_manager.dart';
import '../webhook/webhook_service.dart';

class WorkerMigrationService {
  WorkerMigrationService({
    required this.db,
    required this.tokenStore,
    required this.syncService,
    required this.currentFcmToken,
  });

  final AppDatabase db;
  final TokenStore tokenStore;
  final SyncService syncService;
  final String? currentFcmToken;

  Future<void> migrateWorkerBaseUrl({
    required String oldUrl,
    required String newUrl,
  }) async {
    if (oldUrl == newUrl) return;

    final accounts = await _loadPushAccounts();
    if (accounts.isEmpty) return;

    await _tearDownOnWorker(oldUrl, accounts);
    await _enableOnWorker(newUrl, accounts);
  }

  Future<void> _tearDownOnWorker(
    String workerUrl,
    List<AccountConfig> accounts,
  ) async {
    final webhookService = WebhookService(workerUrl: workerUrl);
    final webhookManager = WebhookManager(
      webhookService: webhookService,
      syncService: syncService,
      db: db,
      tokenStore: tokenStore,
    );
    final gmailManager = GmailWatchManager(
      gmailPushService: GmailPushService(workerUrl: workerUrl),
      webhookService: webhookService,
      tokenStore: tokenStore,
      db: db,
    );

    try {
      for (final account in accounts) {
        try {
          switch (account.type) {
            case AccountType.microsoftGraph:
              await webhookManager.tearDownForAccount(account);
              break;
            case AccountType.gmailOAuth:
              await gmailManager.tearDownForAccount(account);
              break;
            case AccountType.genericImap:
              break;
          }
        } catch (e) {
          debugPrint('旧 Worker 推送拆除失败（${account.email}）：$e');
        }
      }
    } finally {
      webhookManager.dispose();
    }
  }

  Future<void> _enableOnWorker(
    String workerUrl,
    List<AccountConfig> accounts,
  ) async {
    final webhookService = WebhookService(workerUrl: workerUrl);
    final webhookManager = WebhookManager(
      webhookService: webhookService,
      syncService: syncService,
      db: db,
      tokenStore: tokenStore,
    );
    final gmailManager = GmailWatchManager(
      gmailPushService: GmailPushService(workerUrl: workerUrl),
      webhookService: webhookService,
      tokenStore: tokenStore,
      db: db,
    );

    try {
      for (final account in accounts) {
        try {
          switch (account.type) {
            case AccountType.microsoftGraph:
              await webhookManager.enableWebhook(account);
              if (currentFcmToken != null) {
                await webhookManager.registerFCMToken(
                  account.id,
                  currentFcmToken!,
                );
              }
              break;
            case AccountType.gmailOAuth:
              await gmailManager.enableWatch(account);
              if (currentFcmToken != null) {
                await gmailManager.registerFCMToken(
                  account.id,
                  currentFcmToken!,
                );
              }
              break;
            case AccountType.genericImap:
              break;
          }
        } catch (e) {
          debugPrint('新 Worker 推送建立失败（${account.email}）：$e');
        }
      }
    } finally {
      webhookManager.dispose();
    }
  }

  Future<List<AccountConfig>> _loadPushAccounts() async {
    final rows = await db.accountDao.getAccounts();
    return rows
        .where(
          (row) =>
              row.accountType == AccountType.microsoftGraph ||
              row.accountType == AccountType.gmailOAuth,
        )
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
      loginName: row.loginName,
      colorValue: row.colorValue,
      imap: row.imapHost == null
          ? null
          : ServerConfig(
              host: row.imapHost!,
              port: row.imapPort ?? 993,
              socketType: row.imapSocketType ?? SocketType.ssl,
            ),
      smtp: row.smtpHost == null
          ? null
          : ServerConfig(
              host: row.smtpHost!,
              port: row.smtpPort ?? 465,
              socketType: row.smtpSocketType ?? SocketType.ssl,
            ),
    );
  }
}
