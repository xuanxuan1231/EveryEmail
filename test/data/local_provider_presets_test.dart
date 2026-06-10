import 'package:everyemail/data/autoconfig/local_provider_presets.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderPresets.lookup', () {
    test('QQ 域命中（含 foxmail / vip.qq.com）', () {
      final qq = ProviderPresets.lookup('user@qq.com');
      expect(qq, isNotNull);
      expect(qq!.imap.host, 'imap.qq.com');
      expect(qq.imap.port, 993);
      expect(qq.imap.socketType, SocketType.ssl);
      expect(qq.smtp.host, 'smtp.qq.com');
      expect(qq.loginHint, isNotNull);

      expect(ProviderPresets.lookup('a@foxmail.com')?.imap.host, 'imap.qq.com');
      expect(ProviderPresets.lookup('a@vip.qq.com')?.imap.host, 'imap.qq.com');
    });

    test('网易 163/126/yeah 命中各自服务器', () {
      expect(ProviderPresets.lookup('a@163.com')?.imap.host, 'imap.163.com');
      expect(ProviderPresets.lookup('a@126.com')?.imap.host, 'imap.126.com');
      expect(ProviderPresets.lookup('a@yeah.net')?.imap.host, 'imap.yeah.net');
    });

    test('新浪 / 阿里云 / 移动139 命中', () {
      expect(ProviderPresets.lookup('a@sina.com')?.imap.host, 'imap.sina.com');
      expect(ProviderPresets.lookup('a@aliyun.com')?.imap.host, 'imap.aliyun.com');
      expect(ProviderPresets.lookup('a@139.com')?.imap.host, 'imap.139.com');
    });

    test('域名大小写不敏感', () {
      expect(ProviderPresets.lookup('USER@QQ.COM')?.displayName, 'QQ 邮箱');
    });

    test('未知域 / 非法地址返回 null', () {
      expect(ProviderPresets.lookup('a@example.com'), isNull);
      expect(ProviderPresets.lookup('not-an-email'), isNull);
    });

    test('所有预设均为隐式 SSL 标准端口', () {
      for (final preset in ProviderPresets.all) {
        expect(preset.imap.port, 993, reason: preset.displayName);
        expect(preset.smtp.port, 465, reason: preset.displayName);
        expect(preset.imap.socketType, SocketType.ssl, reason: preset.displayName);
        expect(preset.smtp.socketType, SocketType.ssl, reason: preset.displayName);
      }
    });
  });
}
