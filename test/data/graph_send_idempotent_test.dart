import 'dart:convert';
import 'dart:io';

import 'package:everyemail/data/backends/graph/graph_mail_backend.dart';
import 'package:everyemail/data/backends/mail_backend.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/models/account_config.dart';
import 'package:everyemail/domain/models/mail_address.dart';
import 'package:everyemail/domain/models/outgoing_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// GraphMailBackend.sendMessage 的草稿回写与幂等发送回归。
///
/// 用可编程的本地 HttpServer：每个用例自行设定 /send 返回码与草稿是否仍为草稿，
/// 以覆盖「发送其实已成功、响应丢失」这类需要幂等兜底的路径。
void main() {
  group('GraphMailBackend.sendMessage 幂等与草稿回写', () {
    late HttpServer server;
    late Uri baseUri;
    late List<String> hits;
    late int sendStatus; // POST .../draft/send 的返回码
    late bool draftIsDraft; // GET /me/messages/draft 的 isDraft

    setUp(() async {
      hits = [];
      sendStatus = HttpStatus.accepted;
      draftIsDraft = true;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse(
        'http://${server.address.address}:${server.port}/v1.0',
      );
      server.listen((req) async {
        final path = _path(req.uri);
        await utf8.decoder.bind(req).join();
        hits.add('${req.method} $path');
        final res = req.response;

        if (req.method == 'POST' && path == '/me/messages') {
          return _json(res, {
            'id': 'draft',
            'parentFolderId': 'drafts',
            'conversationId': 'c',
          });
        }
        if (req.method == 'PATCH' && path == '/me/messages/draft') {
          return _json(res, {'id': 'draft'});
        }
        if (req.method == 'GET' && path == '/me/messages/draft/attachments') {
          return _json(res, {'value': <Object?>[]});
        }
        if (req.method == 'GET' && path == '/me/messages/draft') {
          return _json(res, {
            'id': 'draft',
            'parentFolderId': 'drafts',
            'conversationId': 'c',
            'isDraft': draftIsDraft,
          });
        }
        if (req.method == 'POST' && path == '/me/messages/draft/send') {
          res.statusCode = sendStatus;
          if (sendStatus >= 400) return _json(res, {'error': 'boom'});
          return res.close();
        }
        res.statusCode = HttpStatus.notFound;
        return _json(res, {'error': 'unhandled ${req.method} $path'});
      });
    });

    tearDown(() async => server.close(force: true));

    GraphMailBackend backend() => GraphMailBackend(
      account: const AccountConfig(
        id: 'a',
        email: 'me@example.com',
        displayName: 'Me',
        type: AccountType.microsoftGraph,
        authType: AuthType.oauth,
      ),
      tokenProvider: () async => 'token',
      baseUrl: baseUri.toString(),
    );

    OutgoingMessage msg({String? serverDraftId}) => OutgoingMessage(
      from: const MailAddress(email: 'me@example.com'),
      to: const [MailAddress(email: 'you@example.com')],
      subject: 'S',
      text: 'B',
      serverDraftId: serverDraftId,
    );

    test('新建草稿发送：恰好回写一次 draftId 并真正发送', () async {
      final persisted = <String>[];
      await backend().sendMessage(
        msg(),
        onDraftPersisted: (id) async => persisted.add(id),
      );
      expect(persisted, ['draft']);
      expect(hits, contains('POST /me/messages/draft/send'));
    });

    test('发送阶段失败但草稿已被消费：幂等返回，不抛、不再次发送', () async {
      sendStatus = HttpStatus.notFound; // 非可重试
      draftIsDraft = false; // 探测：已不是草稿 → 视为上次已发出
      // 更新既有草稿路径不应回写（draftId 未变）。
      final persisted = <String>[];
      await backend().sendMessage(
        msg(serverDraftId: 'draft'),
        onDraftPersisted: (id) async => persisted.add(id),
      );
      expect(persisted, isEmpty);
    });

    test('发送失败且草稿仍在：抛出 MailBackendException', () async {
      sendStatus = HttpStatus.badRequest; // 非可重试
      draftIsDraft = true; // 草稿仍在 → 真失败
      await expectLater(
        backend().sendMessage(msg(serverDraftId: 'draft')),
        throwsA(isA<MailBackendException>()),
      );
    });
  });
}

String _path(Uri uri) {
  final path = uri.path;
  return path.startsWith('/v1.0') ? path.substring('/v1.0'.length) : path;
}

Future<void> _json(HttpResponse response, Object? data) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(data));
  return response.close();
}
