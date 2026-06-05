import 'dart:async';

import 'package:enough_mail/enough_mail.dart' as em;

import '../../../domain/enums/account_enums.dart';
import '../../../domain/enums/message_enums.dart';
import '../../../domain/models/account_config.dart';
import '../../../domain/models/mail_address.dart';
import '../../../domain/models/mailbox_folder.dart';
import '../../../domain/models/message_envelope.dart';
import '../../../domain/models/message_ref.dart';
import '../../../domain/models/mime_content.dart';
import '../mail_backend.dart';
import '../sync_types.dart';
import '../token_provider.dart';

/// IMAP 后端实现（基于 enough_mail 高层 MailClient）。
///
/// 注意：enough_mail 的 MailClient 是高层 API，直接操作 MimeMessage 对象，
/// 而非底层的 UID。这个实现是简化版，足以演示架构但需后续优化。
class ImapMailBackend implements MailBackend {
  ImapMailBackend({
    required this.account,
    required this.password,
    this.tokenProvider,
  });

  final AccountConfig account;
  final String? password;
  final AccessTokenProvider? tokenProvider;

  em.MailClient? _client;

  /// uidValidity 变更/首次同步时全量重建拉取的最大封数。
  static const int _fullResyncLimit = 200;

  /// 增量同步中拉取最新邮件（筛新邮件）的封数上限。
  static const int _newFetchLimit = 100;

  @override
  AccountType get type => account.type;

  @override
  bool get supportsIdle => true;

