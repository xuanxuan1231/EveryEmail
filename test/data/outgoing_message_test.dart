import 'package:everyemail/domain/models/mail_address.dart';
import 'package:everyemail/domain/models/outgoing_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// OutgoingMessage 序列化回归：发送队列把它编码为 JSON 持久化，跨重启/重试解码，
/// 字段必须完整往返（含附件与线程头）。
void main() {
  test('toJson/fromJson 完整往返', () {
    const message = OutgoingMessage(
      from: MailAddress(email: 'me@example.com', name: '我'),
      to: [
        MailAddress(email: 'a@x.com', name: 'A'),
        MailAddress(email: 'b@y.com'),
      ],
      cc: [MailAddress(email: 'c@z.com')],
      bcc: [MailAddress(email: 'd@z.com')],
      subject: 'Re: 你好',
      text: '正文\n第二行',
      html: '<div>正文</div>',
      inReplyTo: '<orig@x.com>',
      references: ['<root@x.com>', '<orig@x.com>'],
      action: OutgoingMessageAction.reply,
      sourceMessageId: 'graph-source-id',
      serverDraftId: 'draft-1',
      attachments: [
        OutgoingAttachment(
          filename: 'a.pdf',
          mimeType: 'application/pdf',
          localPath: '/tmp/a.pdf',
          size: 1234,
        ),
      ],
    );

    final restored = OutgoingMessage.decode(message.encode());

    expect(restored.from.email, 'me@example.com');
    expect(restored.from.name, '我');
    expect(restored.to.map((a) => a.email), ['a@x.com', 'b@y.com']);
    expect(restored.to.first.name, 'A');
    expect(restored.cc.single.email, 'c@z.com');
    expect(restored.bcc.single.email, 'd@z.com');
    expect(restored.subject, 'Re: 你好');
    expect(restored.text, '正文\n第二行');
    expect(restored.html, '<div>正文</div>');
    expect(restored.inReplyTo, '<orig@x.com>');
    expect(restored.references, ['<root@x.com>', '<orig@x.com>']);
    expect(restored.action, OutgoingMessageAction.reply);
    expect(restored.sourceMessageId, 'graph-source-id');
    expect(restored.serverDraftId, 'draft-1');
    expect(restored.attachments.single.filename, 'a.pdf');
    expect(restored.attachments.single.mimeType, 'application/pdf');
    expect(restored.attachments.single.localPath, '/tmp/a.pdf');
    expect(restored.attachments.single.size, 1234);
  });

  test('最小邮件（仅 from/text）也能往返', () {
    const message = OutgoingMessage(
      from: MailAddress(email: 'me@example.com'),
      subject: '',
      text: 'hi',
    );
    final restored = OutgoingMessage.decode(message.encode());
    expect(restored.from.email, 'me@example.com');
    expect(restored.from.name, isNull);
    expect(restored.to, isEmpty);
    expect(restored.html, isNull);
    expect(restored.inReplyTo, isNull);
    expect(restored.references, isEmpty);
    expect(restored.attachments, isEmpty);
    expect(restored.hasRecipient, isFalse);
  });

  test('hasRecipient / allRecipients 汇总 To+Cc+Bcc', () {
    const message = OutgoingMessage(
      from: MailAddress(email: 'me@example.com'),
      to: [MailAddress(email: 'a@x.com')],
      cc: [MailAddress(email: 'c@z.com')],
      bcc: [MailAddress(email: 'd@z.com')],
      subject: 's',
      text: 't',
    );
    expect(message.hasRecipient, isTrue);
    expect(message.allRecipients.map((a) => a.email), [
      'a@x.com',
      'c@z.com',
      'd@z.com',
    ]);
  });
}
