import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config/app_config.dart';
import '../data/auth/oauth_service.dart';
import '../data/local/database/app_database.dart';
import '../data/local/database/message_with_account.dart';
import '../data/repositories/account_repository.dart';
import '../data/secure/token_store.dart';
import '../data/settings/app_font_settings.dart';
import '../data/settings/account_settings.dart';
import '../data/settings/display_settings.dart';
import '../data/sync/body_prefetch_service.dart';
import '../data/sync/realtime_sync_service.dart';
import '../data/sync/sync_service.dart';
import '../data/webhook/gmail_push_service.dart';
import '../data/webhook/gmail_watch_manager.dart';
import '../data/webhook/webhook_manager.dart';
import '../data/webhook/webhook_service.dart';
import '../domain/enums/message_enums.dart';

/// 全局单例数据库。在 [bootstrap] 中已通过 overrideWithValue 注入真实实例，
/// 这里给一个会抛错的占位，确保未初始化时能快速失败。
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider 必须在 ProviderScope overrides 中注入');
});

/// 应用包信息（版本号、构建号等）。在 [bootstrap] 中预读后通过 overrideWithValue
/// 注入，这里给一个会抛错的占位，确保未初始化时快速失败（与 [databaseProvider] 同构）。
final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError('packageInfoProvider 必须在 ProviderScope overrides 中注入');
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

/// 显示设置。在 [bootstrap] 中读取持久化值后注入，避免首帧主题闪烁。
final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsController, DisplaySettings>((ref) {
      throw UnimplementedError(
        'displaySettingsProvider 必须在 ProviderScope overrides 中注入初始设置',
      );
    });

/// 显示设置控制器：设置页即时更新并持久化。
class DisplaySettingsController extends StateNotifier<DisplaySettings> {
  DisplaySettingsController(super.initial);

  Future<void> setColorMode(AppColorMode colorMode) {
    return _set(state.copyWith(colorMode: colorMode));
  }

  Future<void> setPreviewLines(int previewLines) {
    final clamped = previewLines < 0
        ? 0
        : previewLines > 3
        ? 3
        : previewLines;
    return _set(state.copyWith(previewLines: clamped));
  }

  Future<void> setTimeFormat(MailListTimeFormat timeFormat) {
    return _set(state.copyWith(timeFormat: timeFormat));
  }

  Future<void> setShowSenderAvatar(bool visible) {
    return _set(state.copyWith(showSenderAvatar: visible));
  }

  Future<void> setShowAccountLabels(bool visible) {
    return _set(state.copyWith(showAccountLabels: visible));
  }

  Future<void> setShowAttachmentIcon(bool visible) {
    return _set(state.copyWith(showAttachmentIcon: visible));
  }

  Future<void> setShowUnreadIndicator(bool visible) {
    return _set(state.copyWith(showUnreadIndicator: visible));
  }

  Future<void> setShowStarButton(bool visible) {
    return _set(state.copyWith(showStarButton: visible));
  }

  Future<void> setPrefetchBodies(bool enabled) {
    return _set(state.copyWith(prefetchBodies: enabled));
  }

  Future<void> _set(DisplaySettings settings) async {
    if (settings == state) return;
    state = settings;
    await DisplaySettingsStore.write(settings);
  }
}

final accountSettingsProvider =
    StateNotifierProvider.family<
      AccountSettingsController,
      AccountSettings,
      String
    >((ref, accountId) {
      final controller = AccountSettingsController(accountId);
      unawaited(controller.load());
      return controller;
    });

/// 每个账户的设置控制器：二级设置页即时更新并持久化。
class AccountSettingsController extends StateNotifier<AccountSettings> {
  AccountSettingsController(this.accountId) : super(AccountSettings.defaults);

  final String accountId;

  Future<void> load() async {
    state = await AccountSettingsStore.read(accountId);
  }

  Future<void> setAvatarText(String? value) {
    final trimmed = value?.trim();
    final normalized = trimmed == null || trimmed.isEmpty
        ? null
        : String.fromCharCodes(trimmed.runes.take(2)).toUpperCase();
    return _set(
      state.copyWith(
        avatarMode: AccountAvatarMode.text,
        avatarText: normalized,
        avatarIconId: null,
        avatarImagePath: null,
      ),
    );
  }

  Future<void> setAvatarIcon(String iconId) {
    return _set(
      state.copyWith(
        avatarMode: AccountAvatarMode.icon,
        avatarIconId: iconId.trim(),
        avatarImagePath: null,
      ),
    );
  }

