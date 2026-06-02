import 'package:dio/dio.dart';

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

/// Microsoft Graph 后端实现。
///
/// 使用 Graph REST API v1.0：
/// - /me/mailFolders - 文件夹列表
/// - /me/messages - 邮件查询
/// - /me/mailFolders/{id}/messages/delta - 增量同步
class GraphMailBackend implements MailBackend {
  GraphMailBackend({
    required this.account,
    required this.tokenProvider,
  }) : _dio = Dio(BaseOptions(
          baseUrl: 'https://graph.microsoft.com/v1.0',
          headers: {'Content-Type': 'application/json'},
        )) {
    // 添加认证拦截器
    _dio.interceptors.add(InterceptorsWrapper(
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
    ));
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
      await _dio.get('/me');
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
      final listFuture = _dio.get(
        '/me/mailFolders',
        queryParameters: {
          '\$select': 'id,displayName,unreadItemCount,totalItemCount',
          '\$top': 100,
        },
      );

      final aliasFutures = _wellKnownAliases.entries.map((e) async {
        try {
          final r = await _dio.get(
            '/me/mailFolders/${e.key}',
            queryParameters: {'\$select': 'id'},
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
      throw MailBackendException(
        '列出文件夹失败 (HTTP $status): $body',
        cause: e,
      );
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
  Future<List<MessageEnvelope>> fetchEnvelopes(
    MailboxFolder folder, {
    PageCursor cursor = PageCursor.start,
    int limit = 50,
  }) async {
    try {
      final params = {
        '\$top': limit,
        '\$orderby': 'receivedDateTime desc',
        '\$select': 'id,subject,from,toRecipients,ccRecipients,'
            'receivedDateTime,bodyPreview,isRead,flag,hasAttachments,'
            'conversationId,internetMessageId',
      };

      if (cursor.graphNextLink != null) {
        // 使用 Graph 的 nextLink
        final response = await _dio.get(cursor.graphNextLink!);
        final messages = (response.data['value'] as List)
            .map((json) => _mapMessage(json as Map<String, dynamic>, folder))
            .toList();
        return messages;
      }

      if (cursor.offset > 0) {
        params['\$skip'] = cursor.offset.toString();
      }

      final response = await _dio.get(
        '/me/mailFolders/${folder.remoteId}/messages',
        queryParameters: params,
      );

      final messages = (response.data['value'] as List)
          .map((json) => _mapMessage(json as Map<String, dynamic>, folder))
          .toList();

      return messages;
    } on DioException catch (e) {
      throw MailBackendException('拉取信封失败', cause: e);
    }
  }

  @override
  Future<MimeContent> fetchMessageContent(MessageRef ref) async {
    if (ref is! GraphRef) {
      throw const MailBackendException('GraphMailBackend 需要 GraphRef');
    }

    try {
      final response = await _dio.get('/me/messages/${ref.messageId}');
      final json = response.data as Map<String, dynamic>;

      // 获取正文
      final body = json['body'] as Map<String, dynamic>?;
      final bodyContent = body?['content'] as String?;
      final bodyType = body?['contentType'] as String?;

      // 获取附件
      final attachmentsResponse = await _dio.get(
        '/me/messages/${ref.messageId}/attachments',
        queryParameters: {'\$select': 'id,name,contentType,size'},
      );

      final attachments = (attachmentsResponse.data['value'] as List)
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
      final response = await _dio.get(
        '/me/messages/${ref.messageId}/attachments/$partId/\$value',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data as List<int>;
    } on DioException catch (e) {
      throw MailBackendException('下载附件失败', cause: e);
    }
  }

  @override
  Future<SyncResult> syncDelta(MailboxFolder folder, SyncToken? token) async {
    try {
      final url = token?.value ??
          '/me/mailFolders/${folder.remoteId}/messages/delta';

      final response = await _dio.get(
        url,
        queryParameters: {
          '\$select': 'id,subject,from,toRecipients,ccRecipients,'
              'receivedDateTime,bodyPreview,isRead,flag,hasAttachments,'
              'conversationId,internetMessageId',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final deltaLink = data['@odata.deltaLink'] as String?;

      final added = <MessageEnvelope>[];
      final removedRefs = <MessageRef>[];

      for (final item in data['value'] as List) {
        final json = item as Map<String, dynamic>;
        if (json.containsKey('@removed')) {
          // 邮件已删除
          removedRefs.add(GraphRef(
            messageId: json['id'] as String,
            folderId: folder.remoteId,
          ));
        } else {
          // 新增或更新
          added.add(_mapMessage(json, folder));
        }
      }

      return SyncResult(
        added: added,
        removedRefs: removedRefs,
        newToken: deltaLink != null ? SyncToken(deltaLink) : null,
      );
    } on DioException catch (e) {
      throw MailBackendException('增量同步失败', cause: e);
    }
  }

  @override
  Future<void> markRead(List<MessageRef> refs, {required bool read}) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      try {
        await _dio.patch(
          '/me/messages/${ref.messageId}',
          data: {'isRead': read},
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> markFlagged(List<MessageRef> refs, {required bool flagged}) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      try {
        await _dio.patch(
          '/me/messages/${ref.messageId}',
          data: {
            'flag': {'flagStatus': flagged ? 'flagged' : 'notFlagged'}
          },
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> moveToFolder(List<MessageRef> refs, MailboxFolder target) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      try {
        await _dio.post(
          '/me/messages/${ref.messageId}/move',
          data: {'destinationId': target.remoteId},
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> delete(List<MessageRef> refs) async {
    for (final ref in refs) {
      if (ref is! GraphRef) continue;
      try {
        await _dio.delete('/me/messages/${ref.messageId}');
      } catch (_) {}
    }
  }

  @override
  Stream<MailboxEvent> watch(MailboxFolder folder) async* {
    // Graph 推送需要 webhooks（复杂），这里简化为轮询
    yield* Stream.periodic(const Duration(seconds: 60), (_) async {
      final result = await syncDelta(folder, null);
      return MailArrivedEvent(result.added);
    }).asyncMap((event) => event);
  }

  MailboxFolder _mapFolder(Map<String, dynamic> json, {required FolderType type}) {
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
      ref: GraphRef(
        messageId: json['id'] as String,
        folderId: folder.remoteId,
      ),
      accountId: account.id,
      folderId: folder.id.isEmpty ? folder.remoteId : folder.id, // 使用 remoteId 作为临时 ID
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
