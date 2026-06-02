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
      await client.selectMailbox(mailbox);

      // enough_mail 的 fetchMessages 默认拉取最新 N 封
      final messages = await client.fetchMessages(count: limit);
      return messages.map((m) => _mapMessage(m, folder)).toList();
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
      // 选择邮箱
      final mailboxes = client.mailboxes;
      if (mailboxes == null) throw const MailBackendException('邮箱列表未加载');

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == folder.remoteId,
        orElse: () => throw MailBackendException('文件夹不存在: ${folder.remoteId}'),
      );
      await client.selectMailbox(mailbox);

      // 简化：全量拉取最新邮件
      final messages = await client.fetchMessages(count: 100);
      final envelopes = messages.map((m) => _mapMessage(m, folder)).toList();

      return SyncResult(added: envelopes);
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
        if (read) {
          await client.store(sequence, [em.MessageFlags.seen], action: em.StoreAction.add);
        } else {
          await client.markUnseen(sequence);
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> markFlagged(List<MessageRef> refs, {required bool flagged}) async {
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
        if (flagged) {
          await client.store(sequence, [em.MessageFlags.flagged], action: em.StoreAction.add);
        } else {
          await client.markUnflagged(sequence);
        }
      } catch (_) {}
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
  Stream<MailboxEvent> watch(MailboxFolder folder) async* {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    // 简化：轮询而非真 IDLE（真 IDLE 需要底层 ImapClient + startPolling）
    // 生产环境应使用 client.startPolling() 并映射事件
    yield* Stream.periodic(const Duration(seconds: 30), (_) async {
      // 选择邮箱
      final mailboxes = client.mailboxes;
      if (mailboxes == null) throw const MailBackendException('邮箱列表未加载');

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == folder.remoteId,
        orElse: () => throw MailBackendException('文件夹不存在: ${folder.remoteId}'),
      );
      await client.selectMailbox(mailbox);

      final messages = await client.fetchMessages(count: 20);
      return MailArrivedEvent(messages.map((m) => _mapMessage(m, folder)).toList());
    }).asyncMap((event) => event);
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

  MessageEnvelope _mapMessage(em.MimeMessage msg, MailboxFolder folder) {
    final uid = msg.uid ?? 0;
    // uidValidity 来自 Mailbox，不是 MimeMessage
    // 简化：使用 0 作为占位符，生产环境应从 _client?.selectedMailbox?.uidValidity 获取
    final uidValidity = 0;

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
