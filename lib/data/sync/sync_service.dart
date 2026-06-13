// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/id_generator.dart' as id_gen;
import '../../domain/enums/account_enums.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/account_config.dart';
import '../../domain/models/mail_attachment.dart';
import '../../domain/models/mailbox_folder.dart';
import '../../domain/models/message_envelope.dart';
import '../../domain/models/message_ref.dart';
import '../auth/oauth_service.dart';
import '../backends/gmail/gmail_mail_backend.dart';
import '../backends/graph/graph_mail_backend.dart';
import '../backends/imap/imap_mail_backend.dart';
import '../backends/mail_backend.dart';
import '../backends/sync_types.dart';
import '../local/database/app_database.dart';
import '../secure/token_store.dart';
import '../settings/account_settings.dart';

/// 邮件同步服务：编排后端同步与数据库持久化。
///
/// 职责：
/// - 为每个账户创建对应的 MailBackend 实例
/// - 拉取文件夹和邮件并写入 Drift
/// - 增量同步（delta）
/// - 错误处理和重试
class SyncService {
  SyncService({
    required AppDatabase db,
    required TokenStore tokenStore,
    required OAuthService oauthService,
  }) : _db = db,
       _tokenStore = tokenStore,
       _oauthService = oauthService;

  final AppDatabase _db;
  final TokenStore _tokenStore;
  final OAuthService _oauthService;
  final Map<String, MailBackend> _backends = {};

  /// 每账户当前缓存的 access token（仍在有效期内可复用）。
  final Map<String, OAuthTokens> _tokenCache = {};

  /// 每账户正在进行的刷新 future，用于单飞合并并发刷新。
  /// Microsoft Entra public client 启用了滚动刷新令牌——并发刷新会让旧
  /// refresh token 立刻失效、其它并发请求全数 invalid_grant，必须串行。
  final Map<String, Future<OAuthTokens>> _refreshInflight = {};

  /// 共享的 access token 入口：缓存 + 单飞调度。
  /// Microsoft Entra public client 启用了滚动刷新令牌——并发刷新会让旧
  /// refresh token 立刻失效、其它并发请求全数 invalid_grant，必须串行。
  /// WebhookManager 等其它服务也走这里以共享缓存。
  Future<String> getAccessToken(AccountConfig account) async {
    if (account.secretRef == null) {
      throw Exception('OAuth 账户缺少 secretRef');
    }
    final cached = _tokenCache[account.id];
    if (cached != null && !cached.isExpired()) {
      return cached.accessToken;
    }
    final inflight = _refreshInflight[account.id];
    if (inflight != null) {
      final t = await inflight;
      return t.accessToken;
    }
    final future = _refreshTokens(account);
    _refreshInflight[account.id] = future;
    try {
      final tokens = await future;
      _tokenCache[account.id] = tokens;
      return tokens.accessToken;
    } finally {
      _refreshInflight.remove(account.id);
    }
  }

  Future<OAuthTokens> _refreshTokens(AccountConfig account) async {
    final refreshToken = await _tokenStore.readRefreshToken(account.secretRef!);
    if (refreshToken == null) {
      throw Exception('Refresh token 不存在');
    }
    return _oauthService.refresh(account.type, refreshToken);
  }

  /// 为账户创建或获取后端实例。
  Future<MailBackend> _getBackend(AccountConfig account) async {
    if (_backends.containsKey(account.id)) {
      return _backends[account.id]!;
    }

    MailBackend backend;
    switch (account.type) {
      case AccountType.gmailOAuth:
        // Gmail REST API 后端（取代 IMAP，避免列表同步整封下载正文）。
        backend = GmailApiBackend(
          account: account,
          tokenProvider: () => getAccessToken(account),
        );
        break;

      case AccountType.genericImap:
        // 通用 IMAP 后端（密码 / 应用专用密码）。
        String? password;
        if (account.secretRef != null) {
          password = await _tokenStore.readPassword(account.secretRef!);
        }

        backend = ImapMailBackend(account: account, password: password);
        break;

      case AccountType.microsoftGraph:
        // Graph 后端
        if (account.secretRef == null) {
          throw Exception('Microsoft Graph 账户缺少 secretRef');
        }

        backend = GraphMailBackend(
          account: account,
          tokenProvider: () => getAccessToken(account),
        );
        break;
    }

    await backend.connect();
    _backends[account.id] = backend;
    return backend;
  }

  /// 缓存的 IMAP 后端是否已过 OAuth 连接新鲜期，需要重连以刷新 access token。
  /// 无缓存后端 / 非 IMAP / 密码连接均为 false（详见 [ImapMailBackend.isStale]）。
  bool isBackendStale(AccountConfig account) {
    final backend = _backends[account.id];
    return backend is ImapMailBackend && backend.isStale;
  }

  /// 在账户串行队列上重连后端：重建底层连接、经 tokenProvider 取当前有效 token。
  /// 走队列以与同步/取信等操作互斥，避免重建 client 时撞上进行中的命令流。
  /// 无缓存后端则忽略（下次 [_getBackend] 会以全新 token 建连）。
  ///
  /// 注意：重连会使该后端当前的 IDLE 监听失效——调用方（实时协调器）须随后重建监听。
  Future<void> reconnectBackend(AccountConfig account) async {
    final backend = _backends[account.id];
    if (backend is! ImapMailBackend) return;
    await _runOnAccount<void>(
      account.id,
      backend.reconnect,
      highPriority: true,
    );
  }

