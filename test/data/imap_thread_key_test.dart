import 'package:everyemail/data/backends/imap/imap_thread_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// IMAP 会话根键推导回归（`deriveImapThreadKey` / `firstMessageId`）。
///
/// 关键不变量：同一会话的所有回复，其 References 头都以同一个根 message-id 开头，
/// 取链首即得稳定共享键；缺 References 时退回 In-Reply-To，再退回自身 Message-ID。
void main() {
  group('deriveImapThreadKey', () {
    test('References 多 id → 取链首根 id', () {
      expect(
        deriveImapThreadKey(
          references: '<root@a.com> <reply1@a.com> <reply2@a.com>',
          inReplyTo: '<reply2@a.com>',
          messageId: '<reply3@a.com>',
        ),
        '<root@a.com>',
      );
    });

    test('同一会话不同成员推导出相同的根键', () {
      const root = '<root@a.com>';
      final a = deriveImapThreadKey(messageId: root); // 根邮件自身
      final b = deriveImapThreadKey(
        references: '$root <r1@a.com>',
        inReplyTo: root,
        messageId: '<r1@a.com>',
      );
      final c = deriveImapThreadKey(
        references: '$root <r1@a.com> <r2@a.com>',
        messageId: '<r2@a.com>',
      );
      expect(a, root);
      expect(b, root);
      expect(c, root);
    });

    test('无 References，有 In-Reply-To → 取 In-Reply-To', () {
      expect(
        deriveImapThreadKey(
          inReplyTo: '<parent@a.com>',
          messageId: '<self@a.com>',
        ),
        '<parent@a.com>',
      );
    });

    test('仅有 Message-ID → 退回自身', () {
      expect(deriveImapThreadKey(messageId: '<self@a.com>'), '<self@a.com>');
    });

    test('全空 → null', () {
      expect(deriveImapThreadKey(), isNull);
      expect(
        deriveImapThreadKey(references: '  ', inReplyTo: '', messageId: null),
        isNull,
      );
    });
  });

  group('firstMessageId', () {
    test('取第一个尖括号 id（忽略前后空白）', () {
      expect(firstMessageId('  <a@x.com>  <b@x.com> '), '<a@x.com>');
    });

    test('无尖括号 → 取首个空白分隔 token', () {
      expect(firstMessageId('a@x.com b@x.com'), 'a@x.com');
    });

    test('null / 空串 → null', () {
      expect(firstMessageId(null), isNull);
      expect(firstMessageId('   '), isNull);
    });
  });
}
