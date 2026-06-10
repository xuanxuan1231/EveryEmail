import 'package:everyemail/data/autoconfig/doh_dns_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DohDnsResolver.parseSrvData', () {
    test('标准 SRV → 字段正确、去尾点', () {
      final r = DohDnsResolver.parseSrvData('10 5 993 imap.example.com.');
      expect(r, isNotNull);
      expect(r!.priority, 10);
      expect(r.weight, 5);
      expect(r.port, 993);
      expect(r.target, 'imap.example.com');
    });

    test('target "." → null（服务显式不可用）', () {
      expect(DohDnsResolver.parseSrvData('0 0 0 .'), isNull);
    });

    test('字段不足或非数字 → null', () {
      expect(DohDnsResolver.parseSrvData('10 5 993'), isNull);
      expect(DohDnsResolver.parseSrvData('a b c host'), isNull);
    });

    test('多空格容错', () {
      final r = DohDnsResolver.parseSrvData('  1   0   587   smtp.x.io.  ');
      expect(r?.port, 587);
      expect(r?.target, 'smtp.x.io');
    });
  });

  group('DohDnsResolver.parseMxData', () {
    test('标准 MX → preference + exchange（去尾点、转小写）', () {
      final r = DohDnsResolver.parseMxData('10 ASPMX.L.GOOGLE.COM.');
      expect(r, isNotNull);
      expect(r!.preference, 10);
      expect(r.exchange, 'aspmx.l.google.com');
    });

    test('字段不足 / 空 exchange → null', () {
      expect(DohDnsResolver.parseMxData('10'), isNull);
      expect(DohDnsResolver.parseMxData('10 .'), isNull);
    });
  });
}