  /// 从 [accountId] 重建领域模型 [AccountConfig]（[_getBackend] 需要它）。
  /// 映射与 AccountRepository.toConfig / WebhookManager._rowToConfig 保持一致。
  Future<AccountConfig> accountConfigFor(String accountId) async {
    final row = await _db.accountDao.getAccount(accountId);
    if (row == null) {
      throw Exception('账户不存在: $accountId');
    }
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

  /// 每账户后端访问串行队列：同步、按需取正文、后台预取都经由此队列，
  /// 保证同一账户不并发触碰单条后端连接（IMAP 单 client；enough_mail 的
  /// select-then-fetch 跨调用非原子，并发会选错邮箱）。高优先级（用户点开）
  /// 排在低优先级（后台预取）之前。
  final Map<String, _AccountBackendQueue> _backendQueues = {};

  /// 某文件夹同步落库后回调（folderId, folderType）。由 BodyPrefetchService 挂接，
  /// 用于在收件箱增量同步后批量预取最新邮件正文。SyncService 不反向依赖预取服务，
  /// 避免循环依赖。
  void Function(String folderId, FolderType folderType)? onFolderSynced;

  /// 每账户合并触发的去抖定时器。
  final Map<String, Timer> _syncDebounce = {};

  /// 在指定账户的串行队列上执行后端操作。
  Future<T> _runOnAccount<T>(
    String accountId,
    Future<T> Function() action, {
    bool highPriority = false,
  }) {
    final queue = _backendQueues.putIfAbsent(
      accountId,
      _AccountBackendQueue.new,
    );
    return queue.add(action, highPriority: highPriority);
  }

  /// 合并触发窗口：把一阵触发（Graph 一封新邮件连发的多条 updated 静默推送、
  /// 或 IMAP IDLE 连续事件）压成一次 [syncAccount]。
  static const Duration _syncDebounceWindow = Duration(seconds: 3);

  /// 请求一次（去抖 + 串行）账户同步。突发触发场景（FCM 静默数据消息 / IDLE 事件）
  /// 应走这里而非直接 [syncAccount]，避免短时间内重复全量同步。
  void requestSync(AccountConfig account) {
    _syncDebounce[account.id]?.cancel();
    _syncDebounce[account.id] = Timer(_syncDebounceWindow, () {
      _syncDebounce.remove(account.id);
      unawaited(
        syncAccount(account).catchError((Object e) {
          debugPrint('requestSync: 同步失败: $e');
        }),
      );
    });
  }

  /// 同步账户：拉取文件夹列表和初始邮件。
  ///
  /// 同一账户的并发调用（手动刷新 / FCM 静默推送 / IMAP IDLE 触发）会被串行化，
  /// 避免同时操作同一后端连接造成命令流交错。
  Future<void> syncAccount(AccountConfig account) async {
    final accountSettings = await AccountSettingsStore.read(account.id);
    if (!accountSettings.receiveEnabled) return;

    // 经由账户串行队列：与按需取正文、后台预取互斥，避免并发触碰同一后端连接。
    await _runOnAccount(
      account.id,
      () => _syncAccountInner(account, accountSettings),
    );
  }

  Future<void> _syncAccountInner(
    AccountConfig account,
    AccountSettings accountSettings,
  ) async {
    // 先把本地待推送变更（已读/标星/移动/删除等）刷到服务端，
    // 否则随后的 delta 会用服务端旧值覆盖刚改完的本地新值。
    await flushOutbox(account);

    final backend = await _getBackend(account);

    // 1. 拉取文件夹列表
    final folders = await backend.listFolders();

    // 2. 持久化文件夹
    for (final folder in folders) {
      // 检查是否已存在
      var existing = await _db.folderDao.getByRemoteId(
        account.id,
        folder.remoteId,
      );

      if (existing == null) {
        // 新文件夹：生成 ID 并插入
        final folderId = id_gen.generateId();
        await _db.folderDao.upsertFolder(
          FoldersCompanion.insert(
            id: folderId,
            accountId: account.id,
            remoteId: folder.remoteId,
            displayName: folder.displayName,
            folderType: folder.type,
            unreadCount: Value(folder.unreadCount),
            totalCount: Value(folder.totalCount),
            sortIndex: Value(_folderSortIndex(folder.type)),
          ),
        );
        existing = await _db.folderDao.getFolder(folderId);
      } else {
        // 用远端最新值覆盖类型/名称/计数：早期 Graph 后端漏 select wellKnownName，
        // 把所有文件夹写成了 custom；升级后必须重写，否则 inbox 永远不会被同步。
        await _db.folderDao.updateFromRemote(
          existing.id,
          displayName: folder.displayName,
          folderType: folder.type,
          unreadCount: folder.unreadCount,
          totalCount: folder.totalCount,
          sortIndex: _folderSortIndex(folder.type),
        );
        existing = await _db.folderDao.getFolder(existing.id);
      }

      // 3. 按账户设置与文件夹开关同步文件夹邮件。
      final localFolder = existing!;
      if (localFolder.syncEnabled &&
          accountSettings.canSyncFolder(
            localFolder.folderType,
            isSubscribed: localFolder.isSubscribed,
          )) {
        await syncFolder(account, localFolder);
      }
    }
  }

  /// 同步单个文件夹：增量拉取邮件。
  Future<void> syncFolder(AccountConfig account, Folder folder) async {
    final backend = await _getBackend(account);

    // 获取同步游标
    final syncState = await _db.messageDao.getSyncState(folder.id);
    final token = syncState?.deltaLink != null
        ? SyncToken(syncState!.deltaLink!)
        : null;

    // 执行增量同步
    final result = await backend.syncDelta(folder.toMailboxFolder(), token);

    // 持久化新增/更新的邮件
    await _persistMessages(result.added, folder);

    // 应用入站标志变更（仅 flags，不覆盖其它列）。
    await _applyFlagUpdates(result.updated, folder, account);

    // 删除已移除的邮件
    if (result.removedRefs.isNotEmpty) {
      final removedIds = <String>[];
      for (final ref in result.removedRefs) {
        // 根据后端引用查找本地 ID
        if (ref is ImapRef) {
          final msg = await _db.messageDao.getByImapUid(folder.id, ref.uid);
          if (msg != null) removedIds.add(msg.id);
        } else if (ref is GraphRef) {
          final msg = await _db.messageDao.getByGraphId(
            account.id,
            ref.messageId,
          );
          if (msg != null) removedIds.add(msg.id);
        } else if (ref is GmailRef) {
          final msg = await _db.messageDao.getByGmailId(
            account.id,
            ref.messageId,
          );
          if (msg != null) removedIds.add(msg.id);
        }
      }
      if (removedIds.isNotEmpty) {
        await _db.messageDao.deleteMessages(removedIds);
      }
    }

    // 更新同步游标
    if (result.newToken != null) {
      await _db.messageDao.upsertSyncState(
        SyncStatesCompanion.insert(
          folderId: folder.id,
          deltaLink: Value(result.newToken!.value),
          lastSyncAt: Value(DateTime.now()),
        ),
      );
    }

    // 落库完成：通知预取服务（收件箱等）按需批量预取最新邮件正文。
    onFolderSynced?.call(folder.id, folder.folderType);
  }

  /// 按需同步单个文件夹（用户主动点开 / 下拉刷新该文件夹时调用）。
  ///
  /// 与 [syncAccount] 不同：**不经过 `AccountSettings.canSyncFolder` 的范围门控**，
  /// 因此即使是默认不自动同步的垃圾邮件/废纸篓，用户主动打开也能拉取到内容。
  /// 走账户串行队列的高优先级，与取正文/预取互斥。
  Future<void> syncSingleFolder(AccountConfig account, Folder folder) {
    return _runOnAccount<void>(
      account.id,
      () => syncFolder(account, folder),
      highPriority: true,
    );
  }

  /// 历史回填一页：向更旧方向翻一页并落库（“加载更多”）。
  ///
  /// 增量同步只拿更新的邮件，首次同步又有上限，故首次窗口之外的旧邮件需经此回填。
  /// 用独立的 `backfillCursor`（不动增量游标 `deltaLink`）逐页向更旧翻；翻到底置
  /// `backfillDone`。返回是否**可能**还有更旧的一页（true=可继续调用）。
  Future<bool> loadMoreFolder(AccountConfig account, Folder folder) {
    return _runOnAccount<bool>(account.id, () async {
      final syncState = await _db.messageDao.getSyncState(folder.id);
      if (syncState?.backfillDone ?? false) return false;

      final cursorToken = syncState?.backfillCursor;
      final cursor = cursorToken == null
          ? PageCursor.start
          : PageCursor(graphNextLink: cursorToken);

      final backend = await _getBackend(account);
      final page = await backend.fetchEnvelopes(
        folder.toMailboxFolder(),
        cursor: cursor,
        limit: _backfillPageSize,
      );

      // upsert 幂等：首页与已有最新邮件重叠无害，更旧的会新增进来。
      await _persistMessages(page.envelopes, folder);

      final next = page.nextCursor;
      if (next == null) {
        await _db.messageDao.updateBackfillState(folder.id, done: true);
        return false;
      }
      await _db.messageDao.updateBackfillState(
        folder.id,
        cursor: next.graphNextLink,
        done: false,
      );
      return true;
    }, highPriority: true);
  }

  /// 修复文件夹：清空同步游标后强制全量重建，用于补回历史「空洞」
  /// （某次增量取元数据失败、游标却已前进，导致中间一段邮件永久缺失）。
  ///
  /// 走账户串行队列高优先级。全量会重取最新一批并幂等落库，填补最近的缺口；
  /// 更早的缺口仍可经 [loadMoreFolder]（“加载更多”）翻页补回。
  Future<void> repairFolder(AccountConfig account, Folder folder) {
    return _runOnAccount<void>(account.id, () async {
      await _db.messageDao.deleteSyncState(folder.id);
      await syncFolder(account, folder); // 游标为空 → 全量重建
    }, highPriority: true);
  }

  /// 修复统一文件夹：把虚拟统一文件夹展开为所有真实来源文件夹后逐一修复。
  ///
  /// 返回成功处理的来源文件夹数量。若部分来源失败，仍会尝试剩余来源，最后抛出汇总错误。
  Future<int> repairUnifiedFolder(FolderType folderType) async {
    final sourceFolders = await _db.folderDao.getUnifiedSourceFolders(
      folderType,
    );
    final failures = <Object>[];

    for (final folder in sourceFolders) {
      try {
        final account = await accountConfigFor(folder.accountId);
        await repairFolder(account, folder);
      } catch (e) {
        failures.add(e);
      }
    }

    if (failures.isNotEmpty) {
      final first = failures.first;
      final suffix = failures.length == 1
          ? '$first'
          : '$first 等 ${failures.length} 个错误';
      throw Exception('统一文件夹部分来源重新同步失败: $suffix');
    }

    return sourceFolders.length;
  }

  /// 历史回填每页拉取的信封数。
  static const int _backfillPageSize = 50;

  /// 持久化邮件列表到数据库。
  Future<void> _persistMessages(
    List<MessageEnvelope> envelopes,
    Folder folder,
  ) async {
    final companions = <MessagesCompanion>[];

    for (final envelope in envelopes) {
      // 查找是否已存在
      Message? existing;
      if (envelope.ref is ImapRef) {
        final ref = envelope.ref as ImapRef;
        existing = await _db.messageDao.getByImapUid(folder.id, ref.uid);
      } else if (envelope.ref is GraphRef) {
        final ref = envelope.ref as GraphRef;
        existing = await _db.messageDao.getByGraphId(
          envelope.accountId,
          ref.messageId,
        );
      } else if (envelope.ref is GmailRef) {
        final ref = envelope.ref as GmailRef;
        existing = await _db.messageDao.getByGmailId(
          envelope.accountId,
          ref.messageId,
        );
      }

      final messageId = existing?.id ?? id_gen.generateId();
      final ref = envelope.ref;

      companions.add(
        MessagesCompanion(
          id: Value(messageId),
          accountId: Value(envelope.accountId),
          folderId: Value(folder.id),
          imapUid: ref is ImapRef ? Value(ref.uid) : const Value.absent(),
          imapUidValidity: ref is ImapRef
              ? Value(ref.uidValidity)
              : const Value.absent(),
          graphMessageId: ref is GraphRef
              ? Value(ref.messageId)
              : const Value.absent(),
          gmailMessageId: ref is GmailRef
              ? Value(ref.messageId)
              : const Value.absent(),
          subject: Value(envelope.subject),
          fromName: Value(envelope.from?.name),
          fromEmail: Value(envelope.from?.email),
          toRecipients: Value(_encodeRecipients(envelope.to)),
          ccRecipients: Value(_encodeRecipients(envelope.cc)),
          date: Value(envelope.date),
          preview: Value(envelope.preview),
          flagsBitmask: Value(_flagsToBitmask(envelope.flags)),
          hasAttachments: Value(envelope.hasAttachments),
          threadKey: Value(envelope.threadKey),
          messageIdHeader: Value(envelope.messageIdHeader),
          labels: Value(jsonEncode(envelope.labels)),
        ),
      );
    }

    if (companions.isNotEmpty) {
      await _db.messageDao.upsertMessages(companions);
    }
  }

  /// 应用入站标志变更：只更新 `flagsBitmask`，不触碰其它列。
  ///
  /// 后端（尤其 IMAP CONDSTORE 增量）在 [SyncResult.updated] 里返回的信封
  /// 通常只含 `ref` + `flags`（FLAGS-only fetch），不能走全列 upsert，否则会把
  /// subject/from/date 等覆盖成空值。这里按后端引用定位本地行后仅写标志位。
  Future<void> _applyFlagUpdates(
    List<MessageEnvelope> updated,
    Folder folder,
    AccountConfig account,
  ) async {
    for (final env in updated) {
      final ref = env.ref;
      Message? local;
      if (ref is ImapRef) {
        local = await _db.messageDao.getByImapUid(folder.id, ref.uid);
      } else if (ref is GraphRef) {
        local = await _db.messageDao.getByGraphId(account.id, ref.messageId);
      } else if (ref is GmailRef) {
        local = await _db.messageDao.getByGmailId(account.id, ref.messageId);
      }
      if (local != null) {
        await _db.messageDao.updateFlags(local.id, _flagsToBitmask(env.flags));
      }
    }
  }

  /// 监听账户收件箱的实时事件（IMAP IDLE）。
  ///
  /// 返回 null 表示后端不支持实时或无收件箱。调用前应已 [syncAccount] 过一次，
  /// 确保后端已连接且文件夹列表就绪（IDLE 需要先选中收件箱）。
  Future<Stream<MailboxEvent>?> watchAccountInbox(AccountConfig account) async {
    final backend = await _getBackend(account);
    if (!backend.supportsIdle) return null;
    final folders = await _db.folderDao.getFolders(account.id);
    Folder? inbox;
    for (final f in folders) {
      if (f.folderType == FolderType.inbox) {
        inbox = f;
        break;
      }
    }
    if (inbox == null) return null;
    return backend.watch(inbox.toMailboxFolder());
  }

  String _encodeRecipients(List<dynamic> recipients) {
    if (recipients.isEmpty) return '[]';

    // 正确的 JSON 数组格式
    final jsonList = recipients
        .map((r) {
          final name = (r.name ?? '')
              .replaceAll('"', '\\"')
              .replaceAll('\n', ' ');
          final email = (r.email ?? '').replaceAll('"', '\\"');
          return '{"name":"$name","email":"$email"}';
        })
        .join(',');

    return '[$jsonList]';
  }

  int _flagsToBitmask(Set<MessageFlag> flags) {
    int bitmask = 0;
    for (final flag in flags) {
      bitmask |= 1 << flag.index;
    }
    return bitmask;
  }

  int _folderSortIndex(FolderType type) {
    switch (type) {
      case FolderType.inbox:
        return 0;
      case FolderType.sent:
        return 1;
      case FolderType.drafts:
        return 2;
      case FolderType.archive:
        return 3;
      case FolderType.spam:
        return 4;
      case FolderType.trash:
        return 5;
      case FolderType.custom:
        return 10;
    }
  }

  /// 下载并持久化某封邮件的正文与附件元数据（附件字节本身不在此下载）。
  ///
  /// 详情页打开邮件时调用：先查本地，缺正文才拉取后端并写入 [MessageBodies]，
  /// 之后 `MessageDao.watchBody` 会让 UI 自动刷新预览。用户即时操作，走账户串行
  /// 队列的**高优先级**，排在后台预取之前。
  ///
  /// 幂等：正文行只在成功下载后写入，故"已存在且非 notDownloaded"即视为已下载，
  /// 默认跳过；[force] 为 true 时强制重新拉取（手动重试 / 重新下载）。失败向上抛。
  Future<void> fetchMessageBody(String messageId, {bool force = false}) {
    return _fetchAndStoreBody(messageId, force: force, highPriority: true);
  }

  /// 后台预取正文：与 [fetchMessageBody] 同逻辑，但走账户串行队列的**低优先级**，
  /// 不抢占用户点开的高优先级取正文。仅在缺正文时拉取。
  Future<void> prefetchMessageBody(String messageId) {
    return _fetchAndStoreBody(messageId, force: false, highPriority: false);
  }

  Future<void> _fetchAndStoreBody(
    String messageId, {
    required bool force,
    required bool highPriority,
  }) async {
    final message = await _db.messageDao.getMessage(messageId);
    if (message == null) return;

    if (!force) {
      final existing = await _db.messageDao.getBody(messageId);
      if (existing != null &&
          existing.fetchState != BodyFetchState.notDownloaded) {
        return;
      }
    }

    await _runOnAccount<void>(message.accountId, () async {
      // 取得队列槽位后再查一次：另一任务（点开 + 预取并发）可能已经下完。
      if (!force) {
        final existing = await _db.messageDao.getBody(messageId);
        if (existing != null &&
            existing.fetchState != BodyFetchState.notDownloaded) {
          return;
        }
      }

      final ref = await _refForMessage(messageId);
      if (ref == null) {
        throw Exception('无法定位邮件，无法下载正文');
      }

      final account = await accountConfigFor(message.accountId);
      final backend = await _getBackend(account);
      final content = await backend.fetchMessageContent(ref);

      await _db.messageDao.upsertBody(
        MessageBodiesCompanion.insert(
          messageId: messageId,
          plainText: Value(content.plainText),
          htmlBody: Value(content.htmlBody),
          fetchState: Value(
            content.attachments.isEmpty
                ? BodyFetchState.full
                : BodyFetchState.partial,
          ),
          attachmentsMeta: Value(
            jsonEncode([for (final a in content.attachments) a.toJson()]),
          ),
          fetchedAt: Value(DateTime.now()),
        ),
      );
    }, highPriority: highPriority);
  }

  /// 下载附件字节并存为本地文件，返回文件绝对路径；同时把 localPath 回写进正文行的
  /// attachmentsMeta —— 响应式 `watchBody` 会让详情页附件项自动切换为"已下载/打开"。
  ///
  /// 幂等：若该附件已有 localPath 且文件仍在，直接返回缓存路径，不重复下载。
  /// 取字节走账户串行队列的高优先级，与正文下载/同步互斥。
  Future<String> downloadAttachment({
    required String messageId,
    required String partId,
  }) async {
    final message = await _db.messageDao.getMessage(messageId);
    if (message == null) {
      throw Exception('邮件不存在，无法下载附件');
    }

    final body = await _db.messageDao.getBody(messageId);
    final attachments = AttachmentUtils.parseAttachments(body?.attachmentsMeta);
    MailAttachment? meta;
    for (final a in attachments) {
      if (a.partId == partId) {
        meta = a;
        break;
      }
    }

    // 已下载且文件还在 → 直接复用。
    final cached = meta?.localPath;
    if (cached != null && cached.isNotEmpty && await File(cached).exists()) {
      return cached;
    }

    final account = await accountConfigFor(message.accountId);
    final bytes = await _runOnAccount<List<int>>(account.id, () async {
      final ref = await _refForMessage(messageId);
      if (ref == null) {
        throw Exception('无法定位邮件，无法下载附件');
      }
      final backend = await _getBackend(account);
      return backend.fetchAttachmentBytes(ref, partId);
    }, highPriority: true);

    // 存到 <app docs>/attachments/<messageId>/<partId>-<安全文件名>。
    final dir = await getApplicationDocumentsDirectory();
    final attachDir = Directory('${dir.path}/attachments/$messageId');
    await attachDir.create(recursive: true);
    final safeName = _safeFileName(meta?.filename ?? partId);
    final file = File('${attachDir.path}/$partId-$safeName');
    await file.writeAsBytes(bytes, flush: true);

    // 回写 localPath（与 size 兜底）到 attachmentsMeta。
    final updated = [
      for (final a in attachments)
        if (a.partId == partId)
          a.copyWith(localPath: file.path, size: a.size ?? bytes.length)
        else
          a,
    ];
    await _db.messageDao.updateAttachmentsMeta(
      messageId,
      AttachmentUtils.encodeAttachments(updated),
    );

    return file.path;
  }

  /// 把文件名清成文件系统安全的形式（保留字母数字/点/横杠，其余折成下划线）。
  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    return cleaned.isEmpty ? 'attachment' : cleaned;
  }

