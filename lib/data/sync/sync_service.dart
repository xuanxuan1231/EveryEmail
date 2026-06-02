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

  /// 同步账户：拉取文件夹列表和初始邮件。
  Future<void> syncAccount(AccountConfig account) async {
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

  /// 断开所有后端连接。
  Future<void> dispose() async {
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
