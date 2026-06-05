import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/id_generator.dart' as id_gen;
import '../../domain/enums/account_enums.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/account_config.dart';
import '../../domain/models/mailbox_folder.dart';
import '../../domain/models/message_envelope.dart';
import '../../domain/models/message_ref.dart';
import '../auth/oauth_service.dart';
import '../backends/graph/graph_mail_backend.dart';
import '../backends/imap/imap_mail_backend.dart';
import '../backends/mail_backend.dart';
import '../backends/sync_types.dart';
import '../backends/token_provider.dart';
import '../local/database/app_database.dart';
import '../secure/token_store.dart';

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
  })  : _db = db,
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
      case AccountType.genericImap:
        // IMAP 后端
        String? password;
        if (account.secretRef != null) {
          password = await _tokenStore.readPassword(account.secretRef!);
        }

        AccessTokenProvider? tokenProvider;
        if (account.type == AccountType.gmailOAuth && account.secretRef != null) {
          tokenProvider = () => getAccessToken(account);
        }

        backend = ImapMailBackend(
          account: account,
          password: password,
          tokenProvider: tokenProvider,
        );
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

  /// 每账户同步串行链：保证同一账户不并发同步。
  final Map<String, Future<void>> _accountSyncChain = {};

  /// 每账户合并触发的去抖定时器。
  final Map<String, Timer> _syncDebounce = {};

  /// 合并触发窗口：把一阵触发（Graph 一封新邮件连发的多条 updated 静默推送、
  /// 或 IMAP IDLE 连续事件）压成一次 [syncAccount]。
  static const Duration _syncDebounceWindow = Duration(seconds: 3);

  /// 请求一次（去抖 + 串行）账户同步。突发触发场景（FCM 静默数据消息 / IDLE 事件）
  /// 应走这里而非直接 [syncAccount]，避免短时间内重复全量同步。
  void requestSync(AccountConfig account) {
    _syncDebounce[account.id]?.cancel();
    _syncDebounce[account.id] = Timer(_syncDebounceWindow, () {
      _syncDebounce.remove(account.id);
      unawaited(syncAccount(account).catchError((Object e) {
        debugPrint('requestSync: 同步失败: $e');
      }));
    });
  }

  /// 同步账户：拉取文件夹列表和初始邮件。
  ///
  /// 同一账户的并发调用（手动刷新 / FCM 静默推送 / IMAP IDLE 触发）会被串行化，
  /// 避免同时操作同一后端连接造成命令流交错。
  Future<void> syncAccount(AccountConfig account) async {
    final prev = _accountSyncChain[account.id];
    final completer = Completer<void>();
    _accountSyncChain[account.id] = completer.future;
    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }
    try {
      await _syncAccountInner(account);
    } finally {
      if (identical(_accountSyncChain[account.id], completer.future)) {
        _accountSyncChain.remove(account.id);
      }
      completer.complete();
    }
  }

  Future<void> _syncAccountInner(AccountConfig account) async {
    // 先把本地待推送变更（已读/标星/移动/删除等）刷到服务端，
    // 否则随后的 delta 会用服务端旧值覆盖刚改完的本地新值。
    await flushOutbox(account);

    final backend = await _getBackend(account);

    // 1. 拉取文件夹列表
    final folders = await backend.listFolders();

    // 2. 持久化文件夹
    for (final folder in folders) {
      // 检查是否已存在
      var existing = await _db.folderDao.getByRemoteId(account.id, folder.remoteId);

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

      // 3. 同步文件夹邮件（inbox、sent、drafts）
      if (folder.type == FolderType.inbox ||
          folder.type == FolderType.sent ||
          folder.type == FolderType.drafts) {
        await syncFolder(account, existing!);
      }
    }
  }

  /// 同步单个文件夹：增量拉取邮件。
  Future<void> syncFolder(AccountConfig account, Folder folder) async {
    final backend = await _getBackend(account);

    // 获取同步游标
    final syncState = await _db.messageDao.getSyncState(folder.id);
    final token = syncState?.deltaLink != null ? SyncToken(syncState!.deltaLink!) : null;

    // 执行增量同步
    final result = await backend.syncDelta(
      folder.toMailboxFolder(),
      token,
    );

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
          final msg = await _db.messageDao.getByGraphId(account.id, ref.messageId);
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
  }

  /// 持久化邮件列表到数据库。
  Future<void> _persistMessages(List<MessageEnvelope> envelopes, Folder folder) async {
    final companions = <MessagesCompanion>[];

    for (final envelope in envelopes) {
      // 查找是否已存在
      Message? existing;
      if (envelope.ref is ImapRef) {
        final ref = envelope.ref as ImapRef;
        existing = await _db.messageDao.getByImapUid(folder.id, ref.uid);
      } else if (envelope.ref is GraphRef) {
        final ref = envelope.ref as GraphRef;
        existing = await _db.messageDao.getByGraphId(envelope.accountId, ref.messageId);
      }

      final messageId = existing?.id ?? id_gen.generateId();
      final ref = envelope.ref;

      companions.add(
        MessagesCompanion(
          id: Value(messageId),
          accountId: Value(envelope.accountId),
          folderId: Value(folder.id),
          imapUid: ref is ImapRef ? Value(ref.uid) : const Value.absent(),
          imapUidValidity: ref is ImapRef ? Value(ref.uidValidity) : const Value.absent(),
          graphMessageId: ref is GraphRef ? Value(ref.messageId) : const Value.absent(),
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
    final jsonList = recipients.map((r) {
      final name = (r.name ?? '').replaceAll('"', '\\"').replaceAll('\n', ' ');
      final email = (r.email ?? '').replaceAll('"', '\\"');
      return '{"name":"$name","email":"$email"}';
    }).join(',');

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
  /// 之后 `MessageDao.watchBody` 会让 UI 自动刷新预览。
  ///
  /// 幂等：正文行只在成功下载后写入，故"已存在且非 notDownloaded"即视为已下载，
  /// 默认跳过；[force] 为 true 时强制重新拉取（手动重试 / 重新下载）。失败向上抛。
  Future<void> fetchMessageBody(String messageId, {bool force = false}) async {
    final message = await _db.messageDao.getMessage(messageId);
    if (message == null) return;

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

    final remoteId = message.graphMessageId ?? message.imapUid?.toString();
    if (remoteId == null) {
      // 本地草稿等没有远端引用，仅更新本地。
      await _db.messageDao.updateFlags(messageId, newBitmask);
      return;
    }

    // 与已有相同 (op, messageId) 的待推送条目去重：保留最新意图即可。
    final opType = _opTypeFor(flag, value);
    if (opType == null) {
      await _db.messageDao.updateFlags(messageId, newBitmask);
      return;
    }

    await _db.transaction(() async {
      await _db.messageDao.updateFlags(messageId, newBitmask);
      await _db.outboxDao.removeForMessage(message.accountId, messageId, flag);
      await _db.outboxDao.enqueue(
        OutboxOpsCompanion.insert(
          accountId: message.accountId,
          opType: opType,
          payload: Value(jsonEncode({'messageId': messageId})),
        ),
      );
    });
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

    for (final op in pending) {
      // 失败次数超过阈值就丢弃，避免坏条目无限阻塞队列。
      // 5 次大致覆盖临时网络抖动 + 一两次令牌刷新失败的场景。
      if (op.attempts >= 5) {
        debugPrint('flushOutbox: ${op.opType} 已重试 ${op.attempts} 次，丢弃');
        await _db.outboxDao.remove(op.id);
        continue;
      }

      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        final messageId = payload['messageId'] as String?;
        if (messageId == null) {
          await _db.outboxDao.remove(op.id);
          continue;
        }
        final ref = await _refForMessage(messageId);
        if (ref == null) {
          // 邮件已不存在；丢弃避免无限重试。
          await _db.outboxDao.remove(op.id);
          continue;
        }

        switch (op.opType) {
          case 'markRead':
            await backend.markRead([ref], read: true);
            break;
          case 'markUnread':
            await backend.markRead([ref], read: false);
            break;
          case 'flag':
            await backend.markFlagged([ref], flagged: true);
            break;
          case 'unflag':
            await backend.markFlagged([ref], flagged: false);
            break;
          default:
            // 其它类型暂未实现，先丢弃避免阻塞队列。
            debugPrint('flushOutbox: 未支持的 opType=${op.opType}, 丢弃');
            await _db.outboxDao.remove(op.id);
            continue;
        }
        await _db.outboxDao.remove(op.id);
      } catch (e) {
        debugPrint('flushOutbox: 推送 ${op.opType} 失败: $e');
        await _db.outboxDao.markFailed(op.id, e.toString());
      }
    }
  }

  Future<MessageRef?> _refForMessage(String messageId) async {
    final m = await _db.messageDao.getMessage(messageId);
    if (m == null) return null;
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

  /// 断开所有后端连接。
  Future<void> dispose() async {
    for (final t in _syncDebounce.values) {
      t.cancel();
    }
    _syncDebounce.clear();
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
        var existing = await _db.folderDao.getByRemoteId(account.id, folder.remoteId);

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
      final inboxFolder = folders.where((f) => f.type == FolderType.inbox).firstOrNull;
      if (inboxFolder != null) {
        final dbFolder = await _db.folderDao.getByRemoteId(account.id, inboxFolder.remoteId);
        if (dbFolder != null) {
          await _syncFolderWithLimit(account, dbFolder, messageLimit, onProgress);
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
    final token = syncState?.deltaLink != null ? SyncToken(syncState!.deltaLink!) : null;

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
          final msg = await _db.messageDao.getByGraphId(account.id, ref.messageId);
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