  /// 修改邮件的 [flag] 状态：先乐观更新本地 DB，再入队（由下次 [flushOutbox]
  /// 推送到后端）。UI 必须走这里而不是直接调 [MessageDao.updateFlags]，否则
  /// 服务端不知道变更，下一次 delta 同步会回滚本地值。
  Future<void> setMessageFlag(
    String messageId, {
    required MessageFlag flag,
    required bool value,
  }) async {
    final message = await _db.messageDao.getMessage(messageId);
    if (message == null) return;

    final newBitmask = value
        ? message.flagsBitmask | (1 << flag.index)
        : message.flagsBitmask & ~(1 << flag.index);
    if (newBitmask == message.flagsBitmask) return;

    // 仅 seen 标志影响未读角标：标读 -1、标未读 +1。服务端计数为基线，
    // 这里本地即时增减让角标及时变化，下次整账户同步再以 listFolders 矫正。
    final unreadDelta = flag == MessageFlag.seen ? (value ? -1 : 1) : 0;

    // 远端引用：Gmail 用 gmailMessageId、Graph 用 graphMessageId、IMAP 用 uid。
    // 必须用 _refPayloadForMessage 统一推导（早期只判断 graph/imap，漏了 Gmail，
    // 导致 Gmail 邮件的已读状态从不入队、永不回推服务端）。
    final refPayload = await _refPayloadForMessage(message);
    if (refPayload == null) {
      // 本地草稿等没有远端引用，仅更新本地。
      await _db.messageDao.updateFlags(messageId, newBitmask);
      await _adjustFolderUnread(message.folderId, unreadDelta);
      return;
    }

    // 与已有相同 (op, messageId) 的待推送条目去重：保留最新意图即可。
    final opType = _opTypeFor(flag, value);
    if (opType == null) {
      await _db.messageDao.updateFlags(messageId, newBitmask);
      await _adjustFolderUnread(message.folderId, unreadDelta);
      return;
    }

    await _db.transaction(() async {
      await _db.messageDao.updateFlags(messageId, newBitmask);
      await _adjustFolderUnread(message.folderId, unreadDelta);
      await _db.outboxDao.removeForMessage(message.accountId, messageId, flag);
      await _db.outboxDao.enqueue(
        OutboxOpsCompanion.insert(
          accountId: message.accountId,
          opType: opType,
          payload: Value(
            jsonEncode({'messageId': messageId, 'ref': refPayload}),
          ),
        ),
      );
    });
  }