  Future<void> setAvatarImagePath(String imagePath) {
    return _set(
      state.copyWith(
        avatarMode: AccountAvatarMode.image,
        avatarImagePath: imagePath.trim(),
      ),
    );
  }

  Future<void> setReceiveEnabled(bool enabled) {
    return _set(state.copyWith(receiveEnabled: enabled));
  }

  Future<void> setSendEnabled(bool enabled) {
    return _set(state.copyWith(sendEnabled: enabled));
  }

  Future<void> setRealtimeSyncEnabled(bool enabled) {
    return _set(state.copyWith(realtimeSyncEnabled: enabled));
  }

  Future<void> setFolderSyncScope(AccountFolderSyncScope scope) {
    return _set(state.copyWith(folderSyncScope: scope));
  }

  Future<void> setSyncSpamAndTrash(bool enabled) {
    return _set(state.copyWith(syncSpamAndTrash: enabled));
  }

  Future<void> setIncludeInSearch(bool enabled) {
    return _set(state.copyWith(includeInSearch: enabled));
  }

  Future<void> setSearchSpamAndTrash(bool enabled) {
    return _set(state.copyWith(searchSpamAndTrash: enabled));
  }

  Future<void> reset() {
    return _set(AccountSettings.defaults);
  }

  Future<void> _set(AccountSettings settings) async {
    if (settings == state) return;
    state = settings;
    await AccountSettingsStore.write(accountId, settings);
  }
}

final oauthServiceProvider = Provider<OAuthService>((ref) => OAuthService());

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    db: ref.watch(databaseProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    oauthService: ref.watch(oauthServiceProvider),
    webhookManager: ref.watch(webhookManagerProvider),
    gmailWatchManager: ref.watch(gmailWatchManagerProvider),
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

/// 邮件正文预取服务：同步后批量 + 列表可见 + 点击即取，让点开邮件即见内容。
///
/// 与 [SyncService] 通过 `onFolderSynced` 回调单向连接（避免循环依赖）：收件箱
/// 同步落库后驱动批量预取。需在首帧附近被读取一次以完成回调挂接，见
/// [RealtimeSyncCoordinator]。
final bodyPrefetchServiceProvider = Provider<BodyPrefetchService>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final service = BodyPrefetchService(
    syncService: syncService,
    db: ref.watch(databaseProvider),
    isPrefetchEnabled: () => ref.read(displaySettingsProvider).prefetchBodies,
  );
  syncService.onFolderSynced = service.handleFolderSynced;
  ref.onDispose(() {
    if (identical(syncService.onFolderSynced, service.handleFolderSynced)) {
      syncService.onFolderSynced = null;
    }
    service.dispose();
  });
  return service;
});

/// Webhook 服务。
final webhookServiceProvider = Provider<WebhookService>((ref) {
  return WebhookService(workerUrl: AppConfig.workerBaseUrl);
});

/// Webhook 管理器。
final webhookManagerProvider = Provider<WebhookManager>((ref) {
  return WebhookManager(
    webhookService: ref.watch(webhookServiceProvider),
    syncService: ref.watch(syncServiceProvider),
    db: ref.watch(databaseProvider),
  );
});

/// Gmail 推送服务（users.watch 生命周期）。
final gmailPushServiceProvider = Provider<GmailPushService>((ref) {
  return GmailPushService(workerUrl: AppConfig.workerBaseUrl);
});

/// Gmail watch 管理器。FCM 注册复用 [webhookServiceProvider]；续订由 Worker Cron 负责。
final gmailWatchManagerProvider = Provider<GmailWatchManager>((ref) {
  return GmailWatchManager(
    gmailPushService: ref.watch(gmailPushServiceProvider),
    webhookService: ref.watch(webhookServiceProvider),
    tokenStore: ref.watch(tokenStoreProvider),
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

/// 监听某账户的全部文件夹（管理文件夹页消费，含被隐藏的文件夹）。
final accountFoldersProvider = StreamProvider.family<List<Folder>, String>((
  ref,
  accountId,
) {
  return ref.watch(databaseProvider).folderDao.watchFolders(accountId);
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

/// 监听某个具体文件夹的邮件（按账户选中具体文件夹时消费）。
///
/// 用 StreamProvider 而非内联 StreamBuilder：provider 会跨 widget 重建缓存
/// 当前结果，返回详情页时不会闪一下 loading（重订阅），从而保住列表滚动位置。
final folderMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  folderId,
) {
  return ref
      .watch(databaseProvider)
      .messageDao
      .watchFolderMessages(folderId, limit: 100);
});