  @override
  Future<void> connect() async {
    if (_client != null) return;

    final imap = account.imap;
    if (imap == null) {
      throw const MailBackendException('IMAP 配置缺失');
    }

    // 构造 MailAccount（enough_mail 需要完整的账户配置）
    final mailAccount = em.MailAccount.fromManualSettings(
      name: account.displayName,
      email: account.email,
      incomingHost: imap.host,
      outgoingHost: account.smtp?.host ?? 'smtp.example.com',
      password: password ?? '',
      userName: account.email,
      incomingPort: imap.port,
      outgoingPort: account.smtp?.port ?? 465,
      incomingSocketType: _mapSocketType(imap.socketType),
      outgoingSocketType: _mapSocketType(account.smtp?.socketType ?? SocketType.ssl),
    );

    _client = em.MailClient(mailAccount, isLogEnabled: false);

    try {
      await _client!.connect();
    } on em.MailException catch (e) {
      _client = null;
      throw MailAuthException('IMAP 连接失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
  }

  @override
  Future<List<MailboxFolder>> listFolders() async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    try {
      final mailboxes = await client.listMailboxes();
      return mailboxes.map(_mapMailbox).toList();
    } on em.MailException catch (e) {
      throw MailBackendException('列出文件夹失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<List<MessageEnvelope>> fetchEnvelopes(
    MailboxFolder folder, {
    PageCursor cursor = PageCursor.start,
    int limit = 50,
  }) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    try {
      // 选择邮箱（通过路径查找）
      final mailboxes = client.mailboxes;
      if (mailboxes == null) throw const MailBackendException('邮箱列表未加载');

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == folder.remoteId,
        orElse: () => throw MailBackendException('文件夹不存在: ${folder.remoteId}'),
      );
      final selected = await client.selectMailbox(mailbox);
      final uidValidity = selected.uidValidity ?? 0;

      // enough_mail 的 fetchMessages 默认拉取最新 N 封
      final messages = await client.fetchMessages(count: limit);
      return messages
          .map((m) => _mapMessage(m, folder, uidValidity: uidValidity))
          .toList();
    } on em.MailException catch (e) {
      throw MailBackendException('拉取信封失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<MimeContent> fetchMessageContent(MessageRef ref) async {
    if (ref is! ImapRef) {
      throw MailBackendException('ImapMailBackend 需要 ImapRef');
    }

    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    try {
      // 选择邮箱
      final mailboxes = client.mailboxes;
      if (mailboxes == null) throw const MailBackendException('邮箱列表未加载');

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == ref.folderPath,
        orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
      );
      await client.selectMailbox(mailbox);

      // 简化：通过 UID 查找消息（需要先 fetchMessages 再过滤）
      // 生产环境应缓存 MimeMessage 对象或用底层 ImapClient
      final messages = await client.fetchMessages(count: 100);
      final msg = messages.cast<em.MimeMessage?>().firstWhere(
            (m) => m?.uid == ref.uid,
            orElse: () => null,
          );

      if (msg == null) {
        throw const MailBackendException('邮件未找到');
      }

      return _mapMimeContent(msg);
    } on em.MailException catch (e) {
      throw MailBackendException('拉取正文失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<List<int>> fetchAttachmentBytes(MessageRef ref, String partId) async {
    throw UnimplementedError('附件下载待实现');
  }

  @override
  Future<SyncResult> syncDelta(MailboxFolder folder, SyncToken? token) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    try {
      final mailboxes = client.mailboxes;
      if (mailboxes == null) throw const MailBackendException('邮箱列表未加载');

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == folder.remoteId,
        orElse: () => throw MailBackendException('文件夹不存在: ${folder.remoteId}'),
      );

      // 服务端是否支持 CONDSTORE/QRESYNC，决定能否做 modseq 标志增量。
      // 不支持时仍可工作：退化为"拉最新 N 封 + upsert 覆盖标志"。
      var supportsCondStore = false;
      em.ImapClient? imap;
      try {
        imap = client.lowLevelIncomingMailClient as em.ImapClient;
        supportsCondStore = imap.serverInfo.supports('CONDSTORE') ||
            imap.serverInfo.supportsQresync;
      } catch (_) {
        supportsCondStore = false;
      }

      // 选择邮箱（支持时开 CONDSTORE 以拿到 highestModSequence）。
      final selected = await client.selectMailbox(
        mailbox,
        enableCondStore: supportsCondStore,
      );
      final curUidValidity = selected.uidValidity ?? 0;
      final curUidNext = selected.uidNext ?? 0;
      final curModSeq = selected.highestModSequence;

      final prev = _ImapSyncCursor.parse(token?.value);
      final newToken = _ImapSyncCursor(
        uidValidity: curUidValidity,
        uidNext: curUidNext,
        modSeq: curModSeq,
      ).toToken();

      // 无游标 / uidValidity 变更 → 整文件夹失效，全量重建。
      if (prev == null || prev.uidValidity != curUidValidity) {
        final messages = await client.fetchMessages(count: _fullResyncLimit);
        final added = messages
            .map((m) => _mapMessage(m, folder, uidValidity: curUidValidity))
            .toList();
        return SyncResult(added: added, newToken: newToken);
      }

      final added = <MessageEnvelope>[];
      final updated = <MessageEnvelope>[];

      // 1) 新邮件：UID >= 上次 uidNext。取最新 N 封后按 UID 过滤。
      //    uidNext 未知（0）时也拉一次，保证不漏新邮件（退化为全量覆盖）。
      if (curUidNext == 0 || curUidNext > prev.uidNext) {
        final recent = await client.fetchMessages(count: _newFetchLimit);
        for (final m in recent) {
          if ((m.uid ?? 0) >= prev.uidNext) {
            added.add(_mapMessage(m, folder, uidValidity: curUidValidity));
          }
        }
      }

      // 2) 标志变更：CONDSTORE CHANGEDSINCE 只取自上次 modseq 以来变动的 FLAGS。
      //    仅含 ref+flags，由 SyncService 按 ref 做 flags-only 更新。
      if (supportsCondStore && imap != null && prev.modSeq != null) {
        // 直接用底层 ImapClient 发 CHANGEDSINCE FETCH，绕过了 MailClient 的锁；
        // 若此刻正在 IDLE 轮询，先暂停避免命令流冲突，取完再恢复。
        final wasPolling = client.isPolling();
        if (wasPolling) await client.stopPolling();
        try {
          final result = await imap.uidFetchMessages(
            em.MessageSequence.fromAll(),
            '(UID FLAGS)',
            changedSinceModSequence: prev.modSeq,
          );
          for (final m in result.messages) {
            final uid = m.uid ?? 0;
            if (uid == 0 || uid >= prev.uidNext) continue; // 新邮件已走 added
            updated.add(
              MessageEnvelope(
                localId: '',
                ref: ImapRef(
                  folderPath: folder.remoteId,
                  uid: uid,
                  uidValidity: curUidValidity,
                ),
                accountId: account.id,
                folderId: folder.id,
                subject: '', // updated 仅用于 flags-only 更新，其余字段不参与持久化
                date: m.decodeDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
                flags: _mapFlags(m.flags),
              ),
            );
          }
        } finally {
          if (wasPolling) await client.startPolling();
        }
      }

      return SyncResult(added: added, updated: updated, newToken: newToken);
    } on em.MailException catch (e) {
      throw MailBackendException('同步失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<void> markRead(List<MessageRef> refs, {required bool read}) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    for (final ref in refs) {
      if (ref is! ImapRef) continue;
      final mailboxes = client.mailboxes;
      if (mailboxes == null) {
        throw const MailBackendException('邮箱列表未加载');
      }

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == ref.folderPath,
        orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
      );
      await client.selectMailbox(mailbox);

      final sequence = em.MessageSequence.fromId(ref.uid, isUid: true);
      if (read) {
        await client.store(sequence, [em.MessageFlags.seen], action: em.StoreAction.add);
      } else {
        await client.markUnseen(sequence);
      }
    }
  }

  @override
  Future<void> markFlagged(List<MessageRef> refs, {required bool flagged}) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    for (final ref in refs) {
      if (ref is! ImapRef) continue;
      final mailboxes = client.mailboxes;
      if (mailboxes == null) {
        throw const MailBackendException('邮箱列表未加载');
      }

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == ref.folderPath,
        orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
      );
      await client.selectMailbox(mailbox);

      final sequence = em.MessageSequence.fromId(ref.uid, isUid: true);
      if (flagged) {
        await client.store(sequence, [em.MessageFlags.flagged], action: em.StoreAction.add);
      } else {
        await client.markUnflagged(sequence);
      }
    }
  }

