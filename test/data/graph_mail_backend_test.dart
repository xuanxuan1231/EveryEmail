import 'dart:convert';
import 'dart:io';

import 'package:everyemail/data/backends/graph/graph_mail_backend.dart';
import 'package:everyemail/data/backends/sync_types.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:everyemail/domain/models/account_config.dart';
import 'package:everyemail/domain/models/mail_address.dart';
import 'package:everyemail/domain/models/mailbox_folder.dart';
import 'package:everyemail/domain/models/message_ref.dart';
import 'package:everyemail/domain/models/outgoing_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GraphMailBackend', () {
    late HttpServer server;
    late Uri baseUri;
    late List<_CapturedRequest> captured;

    setUp(() async {
      captured = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse(
        'http://${server.address.address}:${server.port}/v1.0',
      );
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        captured.add(
          _CapturedRequest(
            method: request.method,
            path: _graphPath(request.uri),
            prefer: request.headers.value('prefer'),
            authorization: request.headers.value('authorization'),
            body: body,
          ),
        );
        await _handleGraphRequest(request, baseUri);
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('adds ImmutableId Prefer header to Graph mail requests', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'graph_mail_backend_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final attachmentFile = File('${tempDir.path}/note.txt');
      await attachmentFile.writeAsString('hello');

      final backend = GraphMailBackend(
        account: const AccountConfig(
          id: 'acc-graph',
          email: 'me@example.com',
          displayName: 'Me',
          type: AccountType.microsoftGraph,
          authType: AuthType.oauth,
        ),
        tokenProvider: () async => 'token-123',
        baseUrl: baseUri.toString(),
      );
      final folder = const MailboxFolder(
        id: 'folder-local',
        accountId: 'acc-graph',
        remoteId: 'folder',
        displayName: 'Inbox',
        type: FolderType.inbox,
      );
      final target = const MailboxFolder(
        id: 'target-local',
        accountId: 'acc-graph',
        remoteId: 'target',
        displayName: 'Target',
        type: FolderType.custom,
      );
      final ref = const GraphRef(messageId: 'msg', folderId: 'folder');
      final draft = OutgoingMessage(
        from: const MailAddress(email: 'me@example.com'),
        to: const [MailAddress(email: 'you@example.com')],
        subject: 'Draft',
        text: 'Body',
        attachments: [
          OutgoingAttachment(
            filename: 'note.txt',
            mimeType: 'text/plain',
            localPath: attachmentFile.path,
            size: await attachmentFile.length(),
          ),
        ],
      );

      await backend.listFolders();
      await backend.fetchEnvelopes(folder);
      await backend.fetchEnvelopes(
        folder,
        cursor: PageCursor(
          graphNextLink:
              '${baseUri.toString()}/me/mailFolders/folder/messages?\$skiptoken=next',
        ),
      );
      await backend.syncDelta(folder, null);
      await backend.syncDelta(
        folder,
        SyncToken(
          '${baseUri.toString()}/me/mailFolders/folder/messages/delta?\$deltatoken=old',
        ),
      );
      await backend.fetchMessageContent(ref);
      await backend.fetchAttachmentBytes(ref, 'att');
      await backend.markRead([ref], read: true);
      await backend.markFlagged([ref], flagged: true);
      await backend.moveToFolder([ref], target);
      await backend.archive([ref]);
      await backend.delete([ref]);
      await backend.saveDraft(draft);
      await backend.sendMessage(draft.copyWith(serverDraftId: 'draft'));
      await backend.deleteDraft('draft');

      expect(captured, isNotEmpty);
      expect(
        captured.where((r) => r.path.startsWith('/me/')),
        everyElement(
          predicate<_CapturedRequest>(
            (r) =>
                r.prefer == 'IdType="ImmutableId"' &&
                r.authorization == 'Bearer token-123',
            'has ImmutableId Prefer and bearer auth',
          ),
        ),
      );
      expect(
        captured.map((r) => '${r.method} ${r.path}'),
        containsAll(<String>[
          'GET /me/mailFolders',
          'GET /me/mailFolders/folder/messages',
          'GET /me/mailFolders/folder/messages/delta',
          'GET /me/messages/msg',
          'GET /me/messages/msg/attachments/att/\$value',
          'PATCH /me/messages/msg',
          'POST /me/messages/msg/move',
          'DELETE /me/messages/msg',
          'POST /me/messages',
          'PATCH /me/messages/draft',
          'GET /me/messages/draft/attachments',
          'DELETE /me/messages/draft/attachments/old-att',
          'POST /me/messages/draft/attachments',
          'POST /me/messages/draft/send',
          'DELETE /me/messages/draft',
        ]),
      );
    });
  });
}