  /// 把文件夹未读角标按 [delta] 本地增减（服务端计数为基线、这里保证及时）。
  /// 读改写并钳制非负；下次整账户同步会以 [FolderDao.updateFromRemote] 矫正漂移。
  Future<void> _adjustFolderUnread(String folderId, int delta) async {
    if (delta == 0) return;
    final folder = await _db.folderDao.getFolder(folderId);
    if (folder == null) return;
    final next = folder.unreadCount + delta;
    await _db.folderDao.updateCounts(folderId, unread: next < 0 ? 0 : next);
  }

  /// 邮件当前是否未读（seen 位未置）。
  bool _isUnread(int flagsBitmask) =>
      (flagsBitmask & (1 << MessageFlag.seen.index)) == 0;

  /// 删除邮件：本地立即移除，并把后端删除操作入队。
  Future<void> deleteMessage(String messageId) async {
    final message = await _db.messageDao.getMessage(messageId);
    if (message == null) return;

    final wasUnread = _isUnread(message.flagsBitmask);

    final refPayload = await _refPayloadForMessage(message);
    if (refPayload == null) {
      await _db.messageDao.deleteMessages([messageId]);
      if (wasUnread) await _adjustFolderUnread(message.folderId, -1);
      return;
    }

    await _db.transaction(() async {
      await _db.outboxDao.removeOpsForMessage(
        message.accountId,
        messageId,
        const ['move', 'delete'],
      );
      await _db.outboxDao.enqueue(
        OutboxOpsCompanion.insert(
          accountId: message.accountId,
          opType: 'delete',
          payload: Value(
            jsonEncode({'messageId': messageId, 'ref': refPayload}),
          ),
        ),
      );
      await _db.messageDao.deleteMessages([messageId]);
      if (wasUnread) await _adjustFolderUnread(message.folderId, -1);
    });
  }

