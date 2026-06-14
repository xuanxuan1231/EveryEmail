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
import 'imap_thread_key.dart';

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

  /// 当前 IDLE 监听的文件夹路径。同步其它文件夹会临时 SELECT 它们；完成后需要恢复
  /// 到这个文件夹，否则长连接会悄悄变成监听最后同步的文件夹。
  String? _idleFolderPath;

  /// 上次成功(重)连接的时刻。用于 OAuth 连接的过期自愈（见 [isStale]）。
  DateTime? _connectedAt;

  /// uidValidity 变更/首次同步时全量重建拉取的最大封数。
  static const int _fullResyncLimit = 200;

  /// 增量同步中拉取最新邮件（筛新邮件）的封数上限。
  static const int _newFetchLimit = 100;

  /// OAuth 连接的"新鲜期"。enough_mail 的自动重连不会回调 refresh 取新 token
  /// （只有显式 connect() 才会），长连接超过 Google access token 寿命（~1h）后，
  /// 一旦断线自动重连就会拿过期 token 重认证而失败、且不会自愈。故由上层（同步
  /// 协调器）在超过此阈值时主动 [reconnect]，走完整 connect 路径拉取新 token。
  /// 取 40min（< token 寿命）留足余量。密码连接无此问题（[isStale] 恒为 false）。
  static const Duration _oauthConnectionTtl = Duration(minutes: 40);

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

    final outgoingHost = account.smtp?.host ?? 'smtp.example.com';
    final outgoingPort = account.smtp?.port ?? 465;
    final outgoingSocket = _mapSocketType(
      account.smtp?.socketType ?? SocketType.ssl,
    );

    final em.MailAccount mailAccount;
    if (tokenProvider != null) {
      // OAuth（Gmail XOAUTH2）：用 access token 走 OAuth 认证，而非密码。否则
      // enough_mail 会用空密码登录，被服务器拒为「Empty username or password」。
      final accessToken = await tokenProvider!();
      final auth = em.OauthAuthentication(
        account.email,
        _buildOauthToken(accessToken),
      );
      mailAccount = em.MailAccount.fromManualSettingsWithAuth(
        name: account.displayName,
        email: account.email,
        incomingHost: imap.host,
        outgoingHost: outgoingHost,
        auth: auth,
        userName: account.email,
        incomingPort: imap.port,
        outgoingPort: outgoingPort,
        incomingSocketType: _mapSocketType(imap.socketType),
        outgoingSocketType: outgoingSocket,
      );
    } else {
      // 密码 / 应用专用密码。
      mailAccount = em.MailAccount.fromManualSettings(
        name: account.displayName,
        email: account.email,
        incomingHost: imap.host,
        outgoingHost: outgoingHost,
        password: password ?? '',
        userName: account.email,
        incomingPort: imap.port,
        outgoingPort: outgoingPort,
        incomingSocketType: _mapSocketType(imap.socketType),
        outgoingSocketType: outgoingSocket,
      );
    }

    _client = em.MailClient(
      mailAccount,
      isLogEnabled: false,
      // enough_mail 默认响应超时仅 5s、写超时 2s，对移动网络下的 Gmail IMAP
      // （首次 LIST 多标签、大邮箱、拉全文）过于激进，极易 timeout。放宽到更现实的值。
      defaultResponseTimeout: const Duration(seconds: 30),
      defaultWriteTimeout: const Duration(seconds: 15),
      // OAuth：access token 临近过期时，MailClient 在(重)连时回调刷新，统一走
      // tokenProvider（其内部用 refresh token 经 Worker 刷新并缓存）。
      refresh: tokenProvider == null ? null : _refreshOauthToken,
    );

    try {
      await _client!.connect();
      _connectedAt = DateTime.now();
      await _sendImapId();
    } on em.MailException catch (e) {
      _client = null;
      throw MailAuthException('IMAP 连接失败: ${e.message}', cause: e);
    }
  }

  /// 登录后向服务器发送 RFC 2971 ID 命令。
  ///
  /// 网易系（163/126/yeah）的反代收策略要求客户端登录后必须发 ID，否则后续 SELECT
  /// 被拒：「Unsafe Login. Please contact kefu@188.com for help」。网易系强制发送；
  /// 其余服务器仅在声明 ID 能力（[em.ImapServerInfo.supportsId]）时发送。ID 命令为
  /// 可选扩展，失败不致命——吞掉异常，后续 SELECT 由服务器裁定。
  Future<void> _sendImapId() async {
    final client = _client;
    if (client == null) return;
    final incoming = client.lowLevelIncomingMailClient;
    if (incoming is! em.ImapClient) return; // 仅 IMAP（非 POP）

    final host = account.imap?.host.toLowerCase() ?? '';
    final isNetease =
        host.contains('163.com') ||
        host.contains('126.com') ||
        host.contains('yeah.net') ||
        host.contains('netease');
    if (!isNetease && !incoming.serverInfo.supportsId) return;

    try {
      await incoming.id(
        clientId: const em.Id(name: 'EveryEmail', version: '1.0'),
      );
    } catch (_) {
      // ID 失败不致命：不支持的服务器 / 网络抖动时忽略。
    }
  }

  /// OAuth 连接是否已过"新鲜期"，需要重连以刷新 token（见 [_oauthConnectionTtl]）。
  /// 密码连接恒为 false。未连接（无 [_connectedAt]）时也为 false——交由 connect 处理。
  bool get isStale {
    if (tokenProvider == null) return false;
    final at = _connectedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) >= _oauthConnectionTtl;
  }

  /// 断开并以全新的 [em.MailClient] 重连，从而经 [tokenProvider] 取到当前有效的
  /// access token 重新认证。用于规避 enough_mail 自动重连复用过期 token 的问题。
  ///
  /// 注意：会重建 [_client]，任何持有旧 client 引用的进行中操作 / IDLE 订阅都将
  /// 失效——调用方需保证已在账户串行队列上执行，并在重连后重建 IDLE 监听。
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  /// 用一个有效 access token 构造 enough_mail 的 [em.OauthToken]。
  ///
  /// 这里不负责过期管理：把 expiresIn 设得很短，促使 MailClient 在每次(重)连时
  /// 都经 [refresh] 回调向 [tokenProvider] 取当前有效 token（由它判断是否真的需要
  /// 用 refresh token 经 Worker 刷新）。refreshToken/scope 留空即可。
  em.OauthToken _buildOauthToken(String accessToken) => em.OauthToken(
    accessToken: accessToken,
    expiresIn: 60,
    refreshToken: '',
    scope: '',
    tokenType: 'Bearer',
    created: DateTime.now().toUtc(),
  );

  /// MailClient 的 OAuth 刷新回调：token 临近过期时取一个当前有效的 access token。
  Future<em.OauthToken?> _refreshOauthToken(
    em.MailClient client,
    em.OauthToken expiredToken,
  ) async {
    final provider = tokenProvider;
    if (provider == null) return null;
    final accessToken = await provider();
    return _buildOauthToken(accessToken);
  }

  @override
  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    _connectedAt = null;
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
  Future<EnvelopePage> fetchEnvelopes(
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
      final envelopes = messages
          .map((m) => _mapMessage(m, folder, uidValidity: uidValidity))
          .toList();
      // IMAP 暂不支持向更旧分页（始终取最新 N 封），无更旧游标。
      return EnvelopePage(envelopes: envelopes, nextCursor: null);
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
      // 直接打开邮件详情时，后端可能还没列过文件夹（mailboxes 为空，例如本次
      // 连接还没同步过）。按需加载一次，避免误报「邮箱列表未加载」。
      final mailboxes = client.mailboxes ?? await client.listMailboxes();

      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == ref.folderPath,
        orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
      );

      // 直接按 UID 拉取该封邮件的完整内容，而不是拉最新 N 封再筛——后者拉不到
      // 较旧的邮件（不在最新 100 封内）就会误报「邮件未找到」。
      final sequence = em.MessageSequence.fromId(ref.uid, isUid: true);
      final messages = await client.fetchMessageSequence(
        sequence,
        mailbox: mailbox,
        fetchPreference: em.FetchPreference.full,
      );

      if (messages.isEmpty) {
        throw const MailBackendException('邮件未找到');
      }

      return _mapMimeContent(messages.first);
    } on em.MailException catch (e) {
      throw MailBackendException('拉取正文失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<List<int>> fetchAttachmentBytes(MessageRef ref, String partId) async {
    if (ref is! ImapRef) {
      throw MailBackendException('ImapMailBackend 需要 ImapRef');
    }

    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    try {
      // 详情页可能在未列过文件夹时就请求下载，按需加载一次（同 fetchMessageContent）。
      final mailboxes = client.mailboxes ?? await client.listMailboxes();
      final mailbox = mailboxes.firstWhere(
        (mb) => mb.path == ref.folderPath,
        orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
      );
      await client.selectMailbox(mailbox);

      // fetchMessagePart 在 message.uid 非空时发 `UID FETCH <uid> (BODY[<partId>])`，
      // 只需一个带 uid 的占位 MimeMessage；其内部会暂停/恢复 IDLE，IDLE 期间也安全。
      final message = em.MimeMessage()..uid = ref.uid;
      final part = await client.fetchMessagePart(message, partId);

      // 按部件的传输编码（base64/quoted-printable）解码出原始字节。
      final bytes = part.decodeContentBinary();
      if (bytes == null) {
        throw const MailBackendException('附件内容为空或无法解码');
      }
      return bytes;
    } on em.MailException catch (e) {
      throw MailBackendException('下载附件失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<SyncResult> syncDelta(MailboxFolder folder, SyncToken? token) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');
    final wasPollingAtStart = client.isPolling();
    final idleFolderPath = _idleFolderPath;

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
        supportsCondStore =
            imap.serverInfo.supports('CONDSTORE') ||
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
        // 若此刻正在 IDLE，先暂停避免命令流冲突，取完再恢复。
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
    } finally {
      await _restoreIdleMailboxIfNeeded(
        wasPolling: wasPollingAtStart,
        folderPath: idleFolderPath,
      );
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
        await client.store(sequence, [
          em.MessageFlags.seen,
        ], action: em.StoreAction.add);
      } else {
        await client.markUnseen(sequence);
      }
    }
  }

  @override
  Future<void> markFlagged(
    List<MessageRef> refs, {
    required bool flagged,
  }) async {
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
        await client.store(sequence, [
          em.MessageFlags.flagged,
        ], action: em.StoreAction.add);
      } else {
        await client.markUnflagged(sequence);
      }
    }
  }

  @override
  Future<void> moveToFolder(List<MessageRef> refs, MailboxFolder target) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    final mailboxes = client.mailboxes;
    if (mailboxes == null) {
      throw const MailBackendException('邮箱列表未加载');
    }

    final targetMailbox = mailboxes.firstWhere(
      (mb) => mb.path == target.remoteId,
      orElse: () => throw MailBackendException('目标文件夹不存在: ${target.remoteId}'),
    );

    for (final ref in refs) {
      if (ref is! ImapRef) continue;

      final sourceMailbox = mailboxes.firstWhere(
        (mb) => mb.path == ref.folderPath,
        orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
      );
      await client.selectMailbox(sourceMailbox);

      final sequence = em.MessageSequence.fromId(ref.uid, isUid: true);
      await client.moveMessages(sequence, targetMailbox);
    }
  }

  @override
  Future<void> delete(List<MessageRef> refs) async {
    final client = _client;
    if (client == null) throw const MailBackendException('未连接');

    for (final ref in refs) {
      if (ref is! ImapRef) continue;
      // 选择邮箱
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
      await client.store(sequence, [
        em.MessageFlags.deleted,
      ], action: em.StoreAction.add);
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
      _idleFolderPath = folder.remoteId;

      subs.add(
        client.eventBus.on<em.MailLoadEvent>().listen((e) {
          controller.add(
            MailArrivedEvent([
              _mapMessage(e.message, folder, uidValidity: uidValidity),
            ]),
          );
        }),
      );
      subs.add(
        client.eventBus.on<em.MailUpdateEvent>().listen((e) {
          controller.add(
            MailUpdatedEvent([
              _mapMessage(e.message, folder, uidValidity: uidValidity),
            ]),
          );
        }),
      );
      subs.add(
        client.eventBus.on<em.MailVanishedEvent>().listen((_) {
          // expunge 序列难直接映射 UID，发文件夹变更让上层做一次重同步。
          controller.add(FolderChangedEvent(folder));
        }),
      );
      subs.add(
        client.eventBus.on<em.MailConnectionLostEvent>().listen((_) {
          controller.add(FolderChangedEvent(folder));
        }),
      );
      subs.add(
        client.eventBus.on<em.MailConnectionReEstablishedEvent>().listen((_) {
          // 断线重连期间可能漏掉变更，触发一次重同步兜底。
          controller.add(FolderChangedEvent(folder));
        }),
      );

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
        if (_idleFolderPath == folder.remoteId) {
          _idleFolderPath = null;
        }
      };

    return controller.stream;
  }

  Future<void> _restoreIdleMailboxIfNeeded({
    required bool wasPolling,
    required String? folderPath,
  }) async {
    if (!wasPolling || folderPath == null) return;
    if (_idleFolderPath != folderPath) return;
    final client = _client;
    if (client == null) return;

    try {
      final mailboxes = client.mailboxes ?? await client.listMailboxes();
      em.Mailbox? mailbox;
      for (final mb in mailboxes) {
        if (mb.path == folderPath) {
          mailbox = mb;
          break;
        }
      }
      if (mailbox == null) return;

      await client.selectMailbox(mailbox);
      if (!client.isPolling()) {
        await client.startPolling();
      }
    } catch (_) {
      // 恢复 IDLE 失败不应掩盖本次同步结果；上层周期刷新/回前台会重建监听。
    }
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
      ref: ImapRef(
        folderPath: folder.remoteId,
        uid: uid,
        uidValidity: uidValidity,
      ),
      accountId: account.id,
      folderId: folder.id,
      subject: msg.decodeSubject() ?? '',
      date: msg.decodeDate() ?? DateTime.now(),
      from: _mapAddress(msg.from?.firstOrNull),
      to: msg.to?.map(_mapAddress).whereType<MailAddress>().toList() ?? [],
      cc: msg.cc?.map(_mapAddress).whereType<MailAddress>().toList() ?? [],
      preview:
          msg.decodeTextPlainPart()?.substring(
            0,
            200.clamp(0, msg.decodeTextPlainPart()?.length ?? 0),
          ) ??
          '',
      flags: _mapFlags(msg.flags),
      hasAttachments: msg.hasAttachments(),
      threadKey: deriveImapThreadKey(
        references: msg.decodeHeaderValue('references'),
        inReplyTo: msg.decodeHeaderValue('in-reply-to'),
        messageId: msg.decodeHeaderValue('message-id'),
      ),
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
    final parts = msg.findContentInfo(
      disposition: em.ContentDisposition.attachment,
    );
    for (final part in parts) {
      attachments.add(
        MailAttachment(
          partId: part.fetchId,
          mimeType:
              part.contentType?.mediaType.text ?? 'application/octet-stream',
          filename: part.contentType?.parameters['name'],
          size: part.size,
        ),
      );
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
