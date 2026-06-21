import 'package:everyemail/domain/models/mail_address.dart';
import 'package:everyemail/features/compose/compose_args.dart';
import 'package:flutter_test/flutter_test.dart';

/// 收件人文本解析回归：撰写/回复/转发都依赖它在「文本 ⇄ 地址列表」间转换。
void main() {
  test('按逗号/分号/换行切分，解析姓名与邮箱', () {
    final parsed = RecipientParsing.parse(
      'a@b.com, C <c@d.com>; "D, E" <e@f.com>\ng@h.com',
    );
    expect(parsed.map((a) => a.email), [
      'a@b.com',
      'c@d.com',
      'e@f.com',
      'g@h.com',
    ]);
    expect(parsed[1].name, 'C');
    // 引号内的姓名（含逗号）应被完整保留，不被当作分隔符。
    expect(parsed[2].name, 'D, E');
  });

  test('空白与多余分隔符被忽略', () {
    expect(RecipientParsing.parse('  '), isEmpty);
    expect(RecipientParsing.parse(',,; '), isEmpty);
    expect(RecipientParsing.parse('a@b.com,').map((a) => a.email), ['a@b.com']);
  });

  test('format 与 parse 往返一致', () {
    const addresses = [
      MailAddress(email: 'a@b.com', name: '甲'),
      MailAddress(email: 'c@d.com'),
    ];
    final text = RecipientParsing.format(addresses);
    expect(text, '甲 <a@b.com>, c@d.com');
    final back = RecipientParsing.parse(text);
    expect(back[0].email, 'a@b.com');
    expect(back[0].name, '甲');
    expect(back[1].email, 'c@d.com');
    expect(back[1].name, isNull);
  });

  test('isValidEmail 基本校验', () {
    expect(RecipientParsing.isValidEmail('a@b.com'), isTrue);
    expect(RecipientParsing.isValidEmail('a.b+c@x.co.uk'), isTrue);
    expect(RecipientParsing.isValidEmail('no-at'), isFalse);
    expect(RecipientParsing.isValidEmail('a@b'), isFalse);
    expect(RecipientParsing.isValidEmail('a b@c.com'), isFalse);
  });
}