  /// 移动邮件到指定文件夹：本地立即更新，并把后端移动操作入队。
  Future<void> moveMessageToFolder(
    String messageId,
    String targetFolderId,
  ) async {
    final message = await _db.messageDao.getMessage(messageId);
    if (message == null || message.folderId == targetFolderId) return;

    final targetFolder = await _db.folderDao.getFolder(targetFolderId);
    if (targetFolder == null) {
      throw Exception('目标文件夹不存在: $targetFolderId');
    }
    if (targetFolder.accountId != message.accountId) {
      throw Exception('不能跨账户移动邮件');
    }

    final wasUnread = _isUnread(message.flagsBitmask);
    final sourceFolderId = message.folderId;

    final refPayload = await _refPayloadForMessage(message);
    if (refPayload == null) {
      await _db.messageDao.moveMessage(messageId, targetFolderId);
      if (wasUnread) {
        await _adjustFolderUnread(sourceFolderId, -1);
        await _adjustFolderUnread(targetFolderId, 1);
      }
      return;
    }

    await _db.transaction(() async {
      await _db.outboxDao.removeOpsForMessage(
        message.accountId,
        messageId,
        const ['move'],
      );
      await _db.messageDao.moveMessage(messageId, targetFolderId);
      if (wasUnread) {
        await _adjustFolderUnread(sourceFolderId, -1);
        await _adjustFolderUnread(targetFolderId, 1);
      }
      await _db.outboxDao.enqueue(
        OutboxOpsCompanion.insert(
          accountId: message.accountId,
          opType: 'move',
          payload: Value(
            jsonEncode({
              'messageId': messageId,
              'targetFolderId': targetFolderId,
              'ref': refPayload,
            }),
          ),
        ),
      );
    });
  }