  @override
  Future<void> moveToFolder(List<MessageRef> refs, MailboxFolder target) async {
    throw UnimplementedError('移动邮件待实现');
  }

  @override
  Future<void> delete(List<MessageRef> refs) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    for (final ref in refs) {
      if (ref is! ImapRef) continue;
      try {
        // 选择邮箱
        final mailboxes = client.mailboxes;
        if (mailboxes == null) continue;

        final mailbox = mailboxes.firstWhere(
          (mb) => mb.path == ref.folderPath,
          orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
        );
        await client.selectMailbox(mailbox);

        final sequence = em.MessageSequence.fromId(ref.uid, isUid: true);
        await client.store(sequence, [em.MessageFlags.deleted], action: em.StoreAction.add);
      } catch (_) {}
    }
  }

  @override
  Stream<MailboxEvent> watch(MailboxFolder folder) {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    // 真 IDLE：MailClient.startPolling() 在服务端支持时使用 IMAP IDLE，
    // 通过 eventBus 派发新邮件/标志变更/过期/重连事件，映射到 MailboxEvent。
    final controller = StreamController<MailboxEvent>();
    final subs = <StreamSubscription<dynamic>>[];

    Future<void> startIdle() async {
      final mailboxes = client.mailboxes;
      if (mailboxes == null) throw const MailBackendException('邮箱列表未加载');
      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == folder.remoteId,
        orElse: () => throw MailBackendException('文件夹不存在: ${folder.remoteId}'),
      );
      final selected = await client.selectMailbox(mailbox);
      final uidValidity = selected.uidValidity ?? 0;

      subs.add(client.eventBus.on<em.MailLoadEvent>().listen((e) {
        controller.add(
          MailArrivedEvent(
            [_mapMessage(e.message, folder, uidValidity: uidValidity)],
          ),
        );
      }));
      subs.add(client.eventBus.on<em.MailUpdateEvent>().listen((e) {
        controller.add(
          MailUpdatedEvent(
            [_mapMessage(e.message, folder, uidValidity: uidValidity)],
          ),
        );
      }));
      subs.add(client.eventBus.on<em.MailVanishedEvent>().listen((_) {
        // expunge 序列难直接映射 UID，发文件夹变更让上层做一次重同步。
        controller.add(FolderChangedEvent(folder));
      }));
      subs.add(client.eventBus
          .on<em.MailConnectionReEstablishedEvent>()
          .listen((_) {
        // 断线重连期间可能漏掉变更，触发一次重同步兜底。
        controller.add(FolderChangedEvent(folder));
      }));

      await client.startPolling();
    }

    controller
      ..onListen = () {
        startIdle().catchError(controller.addError);
      }
      ..onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
        try {
          await client.stopPollingIfNeeded();
        } catch (_) {}
      };

    return controller.stream;
  }

  MailboxFolder _mapMailbox(em.Mailbox mb) {
    return MailboxFolder(
      id: '', // 由仓储层填充
      accountId: account.id,
      remoteId: mb.path,
      displayName: mb.name,
      type: _inferFolderType(mb),
      unreadCount: mb.messagesUnseen,
      totalCount: mb.messagesExists,
    );
  }

  FolderType _inferFolderType(em.Mailbox mb) {
    if (mb.isInbox) return FolderType.inbox;
    if (mb.isSent) return FolderType.sent;
    if (mb.isDrafts) return FolderType.drafts;
    if (mb.isTrash) return FolderType.trash;
    if (mb.isJunk) return FolderType.spam;
    if (mb.isArchive) return FolderType.archive;
    return FolderType.custom;
  }

  MessageEnvelope _mapMessage(
    em.MimeMessage msg,
    MailboxFolder folder, {
    int uidValidity = 0,
  }) {
    final uid = msg.uid ?? 0;

    return MessageEnvelope(
      localId: '', // 由仓储层填充
      ref: ImapRef(folderPath: folder.remoteId, uid: uid, uidValidity: uidValidity),
      accountId: account.id,
      folderId: folder.id,
      subject: msg.decodeSubject() ?? '',
      date: msg.decodeDate() ?? DateTime.now(),
      from: _mapAddress(msg.from?.firstOrNull),
      to: msg.to?.map(_mapAddress).whereType<MailAddress>().toList() ?? [],
      cc: msg.cc?.map(_mapAddress).whereType<MailAddress>().toList() ?? [],
      preview: msg.decodeTextPlainPart()?.substring(0, 200.clamp(0, msg.decodeTextPlainPart()?.length ?? 0)) ?? '',
      flags: _mapFlags(msg.flags),
      hasAttachments: msg.hasAttachments(),
      threadKey: msg.decodeHeaderValue('references'),
      messageIdHeader: msg.decodeHeaderValue('message-id'),
    );
  }

  MailAddress? _mapAddress(em.MailAddress? addr) {
    if (addr == null || addr.email.isEmpty) return null;
    return MailAddress(email: addr.email, name: addr.personalName);
  }

  Set<MessageFlag> _mapFlags(List<String>? flags) {
    if (flags == null) return {};
    final result = <MessageFlag>{};
    for (final f in flags) {
      final lower = f.toLowerCase();
      if (lower.contains('seen')) result.add(MessageFlag.seen);
      if (lower.contains('flagged')) result.add(MessageFlag.flagged);
      if (lower.contains('answered')) result.add(MessageFlag.answered);
      if (lower.contains('draft')) result.add(MessageFlag.draft);
      if (lower.contains('deleted')) result.add(MessageFlag.deleted);
    }
    return result;
  }

  MimeContent _mapMimeContent(em.MimeMessage msg) {
    final attachments = <MailAttachment>[];
    final parts = msg.findContentInfo(disposition: em.ContentDisposition.attachment);
    for (final part in parts) {
      attachments.add(MailAttachment(
        partId: part.fetchId,
        mimeType: part.contentType?.mediaType.text ?? 'application/octet-stream',
        filename: part.contentType?.parameters['name'],
        size: part.size,
      ));
    }

    return MimeContent(
      plainText: msg.decodeTextPlainPart(),
      htmlBody: msg.decodeTextHtmlPart(),
      attachments: attachments,
    );
  }

  em.SocketType _mapSocketType(SocketType type) {
    switch (type) {
      case SocketType.ssl:
        return em.SocketType.ssl;
      case SocketType.starttls:
        return em.SocketType.starttls;
      case SocketType.plain:
        return em.SocketType.plain;
    }
  }
}

