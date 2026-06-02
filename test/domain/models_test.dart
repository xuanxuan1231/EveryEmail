import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:everyemail/domain/models/mail_address.dart';
import 'package:everyemail/domain/models/message_flags.dart';
import 'package:everyemail/domain/models/message_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageFlags 位掩码', () {
    test('空集合 <-> 0', () {
      expect(MessageFlags.toBitmask({}), 0);
      expect(MessageFlags.fromBitmask(0), <MessageFlag>{});
    });

    test('往返一致', () {
      final flags = {MessageFlag.seen, MessageFlag.flagged};
      final mask = MessageFlags.toBitmask(flags);
      expect(MessageFlags.fromBitmask(mask), flags);
    });

    test('has / withFlag', () {
      var mask = 0;
      mask = MessageFlags.withFlag(mask, MessageFlag.seen, true);
      expect(MessageFlags.has(mask, MessageFlag.seen), isTrue);
      expect(MessageFlags.has(mask, MessageFlag.flagged), isFalse);

      mask = MessageFlags.withFlag(mask, MessageFlag.seen, false);
      expect(MessageFlags.has(mask, MessageFlag.seen), isFalse);
    });
  });

  group('MailAddress', () {
    test('displayName 优先 name，回退 email', () {
      expect(const MailAddress(email: 'a@b.com', name: 'A').displayName, 'A');
      expect(const MailAddress(email: 'a@b.com').displayName, 'a@b.com');
      expect(const MailAddress(email: 'a@b.com', name: '').displayName, 'a@b.com');
    });

    test('JSON 往返', () {
      const addr = MailAddress(email: 'a@b.com', name: 'A');
      expect(MailAddress.fromJson(addr.toJson()), addr);
    });
  });

  group('MessageRef union', () {
    test('ImapRef 相等性', () {
      const a = ImapRef(folderPath: 'INBOX', uid: 1, uidValidity: 10);
      const b = ImapRef(folderPath: 'INBOX', uid: 1, uidValidity: 10);
      const c = ImapRef(folderPath: 'INBOX', uid: 2, uidValidity: 10);
      expect(a, b);
      expect(a == c, isFalse);
    });

    test('GraphRef 相等性', () {
      const a = GraphRef(messageId: 'x', folderId: 'inbox');
      const b = GraphRef(messageId: 'x', folderId: 'inbox');
      expect(a, b);
    });

    test('sealed switch 穷尽', () {
      String describe(MessageRef ref) => switch (ref) {
            ImapRef() => 'imap',
            GraphRef() => 'graph',
          };
      expect(
        describe(const ImapRef(folderPath: 'INBOX', uid: 1, uidValidity: 1)),
        'imap',
      );
      expect(describe(const GraphRef(messageId: 'x', folderId: 'y')), 'graph');
    });
  });
}