  /// 移动邮件到某个语义文件夹（如归档 / 垃圾邮件）。
  Future<void> moveMessageToFolderType(
    String messageId,
    FolderType folderType,
  ) async {
    final message = await _db.messageDao.getMessage(messageId);
    if (message == null) return;

    var targetFolder = await _folderByType(message.accountId, folderType);
    if (targetFolder == null) {
      final account = await accountConfigFor(message.accountId);
      await syncAccount(account);
      targetFolder = await _folderByType(message.accountId, folderType);
    }
    if (targetFolder == null) {
      throw Exception('账户没有可用的${_folderTypeLabel(folderType)}文件夹');
    }

    await moveMessageToFolder(messageId, targetFolder.id);
  }

  String? _opTypeFor(MessageFlag flag, bool value) {
    switch (flag) {
      case MessageFlag.seen:
        return value ? 'markRead' : 'markUnread';
      case MessageFlag.flagged:
        return value ? 'flag' : 'unflag';
      default:
        return null; // 其它标志暂不推送。
    }
  }

  /// 把账户的 outbox 待推送变更刷到后端。失败的条目保留并累计 attempts。
  ///
  /// 同类操作（已读/未读/星标/取消星标/删除，以及按目标分组的移动）会**归并成一次**
  /// 后端调用——Gmail 后端据此走 `messages.batchModify`，把 N 个请求压成 1 个。
  /// 后端的写方法本就接收 refs 列表（Graph/IMAP 内部循环），故对三种后端都兼容。
  Future<void> flushOutbox(AccountConfig account) async {
    final pending = await _db.outboxDao.getPendingForAccount(account.id);
    if (pending.isEmpty) return;

    MailBackend? backend;
    try {
      backend = await _getBackend(account);
    } catch (e) {
      debugPrint('flushOutbox: 获取后端失败，跳过本轮: $e');
      return;
    }
    final b = backend; // 此处已非空，捕获给闭包用。

    // 1) 解析每条 op 为 (op, ref) 并按操作意图分桶；无效 / 超阈值的就地丢弃。
    final markReadOps = <(OutboxOp, MessageRef)>[];
    final markUnreadOps = <(OutboxOp, MessageRef)>[];
    final flagOps = <(OutboxOp, MessageRef)>[];
    final unflagOps = <(OutboxOp, MessageRef)>[];
    final deleteOps = <(OutboxOp, MessageRef)>[];
    // 移动按目标文件夹分组：targetFolderId → (目标文件夹, 该组 ops)。
    final moveGroups = <String, (Folder, List<(OutboxOp, MessageRef)>)>{};

    for (final op in pending) {
      // 失败次数超过阈值就丢弃，避免坏条目无限阻塞队列。
      // 5 次大致覆盖临时网络抖动 + 一两次令牌刷新失败的场景。
      if (op.attempts >= 5) {
        debugPrint('flushOutbox: ${op.opType} 已重试 ${op.attempts} 次，丢弃');
        await _db.outboxDao.remove(op.id);
        continue;
      }

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(op.payload) as Map<String, dynamic>;
      } catch (_) {
        await _db.outboxDao.remove(op.id);
        continue;
      }
      final messageId = payload['messageId'] as String?;
      if (messageId == null) {
        await _db.outboxDao.remove(op.id);
        continue;
      }
      final ref =
          _refFromPayload(payload['ref']) ?? await _refForMessage(messageId);
      if (ref == null) {
        await _db.outboxDao.remove(op.id); // 邮件已不存在
        continue;
      }

      final opType = op.opType;
      if (opType == 'markRead') {
        markReadOps.add((op, ref));
      } else if (opType == 'markUnread') {
        markUnreadOps.add((op, ref));
      } else if (opType == 'flag') {
        flagOps.add((op, ref));
      } else if (opType == 'unflag') {
        unflagOps.add((op, ref));
      } else if (opType == 'delete') {
        deleteOps.add((op, ref));
      } else if (opType == 'move') {
        final targetFolderId = payload['targetFolderId'] as String?;
        if (targetFolderId == null) {
          await _db.outboxDao.remove(op.id);
          continue;
        }
        final targetFolder = await _db.folderDao.getFolder(targetFolderId);
        if (targetFolder == null) {
          await _db.outboxDao.remove(op.id);
          continue;
        }
        moveGroups.putIfAbsent(targetFolderId, () => (targetFolder, [])).$2.add(
          (op, ref),
        );
      } else {
        debugPrint('flushOutbox: 未支持的 opType=$opType, 丢弃');
        await _db.outboxDao.remove(op.id);
      }
    }

