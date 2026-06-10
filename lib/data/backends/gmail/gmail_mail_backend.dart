import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
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
import 'gmail_batch.dart';

/// Gmail REST API 后端实现。
///
/// 用 Gmail API v1（users/me）替代 IMAP，避免 enough_mail 列表同步整封下载正文的
/// 开销。列表只取 `format=metadata`（头 + 服务端 `snippet` + `labelIds`，KB 级），
/// 增量走 `history.list`（精确 delta），正文/附件按需 `format=full`。
///
/// 推送靠 FCM（users.watch + Pub/Sub），不在客户端 IDLE/轮询（[supportsIdle] = false）。
class GmailApiBackend implements MailBackend {
  GmailApiBackend({required this.account, required this.tokenProvider})
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://gmail.googleapis.com/gmail/v1/users/me',
          headers: {'Content-Type': 'application/json'},
          // Gmail 期望重复键（historyTypes=a&historyTypes=b），dio 默认的
          // multiCompatible 会编码成 historyTypes[]=a，Gmail 不接受。
          listFormat: ListFormat.multi,
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await tokenProvider();
            options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          } catch (e) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: MailAuthException('获取访问令牌失败', cause: e),
              ),
            );
          }
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: const MailAuthException('Gmail API 认证失败（401）'),
              ),
            );
          } else {
            handler.next(error);
          }
        },
      ),
    );
  }

  final AccountConfig account;
  final AccessTokenProvider tokenProvider;
  final Dio _dio;

  /// 首次全量同步每个文件夹拉取的信封上限（与旧 IMAP 全量窗口对齐，避免可见邮件回退）。
  static const int _initialLimit = 200;

  /// 每个批量请求（/batch/gmail/v1）打包的子请求数上限（Gmail 上限 100）。
  static const int _batchSize = 100;

  /// Gmail 批量端点与 API 路径前缀（子请求需用绝对 API 路径）。
  static const String _batchUrl = 'https://gmail.googleapis.com/batch/gmail/v1';
  static const String _apiPathPrefix = '/gmail/v1/users/me';

  /// 取信封时请求的头字段。
  static const List<String> _metadataHeaders = [
    'Subject',
    'From',
    'To',
    'Cc',
    'Date',
    'Message-ID',
  ];

  /// Gmail 系统标签 → 语义文件夹。Gmail 无「归档」标签（归档=移除 INBOX），故不映射。
  static const Map<String, FolderType> _systemFolderType = {
    'INBOX': FolderType.inbox,
    'SENT': FolderType.sent,
    'DRAFT': FolderType.drafts,
    'TRASH': FolderType.trash,
    'SPAM': FolderType.spam,
  };

  @override
  AccountType get type => AccountType.gmailOAuth;

  @override
  bool get supportsIdle => false; // 靠 FCM 推送，不在客户端长连接。

  @override
  Future<void> connect() async {
    // 无状态 REST：用 /profile 验证 token 有效（同 Graph 用 /me）。
    try {
      await _retry(() => _dio.get('/profile'));
    } on DioException catch (e) {
      throw MailAuthException('Gmail 连接验证失败', cause: e);
    }
  }

  @override
  Future<void> disconnect() async {
    // 无需断开。
  }

  @override
  Future<List<MailboxFolder>> listFolders() async {
    try {
      final resp = await _retry(() => _dio.get('/labels'));
      final labels = ((resp.data['labels'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .where(_shouldSurface)
          .toList();

      // labels.list 不含计数，并发用 labels.get 补未读/总数。失败则退化为列表项（计数 0）。
      final detailed = await Future.wait(
        labels.map((l) async {
          try {
            final r = await _retry(() => _dio.get('/labels/${l['id']}'));
            return r.data as Map<String, dynamic>;
          } on DioException {
            return l;
          }
        }),
      );

      return detailed.map(_mapLabel).toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw MailBackendException('列出标签失败 (HTTP $status)', cause: e);
    }
  }

  @override
  Future<EnvelopePage> fetchEnvelopes(
    MailboxFolder folder, {
    PageCursor cursor = PageCursor.start,
    int limit = 50,
  }) async {
    try {
      final params = <String, dynamic>{
        'labelIds': folder.remoteId,
        'maxResults': limit,
        // 否则 TRASH/SPAM 文件夹会返回空（messages.list 默认排除垃圾箱/废纸篓）。
        'includeSpamTrash': true,
      };
      // PageCursor 无 Gmail 专用字段，复用 graphNextLink 承载 pageToken。
      if (cursor.graphNextLink != null) {
        params['pageToken'] = cursor.graphNextLink;
      }
      final listResp = await _retry(
        () => _dio.get('/messages', queryParameters: params),
      );
      final ids = _idsFromList(listResp.data);
      final fetched = await _fetchMetadataBatch(ids, folder);
      // nextPageToken 存在即还有更旧的一页；复用 graphNextLink 承载。
      final nextToken = listResp.data['nextPageToken'] as String?;
      return EnvelopePage(
        envelopes: fetched.envelopes,
        nextCursor: nextToken == null
            ? null
            : PageCursor(graphNextLink: nextToken),
      );
    } on DioException catch (e) {
      throw MailBackendException('拉取信封失败', cause: e);
    }
  }

  @override
  Future<SyncResult> syncDelta(MailboxFolder folder, SyncToken? token) async {
    final historyId = token == null ? null : int.tryParse(token.value);
    // 无游标 / 游标非数字（旧 IMAP 序列化游标遗留）→ 全量重建。
    if (historyId == null) {
      return _fullResync(folder);
    }
    return _incrementalSync(folder, historyId);
  }

  Future<SyncResult> _fullResync(MailboxFolder folder) async {
    try {
      final listResp = await _retry(
        () => _dio.get(
          '/messages',
          queryParameters: {
            'labelIds': folder.remoteId,
            'maxResults': _initialLimit,
            // 否则 TRASH/SPAM 文件夹会返回空（messages.list 默认排除垃圾箱/废纸篓）。
            'includeSpamTrash': true,
          },
        ),
      );
      final ids = _idsFromList(listResp.data);
      final fetched = await _fetchMetadataBatch(ids, folder);

      // 有信封取元数据失败 → 不固化游标（返回 null token），下次重做全量重试，
      // 避免把失败的邮件永久漏掉。全部成功才以当前 historyId 作增量起点。
      if (fetched.failedIds.isNotEmpty) {
        return SyncResult(added: fetched.envelopes, newToken: null);
      }
      final profile = await _retry(() => _dio.get('/profile'));
      final hid = profile.data['historyId']?.toString();
      return SyncResult(
        added: fetched.envelopes,
        newToken: hid != null ? SyncToken(hid) : null,
      );
    } on DioException catch (e) {
      throw MailBackendException('Gmail 全量同步失败', cause: e);
    }
  }

  Future<SyncResult> _incrementalSync(
    MailboxFolder folder,
    int startHistoryId,
  ) async {
    final label = folder.remoteId;
    try {
      // 进入此文件夹（新增 / 加了本标签）→ 需取完整元数据。
      final toFetch = <String>{};
      // 仍在此文件夹但标志变了（已读/星标）→ 仅更新 flags，用 history 里的 labelIds 直接算。
      final flagOnly = <String, List<String>>{};
      final removedRefs = <MessageRef>[];
      String? latestHistoryId;
      String? pageToken;

      do {
        final resp = await _retry(
          () => _dio.get(
            '/history',
            queryParameters: {
              'startHistoryId': startHistoryId,
              'labelId': label,
              'historyTypes': const [
                'messageAdded',
                'messageDeleted',
                'labelAdded',
                'labelRemoved',
              ],
              'pageToken': ?pageToken,
            },
          ),
        );
        final data = resp.data as Map<String, dynamic>;
        latestHistoryId = data['historyId']?.toString() ?? latestHistoryId;

        for (final h in (data['history'] as List? ?? const [])) {
          final hm = h as Map<String, dynamic>;

          for (final a in (hm['messagesAdded'] as List? ?? const [])) {
            final msg =
                (a as Map<String, dynamic>)['message'] as Map<String, dynamic>;
            if (_labelsOf(msg).contains(label)) {
              toFetch.add(msg['id'] as String);
            }
          }

          for (final d in (hm['messagesDeleted'] as List? ?? const [])) {
            final msg =
                (d as Map<String, dynamic>)['message'] as Map<String, dynamic>;
            final id = msg['id'] as String;
            removedRefs.add(GmailRef(messageId: id, labelId: label));
            toFetch.remove(id);
            flagOnly.remove(id);
          }

          for (final la in (hm['labelsAdded'] as List? ?? const [])) {
            final m = la as Map<String, dynamic>;
            final msg = m['message'] as Map<String, dynamic>;
            final id = msg['id'] as String;
            if (_listOf(m['labelIds']).contains(label)) {
              toFetch.add(id); // 进入此文件夹
            } else if (_labelsOf(msg).contains(label)) {
              flagOnly[id] = _labelsOf(msg); // 仅其它标签变化（如 UNREAD/STARRED）
            }
          }

          for (final lr in (hm['labelsRemoved'] as List? ?? const [])) {
            final m = lr as Map<String, dynamic>;
            final msg = m['message'] as Map<String, dynamic>;
            final id = msg['id'] as String;
            if (_listOf(m['labelIds']).contains(label)) {
              // 离开此文件夹（如归档=移除 INBOX）。
              removedRefs.add(GmailRef(messageId: id, labelId: label));
              toFetch.remove(id);
              flagOnly.remove(id);
            } else if (_labelsOf(msg).contains(label)) {
              flagOnly[id] = _labelsOf(msg);
            }
          }
        }
        pageToken = data['nextPageToken'] as String?;
      } while (pageToken != null);

      final fetched = toFetch.isEmpty
          ? (envelopes: <MessageEnvelope>[], failedIds: <String>[])
          : await _fetchMetadataBatch(toFetch.toList(), folder);

      final updated = <MessageEnvelope>[];
      for (final entry in flagOnly.entries) {
        if (toFetch.contains(entry.key)) continue; // 已在 added 里全量刷新
        updated.add(_flagsOnlyEnvelope(entry.key, entry.value, folder));
      }

      // 有 messageAdded 取元数据失败 → 保留旧 startHistoryId 不前进，下次重放同段
      // delta 重试（成功的幂等 upsert，失败的再取），避免静默漏邮件造成空洞。
      // 新邮件不受影响：重放时一并在 toFetch 中重新取到。
      final tokenValue = fetched.failedIds.isEmpty
          ? (latestHistoryId ?? startHistoryId.toString())
          : startHistoryId.toString();

      return SyncResult(
        added: fetched.envelopes,
        updated: updated,
        removedRefs: removedRefs,
        newToken: SyncToken(tokenValue),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // historyId 过旧（离线太久 / 邮箱太活跃）→ 全量重建。
        return _fullResync(folder);
      }
      throw MailBackendException('Gmail 增量同步失败', cause: e);
    }
  }

  @override
  Future<MimeContent> fetchMessageContent(MessageRef ref) async {
    if (ref is! GmailRef) {
      throw const MailBackendException('GmailApiBackend 需要 GmailRef');
    }
    try {
      final resp = await _retry(
        () => _dio.get(
          '/messages/${ref.messageId}',
          queryParameters: {'format': 'full'},
        ),
      );
      final payload = resp.data['payload'] as Map<String, dynamic>?;
      final acc = _BodyAccumulator();
      if (payload != null) _walkPart(payload, acc);
      return MimeContent(
        plainText: acc.plainText,
        htmlBody: acc.htmlBody,
        attachments: acc.attachments,
      );
    } on DioException catch (e) {
      throw MailBackendException('拉取正文失败', cause: e);
    }
  }

  @override
  Future<List<int>> fetchAttachmentBytes(MessageRef ref, String partId) async {
    if (ref is! GmailRef) {
      throw const MailBackendException('GmailApiBackend 需要 GmailRef');
    }
    try {
      final resp = await _retry(
        () => _dio.get('/messages/${ref.messageId}/attachments/$partId'),
      );
      final data = resp.data['data'] as String?;
      if (data == null) {
        throw const MailBackendException('附件内容为空');
      }
      return _decodeBase64Url(data);
    } on DioException catch (e) {
      throw MailBackendException('下载附件失败', cause: e);
    }
  }

  @override
  Future<void> markRead(List<MessageRef> refs, {required bool read}) async {
    await _batchModify(
      _gmailIds(refs),
      add: read ? const [] : const ['UNREAD'],
      remove: read ? const ['UNREAD'] : const [],
    );
  }

  @override
  Future<void> markFlagged(
    List<MessageRef> refs, {
    required bool flagged,
  }) async {
    await _batchModify(
      _gmailIds(refs),
      add: flagged ? const ['STARRED'] : const [],
      remove: flagged ? const [] : const ['STARRED'],
    );
  }

  @override
  Future<void> moveToFolder(List<MessageRef> refs, MailboxFolder target) async {
    final gmailRefs = refs.whereType<GmailRef>().toList();
    if (gmailRefs.isEmpty) return;

    if (target.remoteId == 'TRASH') {
      for (final ref in gmailRefs) {
        await _trash(ref.messageId);
      }
      return;
    }

    // 一次 batchModify：加目标标签、移除各自的来源标签。移除不存在的标签是 no-op，
    // 故可把所有来源标签的并集一起传（每封只会丢掉它确实有的那个）。
    final removeLabels = gmailRefs
        .map((r) => r.labelId)
        .where((l) => l.isNotEmpty && l != target.remoteId)
        .toSet()
        .toList();
    await _batchModify(
      gmailRefs.map((r) => r.messageId).toList(),
      add: [target.remoteId],
      remove: removeLabels,
    );
  }

  @override
  Future<void> delete(List<MessageRef> refs) async {
    // Gmail「删除」语义=移到废纸篓（与 IMAP \Deleted / Graph 删到 deleteditems 一致）。
    // 无批量 trash 端点，逐封调用（已带重试）。
    for (final ref in refs.whereType<GmailRef>()) {
      await _trash(ref.messageId);
    }
  }

  @override
  Stream<MailboxEvent> watch(MailboxFolder folder) {
    // Gmail 走 FCM 推送（users.watch + Pub/Sub），不在客户端轮询/IDLE。
    // supportsIdle=false 时上层不会调用这里，返回空流即可。
    return const Stream.empty();
  }

  /// 批量改标签：一次请求改多封（messages.batchModify，≤1000 id）。
  /// id 为空、或 add/remove 都为空时跳过。
  Future<void> _batchModify(
    List<String> ids, {
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    if (ids.isEmpty || (add.isEmpty && remove.isEmpty)) return;
    await _retry(
      () => _dio.post(
        '/messages/batchModify',
        data: {
          'ids': ids,
          if (add.isNotEmpty) 'addLabelIds': add,
          if (remove.isNotEmpty) 'removeLabelIds': remove,
        },
      ),
    );
  }

  /// 移到废纸篓（无批量端点，逐封）。
  Future<void> _trash(String id) =>
      _retry(() => _dio.post('/messages/$id/trash'));

  /// 从 refs 里取出 GmailRef 的 message id 列表。
  List<String> _gmailIds(List<MessageRef> refs) =>
      refs.whereType<GmailRef>().map((r) => r.messageId).toList();

  // —— 网络：限流 / 瞬时错误重试 ——

  /// 对 429 / 5xx / 连接超时按指数退避重试（尊重 Retry-After 头）；其它错误立即抛出。
  Future<T> _retry<T>(Future<T> Function() op, {int maxAttempts = 4}) async {
    var attempt = 0;
    while (true) {
      try {
        return await op();
      } on DioException catch (e) {
        attempt++;
        if (attempt >= maxAttempts || !_isRetryable(e)) rethrow;
        await Future<void>.delayed(_backoff(e, attempt));
      }
    }
  }

  bool _isRetryable(DioException e) {
    final status = e.response?.statusCode;
    if (status == 429 || (status != null && status >= 500)) return true;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  Duration _backoff(DioException e, int attempt) {
    final retryAfter = e.response?.headers.value('retry-after');
    final seconds = retryAfter == null ? null : int.tryParse(retryAfter.trim());
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds.clamp(0, 60));
    }
    // 指数退避 + 抖动：≈0.5s, 1s, 2s …（上限 8s）。
    final base = 500 * (1 << (attempt - 1));
    final jitter = math.Random().nextInt(250);
    return Duration(milliseconds: (base + jitter).clamp(0, 8000));
  }

  // —— 列表 / 元数据 ——

  List<String> _idsFromList(dynamic listData) {
    return ((listData['messages'] as List?) ?? const [])
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .toList();
  }

  /// 用 Gmail 批量端点取信封元数据：每 100 封一个 HTTP 请求（而非每封一个）。
  /// 子响应 429/5xx 的 id 会再批量重试一轮，仍失败的逐封兜底。
  ///
  /// 返回成功取到的信封 + **仍失败的 id**（非 404 的瞬时错误：401/403/429/5xx/网络）。
  /// 调用方据此决定是否推进同步游标——有失败就不推进，避免静默丢邮件造成空洞。
  /// 404（邮件确已不存在）不计入失败，直接丢弃。
  Future<({List<MessageEnvelope> envelopes, List<String> failedIds})>
  _fetchMetadataBatch(List<String> ids, MailboxFolder folder) async {
    if (ids.isEmpty) {
      return (envelopes: <MessageEnvelope>[], failedIds: <String>[]);
    }
    final out = <MessageEnvelope>[];
    var pending = ids;
    for (var round = 0; round < 2 && pending.isNotEmpty; round++) {
      final failed = <String>[];
      for (var i = 0; i < pending.length; i += _batchSize) {
        final end = (i + _batchSize).clamp(0, pending.length);
        await _batchGetMetadata(pending.sublist(i, end), folder, out, failed);
      }
      pending = failed;
    }
    // 仍失败的零头：逐封兜底（带重试）；再失败则计入 failedIds，由上层保留游标重试。
    final failedIds = <String>[];
    for (final id in pending) {
      final env = await _fetchMetadata(id, folder);
      if (env != null) {
        out.add(env);
      } else {
        failedIds.add(id);
      }
    }
    return (envelopes: out, failedIds: failedIds);
  }

  /// 一个批量请求：把 [ids] 拼成 multipart/mixed 子请求，解析每个子响应。
  /// 200→入 [out]；404/其它 4xx→丢弃；429/5xx 或整批失败→记入 [failed]。
  Future<void> _batchGetMetadata(
    List<String> ids,
    MailboxFolder folder,
    List<MessageEnvelope> out,
    List<String> failed,
  ) async {
    const boundary = 'ee_batch';
    final query = _metadataQuery();
    final body = StringBuffer();
    for (final id in ids) {
      body
        ..write('--$boundary\r\n')
        ..write('Content-Type: application/http\r\n')
        ..write('Content-ID: $id\r\n\r\n')
        ..write('GET $_apiPathPrefix/messages/$id?$query\r\n\r\n');
    }
    body.write('--$boundary--');

    try {
      final resp = await _retry(
        () => _dio.post(
          _batchUrl,
          data: body.toString(),
          options: Options(
            contentType: 'multipart/mixed; boundary=$boundary',
            responseType: ResponseType.plain,
          ),
        ),
      );
      final parts = parseGmailBatchResponse(
        resp.data as String? ?? '',
        resp.headers.value('content-type') ?? '',
      );
      // Gmail 保证子响应与子请求同序，按下标对齐。
      for (var i = 0; i < ids.length; i++) {
        final part = i < parts.length ? parts[i] : null;
        if (part == null) {
          failed.add(ids[i]);
          continue;
        }
        if (part.status == 200 && part.json != null) {
          out.add(_mapMessage(part.json!, folder));
        } else if (part.status == 429 || part.status >= 500) {
          failed.add(ids[i]);
        }
        // 404 / 其它 4xx：邮件已不存在或不可重试，丢弃。
      }
    } on DioException {
      failed.addAll(ids); // 整批失败（重试后仍然）：降级到下一轮 / 逐封兜底。
    }
  }

  /// 逐封取元数据（批量的兜底路径），带重试。
  Future<MessageEnvelope?> _fetchMetadata(
    String id,
    MailboxFolder folder,
  ) async {
    try {
      final resp = await _retry(
        () => _dio.get(
          '/messages/$id',
          queryParameters: {
            'format': 'metadata',
            'metadataHeaders': _metadataHeaders,
          },
        ),
      );
      return _mapMessage(resp.data as Map<String, dynamic>, folder);
    } on DioException {
      return null;
    }
  }

  String _metadataQuery() {
    final headers = _metadataHeaders
        .map((h) => 'metadataHeaders=${Uri.encodeQueryComponent(h)}')
        .join('&');
    return 'format=metadata&$headers';
  }

  MessageEnvelope _mapMessage(Map<String, dynamic> json, MailboxFolder folder) {
    final payload = json['payload'] as Map<String, dynamic>?;
    final headers = ((payload?['headers'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final labelIds = _listOf(json['labelIds']);
    final addresses = _parseAddresses(_header(headers, 'From'));
    final dateMs = int.tryParse(json['internalDate'] as String? ?? '');

    return MessageEnvelope(
      localId: '',
      ref: GmailRef(
        messageId: json['id'] as String,
        labelId: folder.remoteId,
        threadId: json['threadId'] as String?,
      ),
      accountId: account.id,
      folderId: folder.id,
      subject: _decodeHeader(_header(headers, 'Subject')) ?? '',
      date: dateMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dateMs)
          : (DateTime.tryParse(_header(headers, 'Date') ?? '') ??
                DateTime.now()),
      from: addresses.isNotEmpty ? addresses.first : null,
      to: _parseAddresses(_header(headers, 'To')),
      cc: _parseAddresses(_header(headers, 'Cc')),
      preview: _decodeSnippet(json['snippet'] as String?),
      flags: _flagsFromLabels(labelIds),
      hasAttachments: _payloadHasAttachments(payload),
      threadKey: json['threadId'] as String?,
      messageIdHeader: _header(headers, 'Message-ID'),
      labels: labelIds,
    );
  }

  /// 仅含 ref + flags 的信封，供 SyncService 做 flags-only 更新（不参与全列持久化）。
  MessageEnvelope _flagsOnlyEnvelope(
    String id,
    List<String> labelIds,
    MailboxFolder folder,
  ) {
    return MessageEnvelope(
      localId: '',
      ref: GmailRef(messageId: id, labelId: folder.remoteId),
      accountId: account.id,
      folderId: folder.id,
      subject: '',
      date: DateTime.fromMillisecondsSinceEpoch(0),
      flags: _flagsFromLabels(labelIds),
    );
  }

  // —— 文件夹 / 标签 ——

  bool _shouldSurface(Map<String, dynamic> label) {
    final type = label['type'] as String? ?? 'user';
    if (type == 'user') return true;
    // 系统标签只暴露常用文件夹，过滤 CATEGORY_*/IMPORTANT/STARRED/UNREAD/CHAT 等伪标签。
    return _systemFolderType.containsKey(label['id']);
  }

  MailboxFolder _mapLabel(Map<String, dynamic> label) {
    final id = label['id'] as String;
    final isSystem = (label['type'] as String? ?? 'user') == 'system';
    final folderType = isSystem
        ? (_systemFolderType[id] ?? FolderType.custom)
        : FolderType.custom;
    return MailboxFolder(
      id: '', // 由仓储层填充
      accountId: account.id,
      remoteId: id,
      displayName: _displayName(folderType, label['name'] as String? ?? id),
      type: folderType,
      unreadCount: label['messagesUnread'] as int? ?? 0,
      totalCount: label['messagesTotal'] as int? ?? 0,
    );
  }

  /// 系统文件夹用本地化名称（Gmail 原名为 INBOX/SENT 等），用户标签用其原名。
  String _displayName(FolderType type, String rawName) {
    switch (type) {
      case FolderType.inbox:
        return '收件箱';
      case FolderType.sent:
        return '已发送';
      case FolderType.drafts:
        return '草稿';
      case FolderType.trash:
        return '废纸篓';
      case FolderType.spam:
        return '垃圾邮件';
      case FolderType.archive:
        return '归档';
      case FolderType.custom:
        return rawName;
    }
  }

  // —— 正文（format=full）解析 ——

  void _walkPart(Map<String, dynamic> part, _BodyAccumulator acc) {
    final mimeType = (part['mimeType'] as String? ?? '').toLowerCase();
    final filename = part['filename'] as String?;
    final body = part['body'] as Map<String, dynamic>?;
    final parts = part['parts'] as List?;
    final headers = ((part['headers'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    final hasFilename = filename != null && filename.isNotEmpty;
    final attachmentId = body?['attachmentId'] as String?;

    // 有文件名或独立 attachmentId → 附件 / 内联部件。
    if (hasFilename || attachmentId != null) {
      final disposition =
          _header(headers, 'Content-Disposition')?.toLowerCase() ?? '';
      final contentId = _stripAngle(_header(headers, 'Content-ID'));
      acc.attachments.add(
        MailAttachment(
          partId: attachmentId ?? (part['partId'] as String? ?? ''),
          mimeType: mimeType.isEmpty ? 'application/octet-stream' : mimeType,
          filename: hasFilename ? _decodeHeader(filename) : null,
          size: body?['size'] as int?,
          isInline: disposition.startsWith('inline') || contentId != null,
          contentId: contentId,
        ),
      );
      return;
    }

    final data = body?['data'] as String?;
    if (mimeType == 'text/plain' && data != null) {
      acc.plainText = (acc.plainText ?? '') + _decodeBody(data);
      return;
    }
    if (mimeType == 'text/html' && data != null) {
      acc.htmlBody = (acc.htmlBody ?? '') + _decodeBody(data);
      return;
    }

    if (parts != null) {
      for (final p in parts) {
        _walkPart(p as Map<String, dynamic>, acc);
      }
    }
  }

  bool _payloadHasAttachments(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    final filename = payload['filename'] as String?;
    if (filename != null && filename.isNotEmpty) return true;
    final parts = payload['parts'] as List?;
    if (parts != null) {
      for (final p in parts) {
        if (_payloadHasAttachments(p as Map<String, dynamic>)) return true;
      }
    }
    return false;
  }

  // —— 工具 ——

  List<String> _listOf(dynamic raw) =>
      (raw as List?)?.cast<String>() ?? const [];

  List<String> _labelsOf(Map<String, dynamic> message) =>
      _listOf(message['labelIds']);

  Set<MessageFlag> _flagsFromLabels(List<String> labelIds) {
    final flags = <MessageFlag>{};
    if (!labelIds.contains('UNREAD')) flags.add(MessageFlag.seen);
    if (labelIds.contains('STARRED')) flags.add(MessageFlag.flagged);
    if (labelIds.contains('DRAFT')) flags.add(MessageFlag.draft);
    return flags;
  }

  String? _header(List<Map<String, dynamic>> headers, String name) {
    final lower = name.toLowerCase();
    for (final h in headers) {
      if ((h['name'] as String?)?.toLowerCase() == lower) {
        return h['value'] as String?;
      }
    }
    return null;
  }

  /// RFC2047 编码字（=?utf-8?B?..?=）解码，复用 enough_mail 的实现。
  String? _decodeHeader(String? raw) {
    if (raw == null) return null;
    try {
      return em.MailCodec.decodeHeader(raw) ?? raw;
    } catch (_) {
      return raw;
    }
  }

  /// Gmail snippet 是 HTML 转义文本，反转义常见实体。
  String _decodeSnippet(String? snippet) {
    if (snippet == null || snippet.isEmpty) return '';
    return snippet
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#34;', '"');
  }

  List<MailAddress> _parseAddresses(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final result = <MailAddress>[];
    // 按逗号切分，但跳过引号内的逗号。
    final parts = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '"') inQuotes = !inQuotes;
      if (c == ',' && !inQuotes) {
        parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());

    for (final p in parts) {
      final addr = _parseSingleAddress(p.trim());
      if (addr != null) result.add(addr);
    }
    return result;
  }

  MailAddress? _parseSingleAddress(String s) {
    if (s.isEmpty) return null;
    final lt = s.lastIndexOf('<');
    final gt = s.lastIndexOf('>');
    if (lt != -1 && gt > lt) {
      final email = s.substring(lt + 1, gt).trim();
      if (email.isEmpty) return null;
      final name = _decodeHeader(_stripQuotes(s.substring(0, lt).trim())) ?? '';
      return MailAddress(email: email, name: name.isEmpty ? null : name);
    }
    final email = s.trim();
    if (!email.contains('@')) return null;
    return MailAddress(email: email, name: null);
  }

  String _stripQuotes(String s) {
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  String? _stripAngle(String? s) {
    if (s == null) return null;
    var v = s.trim();
    if (v.startsWith('<') && v.endsWith('>')) {
      v = v.substring(1, v.length - 1);
    }
    return v.isEmpty ? null : v;
  }

  String _decodeBody(String data) {
    try {
      return utf8.decode(_decodeBase64Url(data), allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  /// Gmail 用 URL-safe base64（- _），可能缺省填充。
  List<int> _decodeBase64Url(String data) {
    var s = data.replaceAll('-', '+').replaceAll('_', '/');
    final mod = s.length % 4;
    if (mod > 0) s = s.padRight(s.length + (4 - mod), '=');
    return base64.decode(s);
  }
}

/// 解析 format=full 正文时的可变累加器。
class _BodyAccumulator {
  String? plainText;
  String? htmlBody;
  final List<MailAttachment> attachments = [];
}
