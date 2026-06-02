import 'package:everyemail/data/autoconfig/discovery_service.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = DiscoveryService();

  group('DiscoveryService.classify（离线域名判定）', () {
    test('Gmail 域 -> gmailOAuth', () {
      expect(service.classify('a@gmail.com'), AccountType.gmailOAuth);
      expect(service.classify('a@googlemail.com'), AccountType.gmailOAuth);
    });

    test('Microsoft 域 -> microsoftGraph', () {
      expect(service.classify('a@outlook.com'), AccountType.microsoftGraph);
      expect(service.classify('a@hotmail.com'), AccountType.microsoftGraph);
      expect(service.classify('a@live.com'), AccountType.microsoftGraph);
    });

    test('其他域 -> genericImap', () {
      expect(service.classify('a@example.com'), AccountType.genericImap);
      expect(service.classify('a@fastmail.com'), AccountType.genericImap);
    });

    test('大小写不敏感', () {
      expect(service.classify('A@GMAIL.COM'), AccountType.gmailOAuth);
    });
  });

  group('DiscoveryService.discover（Microsoft 短路，无网络）', () {
    test('Microsoft 域直接返回 Graph 类型且无需 IMAP/SMTP', () async {
      final result = await service.discover('a@outlook.com');
      expect(result, isNotNull);
      expect(result!.suggestedType, AccountType.microsoftGraph);
      expect(result.hasImapSmtp, isFalse);
    });
  });
}