    // 2) 每桶一次性推送；成功移除桶内全部 op，失败则整桶累计 attempts。
    await _flushBucket(
      markReadOps,
      () => b.markRead(_refsOf(markReadOps), read: true),
    );
    await _flushBucket(
      markUnreadOps,
      () => b.markRead(_refsOf(markUnreadOps), read: false),
    );
    await _flushBucket(
      flagOps,
      () => b.markFlagged(_refsOf(flagOps), flagged: true),
    );
    await _flushBucket(
      unflagOps,
      () => b.markFlagged(_refsOf(unflagOps), flagged: false),
    );
    await _flushBucket(deleteOps, () => b.delete(_refsOf(deleteOps)));
    for (final group in moveGroups.values) {
      final (folder, ops) = group;
      await _flushBucket(
        ops,
        () => b.moveToFolder(_refsOf(ops), folder.toMailboxFolder()),
      );
    }
  }

  List<MessageRef> _refsOf(List<(OutboxOp, MessageRef)> ops) => [
    for (final (_, ref) in ops) ref,
  ];

  /// 执行一个分桶的后端调用：成功移除桶内全部 op，失败则整桶 markFailed（沿用
  /// 每条 op 的 attempts 阈值，下轮再试 / 到阈值丢弃）。
  Future<void> _flushBucket(
    List<(OutboxOp, MessageRef)> ops,
    Future<void> Function() action,
  ) async {
    if (ops.isEmpty) return;
    try {
      await action();
      for (final (op, _) in ops) {
        await _db.outboxDao.remove(op.id);
      }
    } catch (e) {
      debugPrint('flushOutbox: 批量推送失败（${ops.length} 条）: $e');
      for (final (op, _) in ops) {
        await _db.outboxDao.markFailed(op.id, e.toString());
      }
    }
  }

  Future<MessageRef?> _refForMessage(String messageId) async {
    final m = await _db.messageDao.getMessage(messageId);
    if (m == null) return null;
    return _refForStoredMessage(m);
  }

  Future<MessageRef?> _refForStoredMessage(Message m) async {
    if (m.gmailMessageId != null) {
      final folder = await _db.folderDao.getFolder(m.folderId);
      return GmailRef(
        messageId: m.gmailMessageId!,
        labelId: folder?.remoteId ?? '',
        threadId: m.threadKey,
      );
    }
    if (m.graphMessageId != null) {
      final folder = await _db.folderDao.getFolder(m.folderId);
      return GraphRef(
        messageId: m.graphMessageId!,
        folderId: folder?.remoteId ?? '',
      );
    }
    if (m.imapUid != null && m.imapUidValidity != null) {
      final folder = await _db.folderDao.getFolder(m.folderId);
      if (folder == null) return null;
      return ImapRef(
        folderPath: folder.remoteId,
        uid: m.imapUid!,
        uidValidity: m.imapUidValidity!,
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> _refPayloadForMessage(Message message) async {
    final ref = await _refForStoredMessage(message);
    return _refToPayload(ref);
  }

  Map<String, dynamic>? _refToPayload(MessageRef? ref) {
    return switch (ref) {
      GraphRef(:final messageId, :final folderId) => {
        'type': 'graph',
        'messageId': messageId,
        'folderId': folderId,
      },
      GmailRef(:final messageId, :final labelId, :final threadId) => {
        'type': 'gmail',
        'messageId': messageId,
        'labelId': labelId,
        'threadId': ?threadId,
      },
      ImapRef(:final folderPath, :final uid, :final uidValidity) => {
        'type': 'imap',
        'folderPath': folderPath,
        'uid': uid,
        'uidValidity': uidValidity,
      },
      null => null,
    };
  }

  MessageRef? _refFromPayload(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['type'] as String?;
    switch (type) {
      case 'graph':
        final messageId = raw['messageId'] as String?;
        if (messageId == null || messageId.isEmpty) return null;
        return GraphRef(
          messageId: messageId,
          folderId: raw['folderId'] as String? ?? '',
        );
      case 'gmail':
        final messageId = raw['messageId'] as String?;
        if (messageId == null || messageId.isEmpty) return null;
        return GmailRef(
          messageId: messageId,
          labelId: raw['labelId'] as String? ?? '',
          threadId: raw['threadId'] as String?,
        );
      case 'imap':
        final folderPath = raw['folderPath'] as String?;
        final uid = raw['uid'] as int?;
        final uidValidity = raw['uidValidity'] as int?;
        if (folderPath == null || uid == null || uidValidity == null) {
          return null;
        }
        return ImapRef(
          folderPath: folderPath,
          uid: uid,
          uidValidity: uidValidity,
        );
      default:
        return null;
    }
  }

  Future<Folder?> _folderByType(String accountId, FolderType folderType) async {
    final folders = await _db.folderDao.getFolders(accountId);
    for (final folder in folders) {
      if (folder.folderType == folderType) return folder;
    }
    return null;
  }

  String _folderTypeLabel(FolderType folderType) {
    return switch (folderType) {
      FolderType.inbox => '收件箱',
      FolderType.sent => '已发送',
      FolderType.drafts => '草稿',
      FolderType.trash => '废纸篓',
      FolderType.spam => '垃圾邮件',
      FolderType.archive => '归档',
      FolderType.custom => '自定义',
    };
  }

  /// 断开所有后端连接。
  Future<void> dispose() async {
    for (final t in _syncDebounce.values) {
      t.cancel();
    }
    _syncDebounce.clear();
    _backendQueues.clear();
    for (final backend in _backends.values) {
      await backend.disconnect();
    }
    _backends.clear();
  }

  /// 同步单个账户，限制下载邮件数量（用于首次同步）。
  Future<void> syncAccountWithLimit(
    AccountConfig account,
    int messageLimit, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      final backend = await _getBackend(account);

      onProgress?.call(0.2);
      // 1. 拉取文件夹列表
      final folders = await backend.listFolders();

      onProgress?.call(0.3);
      // 2. 持久化文件夹
      for (final folder in folders) {
        var existing = await _db.folderDao.getByRemoteId(
          account.id,
          folder.remoteId,
        );

        if (existing == null) {
          final folderId = id_gen.generateId();
          await _db.folderDao.upsertFolder(
            FoldersCompanion.insert(
              id: folderId,
              accountId: account.id,
              remoteId: folder.remoteId,
              displayName: folder.displayName,
              folderType: folder.type,
              unreadCount: Value(folder.unreadCount),
              totalCount: Value(folder.totalCount),
              sortIndex: Value(_folderSortIndex(folder.type)),
            ),
          );
          existing = await _db.folderDao.getFolder(folderId);
        }
      }

      onProgress?.call(0.4);
      // 3. 同步收件箱（限制数量）
      final inboxFolder = folders
          .where((f) => f.type == FolderType.inbox)
          .firstOrNull;
      if (inboxFolder != null) {
        final dbFolder = await _db.folderDao.getByRemoteId(
          account.id,
          inboxFolder.remoteId,
        );
        if (dbFolder != null) {
          await _syncFolderWithLimit(
            account,
            dbFolder,
            messageLimit,
            onProgress,
          );
        }
      } else {
        onProgress?.call(1.0);
      }
    } catch (e) {
      debugPrint('同步账户失败: $e');
      rethrow;
    }
  }

  /// 同步单个文件夹（限制数量）。
  Future<void> _syncFolderWithLimit(
    AccountConfig account,
    Folder folder,
    int messageLimit,
    void Function(double progress)? onProgress,
  ) async {
    final backend = await _getBackend(account);

    onProgress?.call(0.5);

    // 获取同步状态
    final syncState = await _db.messageDao.getSyncState(folder.id);
    final token = syncState?.deltaLink != null
        ? SyncToken(syncState!.deltaLink!)
        : null;

    // 执行增量同步
    final result = await backend.syncDelta(folder.toMailboxFolder(), token);

    onProgress?.call(0.7);

    // 处理删除
    if (result.removedRefs.isNotEmpty) {
      final removedIds = <String>[];
      for (final ref in result.removedRefs) {
        if (ref is ImapRef) {
          final msg = await _db.messageDao.getByImapUid(folder.id, ref.uid);
          if (msg != null) removedIds.add(msg.id);
        } else if (ref is GraphRef) {
          final msg = await _db.messageDao.getByGraphId(
            account.id,
            ref.messageId,
          );
          if (msg != null) removedIds.add(msg.id);
        } else if (ref is GmailRef) {
          final msg = await _db.messageDao.getByGmailId(
            account.id,
            ref.messageId,
          );
          if (msg != null) removedIds.add(msg.id);
        }
      }
      if (removedIds.isNotEmpty) {
        await _db.messageDao.deleteMessages(removedIds);
      }
    }

    onProgress?.call(0.8);

    // 处理新增/更新（限制数量）
    final messagesToSync = result.added.take(messageLimit).toList();
    await _persistMessages(messagesToSync, folder);

    // 应用入站标志变更（仅 flags，不覆盖其它列）。
    await _applyFlagUpdates(result.updated, folder, account);

    onProgress?.call(0.9);

    // 更新同步状态
    if (result.newToken != null) {
      await _db.messageDao.upsertSyncState(
        SyncStatesCompanion.insert(
          folderId: folder.id,
          deltaLink: Value(result.newToken!.value),
          lastSyncAt: Value(DateTime.now()),
        ),
      );
    }

    onProgress?.call(1.0);
  }
}

/// Folder 扩展：转换为 MailboxFolder。
extension FolderExt on Folder {
  MailboxFolder toMailboxFolder() {
    return MailboxFolder(
      id: id,
      accountId: accountId,
      remoteId: remoteId,
      displayName: displayName,
      type: folderType,
      unreadCount: unreadCount,
      totalCount: totalCount,
    );
  }
}

/// 单账户后端访问串行队列。
///
/// 同一时刻只跑一个任务；任务结束后**先**取高优先级（用户点开取正文），
/// 再取低优先级（后台预取）。这样后台预取大量入队时，用户点开仍能尽快插队执行。
class _AccountBackendQueue {
  final List<_QueuedTask<dynamic>> _high = [];
  final List<_QueuedTask<dynamic>> _low = [];
  bool _running = false;

  Future<T> add<T>(Future<T> Function() action, {required bool highPriority}) {
    final task = _QueuedTask<T>(action);
    (highPriority ? _high : _low).add(task);
    _drain();
    return task.completer.future;
  }

  void _drain() {
    if (_running) return;
    _running = true;
    Future<void>(() async {
      while (_high.isNotEmpty || _low.isNotEmpty) {
        final task = _high.isNotEmpty ? _high.removeAt(0) : _low.removeAt(0);
        await task.run();
      }
    }).whenComplete(() => _running = false);
  }
}

class _QueuedTask<T> {
  _QueuedTask(this.action);

  final Future<T> Function() action;
  final Completer<T> completer = Completer<T>();

  Future<void> run() async {
    try {
      final result = await action();
      if (!completer.isCompleted) completer.complete(result);
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
  }
}
