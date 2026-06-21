import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../domain/enums/account_enums.dart';
import '../../../domain/enums/message_enums.dart';
import '../../../domain/models/account_config.dart';
import '../../../domain/models/mail_address.dart';
import '../../../domain/models/mailbox_folder.dart';
import '../../../domain/models/message_envelope.dart';
import '../../../domain/models/message_ref.dart';
import '../../../domain/models/mime_content.dart';
import '../../../domain/models/outgoing_message.dart';
import '../mail_backend.dart';
import '../sync_types.dart';
import '../token_provider.dart';

/// Microsoft Graph 后端实现。
///
/// 使用 Graph REST API v1.0：
/// - /me/mailFolders - 文件夹列表
/// - /me/messages - 邮件查询
/// - /me/mailFolders/{id}/messages/delta - 增量同步
class GraphMailBackend implements MailBackend {
  GraphMailBackend({required this.account, required this.tokenProvider})
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://graph.microsoft.com/v1.0',
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ) {
    // 添加认证拦截器
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
                error: const MailAuthException('Graph API 认证失败（401）'),
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

  @override
  AccountType get type => AccountType.microsoftGraph;

  @override
  bool get supportsIdle => false; // Graph 使用 webhooks，不是 IDLE

  @override
  Future<void> connect() async {
    // Graph 是无状态 REST API，无需显式连接
    // 验证令牌有效性
    try {
      await _retry(() => _dio.get('/me'));
    } on DioException catch (e) {
      throw MailAuthException('Graph 连接验证失败', cause: e);
    }
  }

  @override
  Future<void> disconnect() async {
    // 无需断开连接
  }

  @override
  Future<List<MailboxFolder>> listFolders() async {
    try {
      // v1.0 不返回 wellKnownName（仅 beta 有），改用别名反查每个常用文件夹的真实 id 来识别类型。
      final listFuture = _retry(
        () => _dio.get(
          '/me/mailFolders',
          queryParameters: {
            '\$select': 'id,displayName,unreadItemCount,totalItemCount',
            '\$top': 100,
          },
        ),
      );

      final aliasFutures = _wellKnownAliases.entries.map((e) async {
        try {
          final r = await _retry(
            () => _dio.get(
              '/me/mailFolders/${e.key}',
              queryParameters: {'\$select': 'id'},
            ),
          );
          return MapEntry(r.data['id'] as String, e.value);
        } on DioException {
          // 部分邮箱不存在 archive 等别名，忽略即可。
          return null;
        }
      });

      final listResp = await listFuture;
      final aliasResolutions = await Future.wait(aliasFutures);

      final aliasIdToType = <String, FolderType>{
        for (final res in aliasResolutions)
          if (res != null) res.key: res.value,
      };

      final folders = (listResp.data['value'] as List).map((json) {
        final m = json as Map<String, dynamic>;
        final id = m['id'] as String;
        return _mapFolder(m, type: aliasIdToType[id] ?? FolderType.custom);
      }).toList();

      return folders;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      throw MailBackendException('列出文件夹失败 (HTTP $status): $body', cause: e);
    }
  }

  static const Map<String, FolderType> _wellKnownAliases = {
    'inbox': FolderType.inbox,
    'sentitems': FolderType.sent,
    'drafts': FolderType.drafts,
    'deleteditems': FolderType.trash,
    'junkemail': FolderType.spam,
    'archive': FolderType.archive,
  };

  @override
  Future<EnvelopePage> fetchEnvelopes(
    MailboxFolder folder, {
    PageCursor cursor = PageCursor.start,
    int limit = 50,
  }) async {
    try {
      final params = {
        '\$top': limit,
        '\$orderby': 'receivedDateTime desc',
        '\$select':
            'id,subject,from,toRecipients,ccRecipients,'
            'receivedDateTime,bodyPreview,isRead,flag,hasAttachments,'
            'conversationId,internetMessageId',
      };

      if (cursor.graphNextLink != null) {
        // 使用 Graph 的 nextLink
        final response = await _retry(() => _dio.get(cursor.graphNextLink!));
        return _envelopePageFrom(response.data as Map<String, dynamic>, folder);
      }

      if (cursor.offset > 0) {
        params['\$skip'] = cursor.offset.toString();
      }

      final response = await _retry(
        () => _dio.get(
          '/me/mailFolders/${folder.remoteId}/messages',
          queryParameters: params,
        ),
      );

      return _envelopePageFrom(response.data as Map<String, dynamic>, folder);
    } on DioException catch (e) {
      throw MailBackendException('拉取信封失败', cause: e);
    }
  }

  /// 把一页 Graph messages 响应解析为 [EnvelopePage]，用 @odata.nextLink 承载更旧游标。
  EnvelopePage _envelopePageFrom(
    Map<String, dynamic> data,
    MailboxFolder folder,
  ) {
    final messages = (data['value'] as List)
        .map((json) => _mapMessage(json as Map<String, dynamic>, folder))
        .toList();
    final nextLink = data['@odata.nextLink'] as String?;
    return EnvelopePage(
      envelopes: messages,
      nextCursor: nextLink == null ? null : PageCursor(graphNextLink: nextLink),
    );
  }

  @override
  Future<MimeContent> fetchMessageContent(MessageRef ref) async {
    if (ref is! GraphRef) {
      throw const MailBackendException('GraphMailBackend 需要 GraphRef');
    }

    try {
      // 单次请求拿正文 + 附件元数据：$expand 内联附件，省去原先的第二次
      // /attachments 往返，约腰斩点开延迟。$select=body 仅取正文，减小负载。
      final response = await _retry(
        () => _dio.get(
          '/me/messages/${ref.messageId}',
          queryParameters: {
            '\$select': 'body',
            '\$expand': 'attachments(\$select=id,name,contentType,size)',
          },
        ),
      );
      final json = response.data as Map<String, dynamic>;

      // 获取正文
      final body = json['body'] as Map<String, dynamic>?;
      final bodyContent = body?['content'] as String?;
      final bodyType = body?['contentType'] as String?;

      // 内联的附件元数据（无则为空）
      final attachmentsJson = json['attachments'] as List? ?? const [];
      final attachments = attachmentsJson
          .map((json) => _mapAttachment(json as Map<String, dynamic>))
          .toList();

      return MimeContent(
        plainText: bodyType == 'text' ? bodyContent : null,
        htmlBody: bodyType == 'html' ? bodyContent : null,
        attachments: attachments,
      );
    } on DioException catch (e) {
      throw MailBackendException('拉取正文失败', cause: e);
    }
  }

  @override
  Future<List<int>> fetchAttachmentBytes(MessageRef ref, String partId) async {
    if (ref is! GraphRef) {
      throw const MailBackendException('GraphMailBackend 需要 GraphRef');
    }

    try {
      final response = await _retry(
        () => _dio.get(
          '/me/messages/${ref.messageId}/attachments/$partId/\$value',
          options: Options(responseType: ResponseType.bytes),
        ),
      );
      return response.data as List<int>;
    } on DioException catch (e) {
      throw MailBackendException('下载附件失败', cause: e);
    }
  }

  @override
  Future<SyncResult> syncDelta(MailboxFolder folder, SyncToken? token) async {
    try {
      var url =
          token?.value ?? '/me/mailFolders/${folder.remoteId}/messages/delta';
      Map<String, dynamic>? params = token == null
          ? {
              '\$select':
                  'id,subject,from,toRecipients,ccRecipients,'
                  'receivedDateTime,bodyPreview,isRead,flag,hasAttachments,'
                  'conversationId,internetMessageId',
            }
          : null;
      final added = <MessageEnvelope>[];
      final removedRefs = <MessageRef>[];
      String? deltaLink;

      while (true) {
        final response = await _retry(
          () => _dio.get(url, queryParameters: params),
        );
        params = null; // nextLink / deltaLink 已含完整查询参数。
        final data = response.data as Map<String, dynamic>;

        for (final item in data['value'] as List? ?? const []) {
          final json = item as Map<String, dynamic>;
          if (json.containsKey('@removed')) {
            // 邮件已删除
            removedRefs.add(
              GraphRef(
                messageId: json['id'] as String,
                folderId: folder.remoteId,
              ),
            );
          } else {
            // 新增或更新
            added.add(_mapMessage(json, folder));
          }
        }

        final nextLink = data['@odata.nextLink'] as String?;
        deltaLink = data['@odata.deltaLink'] as String? ?? deltaLink;
        if (nextLink == null) break;
        url = nextLink;
      }

      return SyncResult(
        added: added,
        removedRefs: removedRefs,
        newToken: deltaLink != null ? SyncToken(deltaLink) : null,
      );
    } on DioException catch (e) {
      if (token != null &&
          (e.response?.statusCode == 404 || e.response?.statusCode == 410)) {
        return syncDelta(folder, null);
      }
      throw MailBackendException('增量同步失败', cause: e);
    }
  }

  @override
  Future<void> markRead(List<MessageRef> refs, {required bool read}) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      await _retry(
        () =>
            _dio.patch('/me/messages/${ref.messageId}', data: {'isRead': read}),
      );
    }
  }

  @override
  Future<void> markFlagged(
    List<MessageRef> refs, {
    required bool flagged,
  }) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      await _retry(
        () => _dio.patch(
          '/me/messages/${ref.messageId}',
          data: {
            'flag': {'flagStatus': flagged ? 'flagged' : 'notFlagged'},
          },
        ),
      );
    }
  }

  @override
  Future<void> moveToFolder(List<MessageRef> refs, MailboxFolder target) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      await _retry(
        () => _dio.post(
          '/me/messages/${ref.messageId}/move',
          data: {'destinationId': target.remoteId},
        ),
      );
    }
  }

  @override
  Future<void> delete(List<MessageRef> refs) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      await _retry(() => _dio.delete('/me/messages/${ref.messageId}'));
    }
  }

  @override
  Future<void> sendMessage(OutgoingMessage message) async {
    SavedDraft? draft;
    try {
      draft = await _createOrUpdateDraft(message);
      await _retry(() => _dio.post('/me/messages/${draft!.draftId}/send'));
    } on DioException catch (e) {
      if (draft != null && await _draftNoLongerExists(draft.draftId)) {
        return;
      }
      throw MailBackendException(_graphDioMessage('Graph 发送失败', e), cause: e);
    }
  }

  @override
  Future<SavedDraft?> saveDraft(OutgoingMessage message) async {
    try {
      return _createOrUpdateDraft(message);
    } on DioException catch (e) {
      throw MailBackendException(_graphDioMessage('Graph 保存草稿失败', e), cause: e);
    }
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    if (draftId.isEmpty) return;
    try {
      await _retry(() => _dio.delete('/me/messages/$draftId'));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw MailBackendException(_graphDioMessage('Graph 删除草稿失败', e), cause: e);
    }
  }

  Future<bool> _draftNoLongerExists(String draftId) async {
    try {
      final response = await _retry(
        () => _dio.get(
          '/me/messages/$draftId',
          queryParameters: {'\$select': 'id,isDraft'},
        ),
      );
      final json = (response.data as Map).cast<String, dynamic>();
      return json['isDraft'] == false;
    } on DioException catch (e) {
      return e.response?.statusCode == 404;
    }
  }

  String _graphDioMessage(String prefix, DioException e) {
    final parts = <String>[prefix];
    final status = e.response?.statusCode;
    if (status != null) parts.add('HTTP $status');
    final data = e.response?.data;
    if (data != null) {
      final text = _compactErrorData(data);
      if (text.isNotEmpty) parts.add(text);
    }
    return parts.join('：');
  }

  String _compactErrorData(Object data) {
    String text;
    try {
      text = data is String ? data : jsonEncode(data);
    } catch (_) {
      text = data.toString();
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 500 ? '${text.substring(0, 500)}...' : text;
  }

  Future<SavedDraft> _createOrUpdateDraft(OutgoingMessage message) async {
    var draftId = message.serverDraftId;
    if (draftId == null || draftId.isEmpty) {
      final created = await _createDraft(message);
      draftId = created.draftId;
    }

    await _retry(
      () => _dio.patch('/me/messages/$draftId', data: _graphDraftJson(message)),
    );
    await _replaceDraftAttachments(draftId, message.attachments);

    final response = await _retry(
      () => _dio.get(
        '/me/messages/$draftId',
        queryParameters: {'\$select': 'id,parentFolderId,conversationId'},
      ),
    );
    final json = (response.data as Map).cast<String, dynamic>();
    return SavedDraft(
      draftId: json['id'] as String? ?? draftId,
      messageId: json['id'] as String? ?? draftId,
      folderId: json['parentFolderId'] as String?,
      threadId: json['conversationId'] as String?,
    );
  }

  Future<SavedDraft> _createDraft(OutgoingMessage message) async {
    Response<dynamic> response;
    final sourceId = message.sourceMessageId;
    if (sourceId != null && sourceId.isNotEmpty) {
      final action = switch (message.action) {
        OutgoingMessageAction.reply => 'createReply',
        OutgoingMessageAction.replyAll => 'createReplyAll',
        OutgoingMessageAction.forward => 'createForward',
        OutgoingMessageAction.newMessage => null,
      };
      if (action != null) {
        response = await _retry(
          () => _dio.post('/me/messages/$sourceId/$action'),
        );
      } else {
        response = await _retry(
          () => _dio.post('/me/messages', data: _graphDraftJson(message)),
        );
      }
    } else {
      response = await _retry(
        () => _dio.post('/me/messages', data: _graphDraftJson(message)),
      );
    }
    final json = (response.data as Map).cast<String, dynamic>();
    final id = json['id'] as String;
    return SavedDraft(
      draftId: id,
      messageId: id,
      folderId: json['parentFolderId'] as String?,
      threadId: json['conversationId'] as String?,
    );
  }

  /// 把 [OutgoingMessage] 转为 Graph draft/message JSON（附件单独上传）。
  Map<String, dynamic> _graphDraftJson(OutgoingMessage message) {
    final hasHtml = message.html != null && message.html!.trim().isNotEmpty;

    return {
      'subject': message.subject,
      'body': {
        'contentType': hasHtml ? 'html' : 'text',
        'content': hasHtml ? message.html : message.text,
      },
      'toRecipients': [for (final a in message.to) _graphRecipient(a)],
      'ccRecipients': [for (final a in message.cc) _graphRecipient(a)],
      'bccRecipients': [for (final a in message.bcc) _graphRecipient(a)],
    };
  }

  Future<void> _replaceDraftAttachments(
    String draftId,
    List<OutgoingAttachment> attachments,
  ) async {
    final existing = await _retry(
      () => _dio.get(
        '/me/messages/$draftId/attachments',
        queryParameters: {'\$select': 'id'},
      ),
    );
    final values = (existing.data['value'] as List?) ?? const [];
    for (final raw in values) {
      final id = (raw as Map)['id'] as String?;
      if (id != null) {
        await _retry(
          () => _dio.delete('/me/messages/$draftId/attachments/$id'),
        );
      }
    }

    for (final att in attachments) {
      final file = File(att.localPath);
      if (!await file.exists()) {
        throw MailBackendException('附件文件不存在: ${att.localPath}');
      }
      final length = await file.length();
      if (length < _largeAttachmentThreshold) {
        final bytes = await file.readAsBytes();
        await _retry(
          () => _dio.post(
            '/me/messages/$draftId/attachments',
            data: {
              '@odata.type': '#microsoft.graph.fileAttachment',
              'name': att.filename,
              'contentType': att.mimeType,
              'contentBytes': base64.encode(bytes),
            },
          ),
        );
      } else {
        await _uploadLargeAttachment(draftId, att, file, length);
      }
    }
  }

  Future<void> _uploadLargeAttachment(
    String draftId,
    OutgoingAttachment attachment,
    File file,
    int length,
  ) async {
    final session = await _retry(
      () => _dio.post(
        '/me/messages/$draftId/attachments/createUploadSession',
        data: {
          'AttachmentItem': {
            'attachmentType': 'file',
            'name': attachment.filename,
            'size': length,
            'contentType': attachment.mimeType,
          },
        },
      ),
    );
    final uploadUrl = session.data['uploadUrl'] as String;
    var offset = 0;
    final uploadDio = Dio();
    final raf = await file.open();
    try {
      while (offset < length) {
        final endExclusive = (offset + _uploadChunkSize).clamp(0, length);
        final endInclusive = endExclusive - 1;
        await raf.setPosition(offset);
        final chunk = await raf.read(endExclusive - offset);
        final response = await _putUploadChunkWithRetry(
          uploadDio,
          uploadUrl,
          chunk,
          start: offset,
          endInclusive: endInclusive,
          totalLength: length,
        );
        final next = _nextUploadOffset(response.data);
        offset = next ?? endExclusive;
      }
    } finally {
      await raf.close();
    }
  }

  Future<Response<dynamic>> _putUploadChunkWithRetry(
    Dio uploadDio,
    String uploadUrl,
    List<int> chunk, {
    required int start,
    required int endInclusive,
    required int totalLength,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await uploadDio.put(
          uploadUrl,
          data: chunk,
          options: Options(
            headers: {
              'Content-Length': chunk.length,
              'Content-Range': 'bytes $start-$endInclusive/$totalLength',
            },
          ),
        );
      } on DioException catch (e) {
        attempt++;
        if (attempt >= 4 || !_isChunkUploadRetryable(e)) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 300 * attempt * attempt),
        );
      }
    }
  }

  int? _nextUploadOffset(Object? data) {
    if (data is! Map) return null;
    final ranges = data['nextExpectedRanges'];
    if (ranges is! List || ranges.isEmpty) return null;
    final first = ranges.first;
    if (first is! String || first.isEmpty) return null;
    final dash = first.indexOf('-');
    final start = dash == -1 ? first : first.substring(0, dash);
    return int.tryParse(start);
  }

  bool _isChunkUploadRetryable(DioException e) {
    final status = e.response?.statusCode;
    if (status == 408 || status == 429 || (status != null && status >= 500)) {
      return true;
    }
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  /// 对 Graph 的限流、服务端错误和瞬时网络错误做有限重试。
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
    if (status == 408 || status == 429 || (status != null && status >= 500)) {
      return true;
    }
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
    DateTime? retryAfterDate;
    if (retryAfter != null) {
      try {
        retryAfterDate = HttpDate.parse(retryAfter);
      } catch (_) {
        retryAfterDate = null;
      }
    }
    if (retryAfterDate != null) {
      final delay = retryAfterDate.difference(DateTime.now().toUtc());
      if (delay > Duration.zero) {
        return delay > const Duration(seconds: 60)
            ? const Duration(seconds: 60)
            : delay;
      }
    }
    final base = 500 * (1 << (attempt - 1));
    final jitter = math.Random().nextInt(250);
    return Duration(milliseconds: (base + jitter).clamp(0, 8000));
  }

  static const int _largeAttachmentThreshold = 3 * 1024 * 1024;
  static const int _uploadChunkSize = 327680 * 10;

  Map<String, dynamic> _graphRecipient(MailAddress a) => {
    'emailAddress': {
      'address': a.email,
      if (a.name != null && a.name!.isNotEmpty) 'name': a.name,
    },
  };

  @override
  Stream<MailboxEvent> watch(MailboxFolder folder) async* {
    // Graph 推送需要 webhooks（复杂），这里简化为轮询
    yield* Stream.periodic(const Duration(seconds: 60), (_) async {
      final result = await syncDelta(folder, null);
      return MailArrivedEvent(result.added);
    }).asyncMap((event) => event);
  }

  MailboxFolder _mapFolder(
    Map<String, dynamic> json, {
    required FolderType type,
  }) {
    return MailboxFolder(
      id: '', // 由仓储层填充
      accountId: account.id,
      remoteId: json['id'] as String,
      displayName: json['displayName'] as String,
      type: type,
      unreadCount: json['unreadItemCount'] as int? ?? 0,
      totalCount: json['totalItemCount'] as int? ?? 0,
    );
  }

  MessageEnvelope _mapMessage(Map<String, dynamic> json, MailboxFolder folder) {
    final from = json['from'] as Map<String, dynamic>?;
    final fromAddr = from?['emailAddress'] as Map<String, dynamic>?;

    final toList = json['toRecipients'] as List? ?? [];
    final ccList = json['ccRecipients'] as List? ?? [];

    final flags = <MessageFlag>{};
    if (json['isRead'] == true) flags.add(MessageFlag.seen);
    final flagStatus = json['flag']?['flagStatus'] as String?;
    if (flagStatus == 'flagged') flags.add(MessageFlag.flagged);

    return MessageEnvelope(
      localId: '', // 由仓储层填充
      ref: GraphRef(messageId: json['id'] as String, folderId: folder.remoteId),
      accountId: account.id,
      folderId: folder.id.isEmpty
          ? folder.remoteId
          : folder.id, // 使用 remoteId 作为临时 ID
      subject: json['subject'] as String? ?? '',
      date: DateTime.parse(json['receivedDateTime'] as String),
      from: fromAddr != null
          ? MailAddress(
              email: fromAddr['address'] as String,
              name: fromAddr['name'] as String?,
            )
          : null,
      to: toList
          .map((r) => _mapRecipient(r as Map<String, dynamic>))
          .whereType<MailAddress>()
          .toList(),
      cc: ccList
          .map((r) => _mapRecipient(r as Map<String, dynamic>))
          .whereType<MailAddress>()
          .toList(),
      preview: json['bodyPreview'] as String? ?? '',
      flags: flags,
      hasAttachments: json['hasAttachments'] as bool? ?? false,
      threadKey: json['conversationId'] as String?,
      messageIdHeader: json['internetMessageId'] as String?,
    );
  }

  MailAddress? _mapRecipient(Map<String, dynamic> json) {
    final addr = json['emailAddress'] as Map<String, dynamic>?;
    if (addr == null) return null;
    return MailAddress(
      email: addr['address'] as String,
      name: addr['name'] as String?,
    );
  }

  MailAttachment _mapAttachment(Map<String, dynamic> json) {
    return MailAttachment(
      partId: json['id'] as String,
      mimeType: json['contentType'] as String? ?? 'application/octet-stream',
      filename: json['name'] as String?,
      size: json['size'] as int?,
    );
  }
}
