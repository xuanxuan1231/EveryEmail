import 'package:everyemail/data/backends/gmail/gmail_batch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gmailBatchBoundary', () {
    test('extracts unquoted boundary', () {
      expect(
        gmailBatchBoundary('multipart/mixed; boundary=batch_abc123'),
        'batch_abc123',
      );
    });

    test('extracts quoted boundary', () {
      expect(
        gmailBatchBoundary('multipart/mixed; boundary="batch_xyz"'),
        'batch_xyz',
      );
    });

    test('returns null when boundary absent', () {
      expect(gmailBatchBoundary('application/json'), isNull);
    });
  });

  group('parseGmailBatchResponse', () {
    const boundary = 'batch_abc123';
    const contentType = 'multipart/mixed; boundary=$boundary';

    test('parses ordered sub-responses with status + json body', () {
      // 仿 Gmail /batch/gmail/v1 的 multipart/mixed 响应（\r\n 行尾）：两条 200 + 一条 404。
      final body = [
        '--$boundary',
        'Content-Type: application/http',
        'Content-ID: response-1',
        '',
        'HTTP/1.1 200 OK',
        'Content-Type: application/json; charset=UTF-8',
        'Vary: Origin',
        '',
        '{"id":"msg1","threadId":"t1","labelIds":["INBOX","UNREAD"],'
            '"snippet":"hello"}',
        '--$boundary',
        'Content-Type: application/http',
        'Content-ID: response-2',
        '',
        'HTTP/1.1 200 OK',
        'Content-Type: application/json; charset=UTF-8',
        '',
        '{"id":"msg2","threadId":"t2","labelIds":["INBOX"],"snippet":"world"}',
        '--$boundary',
        'Content-Type: application/http',
        'Content-ID: response-3',
        '',
        'HTTP/1.1 404 Not Found',
        'Content-Type: application/json; charset=UTF-8',
        '',
        '{"error":{"code":404,"message":"Not Found"}}',
        '--$boundary--',
        '',
      ].join('\r\n');

      final parts = parseGmailBatchResponse(body, contentType);

      expect(parts.length, 3);

      expect(parts[0].status, 200);
      expect(parts[0].json?['id'], 'msg1');
      expect(parts[0].json?['labelIds'], ['INBOX', 'UNREAD']);

      expect(parts[1].status, 200);
      expect(parts[1].json?['id'], 'msg2');

      // 404 仍解析出 error JSON；调用方据 status 决定丢弃/重试（这里嵌套花括号也要正确）。
      expect(parts[2].status, 404);
      expect(parts[2].json?['error'], isNotNull);
    });

    test('returns empty when boundary missing from content-type', () {
      expect(parseGmailBatchResponse('whatever', 'application/json'), isEmpty);
    });

    test('returns empty for empty body', () {
      expect(parseGmailBatchResponse('', contentType), isEmpty);
    });

    test('skips a segment with no inner HTTP response', () {
      final body = [
        '--$boundary',
        'Content-Type: application/http',
        '',
        'garbage with no http status line',
        '--$boundary--',
      ].join('\r\n');
      expect(parseGmailBatchResponse(body, contentType), isEmpty);
    });
  });
}