/// IMAP 增量游标，序列化进不透明 [SyncToken]：`uidvalidity=..;uidnext=..;modseq=..`。
/// 与 [sync_types.dart] 中 SyncToken 的文档约定一致（IMAP: 序列化的 uidNext/modseq）。
class _ImapSyncCursor {
  const _ImapSyncCursor({
    required this.uidValidity,
    required this.uidNext,
    this.modSeq,
  });

  final int uidValidity;
  final int uidNext;
  final int? modSeq;

  static _ImapSyncCursor? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    int? uidValidity;
    int? uidNext;
    int? modSeq;
    for (final part in value.split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final key = part.substring(0, i);
      final v = int.tryParse(part.substring(i + 1));
      switch (key) {
        case 'uidvalidity':
          uidValidity = v;
          break;
        case 'uidnext':
          uidNext = v;
          break;
        case 'modseq':
          modSeq = v;
          break;
      }
    }
    if (uidValidity == null || uidNext == null) return null;
    return _ImapSyncCursor(
      uidValidity: uidValidity,
      uidNext: uidNext,
      modSeq: modSeq,
    );
  }

  SyncToken toToken() {
    final modSeqPart = modSeq != null ? ';modseq=$modSeq' : '';
    return SyncToken('uidvalidity=$uidValidity;uidnext=$uidNext$modSeqPart');
  }
}
