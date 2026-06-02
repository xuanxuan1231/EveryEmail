import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/auth/oauth_service.dart';
import '../data/local/database/app_database.dart';
import '../data/repositories/account_repository.dart';
import '../data/secure/token_store.dart';
import '../data/sync/realtime_sync_service.dart';
import '../data/sync/sync_service.dart';
import '../data/webhook/webhook_manager.dart';
import '../data/webhook/webhook_service.dart';

/// 全局单例数据库。在 [bootstrap] 中已通过 overrideWithValue 注入真实实例，
/// 这里给一个会抛错的占位，确保未初始化时能快速失败。
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider 必须在 ProviderScope overrides 中注入');
});

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final oauthServiceProvider = Provider<OAuthService>((ref) => OAuthService());

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    db: ref.watch(databaseProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    oauthService: ref.watch(oauthServiceProvider),
    webhookManager: ref.watch(webhookManagerProvider),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(databaseProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    oauthService: ref.watch(oauthServiceProvider),
  );
});

/// 实时同步服务。
final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  return RealtimeSyncService(ref.watch(syncServiceProvider));
});

/// Webhook 服务。
final webhookServiceProvider = Provider<WebhookService>((ref) {
  return WebhookService(
    workerUrl: 'https://everyemail-webhook.17635169264012.workers.dev',
  );
});

/// Webhook 管理器。
final webhookManagerProvider = Provider<WebhookManager>((ref) {
  return WebhookManager(
    webhookService: ref.watch(webhookServiceProvider),
    syncService: ref.watch(syncServiceProvider),
    db: ref.watch(databaseProvider),
  );
});

/// 当前 FCM token（由 FcmBootstrap 获取并刷新）。
///
/// 新增账户时读取它，立刻把单个新账户注册到 Worker，
/// 不必等下次冷启动 FcmBootstrap 的全量注册。
final fcmTokenProvider = StateProvider<String?>((ref) => null);

/// 全部账户的响应式列表。
final accountsProvider = StreamProvider((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

/// 统一收件箱的响应式列表。
final unifiedInboxProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).messageDao.watchUnifiedInbox(limit: 100);
});

/// 监听所有账户。
final accountsStreamProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).accountDao.watchAccounts();
});

/// 监听特定账户的所有邮件。
final accountMessagesProvider = StreamProvider.family<List<Message>, String>((ref, accountId) {
  return ref.watch(databaseProvider).messageDao.watchAccountMessages(accountId, limit: 100);
});