String _graphPath(Uri uri) {
  final path = uri.path;
  return path.startsWith('/v1.0') ? path.substring('/v1.0'.length) : path;
}

Future<void> _handleGraphRequest(HttpRequest request, Uri baseUri) async {
  final path = _graphPath(request.uri);
  final response = request.response;

  if (request.method == 'GET' && path == '/me/mailFolders') {
    return _json(response, {'value': <Object?>[]});
  }

  if (request.method == 'GET' && path.startsWith('/me/mailFolders/')) {
    if (path.endsWith('/messages')) {
      return _json(response, {'value': <Object?>[]});
    }
    if (path.endsWith('/messages/delta')) {
      return _json(response, {
        'value': <Object?>[],
        '@odata.deltaLink':
            '${baseUri.toString()}/me/mailFolders/folder/messages/delta?\$deltatoken=new',
      });
    }
    final id = path.split('/').last;
    return _json(response, {'id': 'folder-$id'});
  }

  if (request.method == 'GET' &&
      path == '/me/messages/msg/attachments/att/\$value') {
    response.headers.contentType = ContentType.binary;
    response.add([1, 2, 3]);
    return response.close();
  }

  if (request.method == 'GET' && path == '/me/messages/msg') {
    return _json(response, {
      'id': 'msg',
      'isDraft': true,
      'parentFolderId': 'folder',
      'conversationId': 'conversation',
      'body': {'contentType': 'html', 'content': '<p>Hello</p>'},
      'attachments': [
        {
          'id': 'att',
          'name': 'note.txt',
          'contentType': 'text/plain',
          'size': 3,
        },
      ],
    });
  }

  if (request.method == 'POST' && path == '/me/messages') {
    return _json(response, {
      'id': 'draft',
      'parentFolderId': 'drafts',
      'conversationId': 'conversation',
    });
  }

  if (request.method == 'PATCH' && path == '/me/messages/draft') {
    return _json(response, {'id': 'draft'});
  }

  if (request.method == 'GET' && path == '/me/messages/draft/attachments') {
    return _json(response, {
      'value': [
        {'id': 'old-att'},
      ],
    });
  }

  if (request.method == 'DELETE' &&
      path == '/me/messages/draft/attachments/old-att') {
    response.statusCode = HttpStatus.noContent;
    return response.close();
  }

  if (request.method == 'POST' && path == '/me/messages/draft/attachments') {
    return _json(response, {'id': 'new-att'});
  }

  if (request.method == 'GET' && path == '/me/messages/draft') {
    return _json(response, {
      'id': 'draft',
      'parentFolderId': 'drafts',
      'conversationId': 'conversation',
      'isDraft': true,
    });
  }

  if (request.method == 'POST' && path == '/me/messages/draft/send') {
    response.statusCode = HttpStatus.accepted;
    return response.close();
  }

  if (request.method == 'DELETE' && path == '/me/messages/draft') {
    response.statusCode = HttpStatus.noContent;
    return response.close();
  }

  if (request.method == 'PATCH' && path == '/me/messages/msg') {
    return _json(response, {'id': 'msg'});
  }

  if (request.method == 'POST' && path == '/me/messages/msg/move') {
    return _json(response, {'id': 'msg'});
  }

  if (request.method == 'DELETE' && path == '/me/messages/msg') {
    response.statusCode = HttpStatus.noContent;
    return response.close();
  }

  response.statusCode = HttpStatus.notFound;
  return _json(response, {'error': 'Unhandled ${request.method} $path'});
}

Future<void> _json(HttpResponse response, Object? data) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(data));
  return response.close();
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.prefer,
    required this.authorization,
    required this.body,
  });

  final String method;
  final String path;
  final String? prefer;
  final String? authorization;
  final String body;
}
