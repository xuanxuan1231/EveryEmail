import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/auth/oauth_service.dart';
import '../data/local/database/app_database.dart';
import '../data/local/database/message_with_account.dart';
import '../data/repositories/account_repository.dart';
import '../data/secure/token_store.dart';
import '../data/settings/app_font_settings.dart';
import '../data/sync/realtime_sync_service.dart';
import '../data/sync/sync_service.dart';
import '../data/webhook/webhook_manager.dart';
import '../data/webhook/webhook_service.dart';
import '../domain/enums/message_enums.dart';

/// 全局单例数据库。在 [bootstrap] 中已通过 overrideWithValue 注入真实实例，
/// 这里给一个会抛错的占位，确保未初始化时能快速失败。
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider 必须在 ProviderScope overrides 中注入');
});

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// 当前应用字体。在 [bootstrap] 中读出持久化值后，通过 overrideWith 注入真实控制器，
/// 这里给一个会抛错的占位，确保未初始化时能快速失败（与 [databaseProvider] 同构）。
final appFontProvider = StateNotifierProvider<AppFontController, AppFont>((
  ref,
) {
  throw UnimplementedError(
    'appFontProvider 必须在 ProviderScope overrides 中注入初始字体',
  );
});

/// 应用字体控制器：切换即时生效（主题 watch 此 provider）并持久化。
class AppFontController extends StateNotifier<AppFont> {
  AppFontController(super.initial);

  Future<void> set(AppFont font) async {
    if (font == state) return;
    state = font;
    await AppFontSettings.write(font);
  }
}

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
  return WebhookService(workerUrl: 'https://ee-webhook.gemen.pp.ua');
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

/// 全部真实账户的响应式列表。
final accountsProvider = StreamProvider((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

/// 统一收件箱的响应式列表。
final unifiedInboxProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).messageDao.watchUnifiedInbox(limit: 100);
});

/// 统一账户下某个统一文件夹的响应式列表。
final unifiedFolderMessagesProvider =
    StreamProvider.family<List<MessageWithAccount>, FolderType>((
      ref,
      folderType,
    ) {
      return ref
          .watch(databaseProvider)
          .messageDao
          .watchUnifiedFolderMessages(folderType, limit: 100);
    });

/// 监听所有真实账户。
final accountsStreamProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).accountDao.watchAccounts();
});

/// 监听特定账户的所有邮件。
final accountMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  accountId,
) {
  return ref
      .watch(databaseProvider)
      .messageDao
      .watchAccountMessages(accountId, limit: 100);
});
