import 'package:enough_mail/discover.dart' as em;
import 'package:everyemail/data/autoconfig/autoconfig_client.dart';
import 'package:everyemail/data/autoconfig/discovery_service.dart';
import 'package:everyemail/data/autoconfig/doh_dns_resolver.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/models/account_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// 注入用假 DNS：返回预置 SRV/MX/CNAME，绝不联网。
class _FakeDns implements DohDnsResolver {
  _FakeDns({
    Map<String, List<SrvRecord>>? srv,
    List<MxRecord>? mx,
    Map<String, List<String>>? cname,
  })  : _srv = srv ?? const {},
        _mx = mx ?? const [],
        _cname = cname ?? const {};

  final Map<String, List<SrvRecord>> _srv;
  final List<MxRecord> _mx;
  final Map<String, List<String>> _cname;

  @override
  Future<List<SrvRecord>> lookupSrv(String name) async => _srv[name] ?? const [];

  @override
  Future<List<MxRecord>> lookupMx(String domain) async => _mx;

  @override
  Future<List<String>> lookupCname(String name) async =>
      _cname[name] ?? const [];
}

/// 注入用假 well-known 客户端：返回预置结果，绝不联网。
class _FakeAutoconfig implements AutoconfigClient {
  _FakeAutoconfig({this.result});

  final AutoconfigResult? result;

  @override
  Future<AutoconfigResult?> fetchWellKnown(String domain, String email) async =>
      result;
}

void main() {
  // 默认实例：classify / MS 短路 / 本地预设均在 DNS/HTTP 步骤前返回，不会联网。
  final service = DiscoveryService();

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

    test('国内预设域仍判定为 genericImap（不影响 classify）', () {
      expect(service.classify('a@qq.com'), AccountType.genericImap);
      expect(service.classify('a@163.com'), AccountType.genericImap);
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

  group('DiscoveryService.discover（国内邮箱本地预设，无网络）', () {
    test('QQ 域命中本地预设：genericImap + 预设端点 + 登录提示', () async {
      final result = await service.discover('user@qq.com');
      expect(result, isNotNull);
      expect(result!.suggestedType, AccountType.genericImap);
      expect(result.imap?.host, 'imap.qq.com');
      expect(result.imap?.port, 993);
      expect(result.smtp?.host, 'smtp.qq.com');
      expect(result.suggestedLoginName, 'user@qq.com');
      expect(result.loginHint, isNotNull);
    });

    test('163 域命中本地预设，登录名为完整地址', () async {
      final result = await service.discover('me@163.com');
      expect(result?.imap?.host, 'imap.163.com');
      expect(result?.suggestedLoginName, 'me@163.com');
    });
  });

  group('DiscoveryService.discover（O365 识别，注入假 DNS）', () {
    test('autodiscover CNAME 指向 outlook → microsoftGraph', () async {
      final dns = _FakeDns(cname: {
        'autodiscover.corp.example': ['autodiscover.outlook.com'],
      });
      final svc = DiscoveryService(dnsResolver: dns);
      final result = await svc.discover('a@corp.example');
      expect(result?.suggestedType, AccountType.microsoftGraph);
      expect(result?.hasImapSmtp, isFalse);
    });

    test('_autodiscover._tcp SRV 指向 outlook → microsoftGraph', () async {
      final dns = _FakeDns(srv: {
        '_autodiscover._tcp.corp.example': [
          const SrvRecord(
              priority: 0,
              weight: 0,
              port: 443,
              target: 'autodiscover.outlook.com'),
        ],
      });
      final svc = DiscoveryService(dnsResolver: dns);
      final result = await svc.discover('a@corp.example');
      expect(result?.suggestedType, AccountType.microsoftGraph);
    });
  });

  group('DiscoveryService.discover（SRV 发现，注入假 DNS）', () {
    test('_imaps + _submissions 命中 → SSL imap/smtp', () async {
      final dns = _FakeDns(srv: {
        '_imaps._tcp.corp.example': [
          const SrvRecord(
              priority: 10, weight: 5, port: 993, target: 'imap.corp.example'),
        ],
        '_submissions._tcp.corp.example': [
          const SrvRecord(
              priority: 10, weight: 5, port: 465, target: 'smtp.corp.example'),
        ],
      });
      final svc = DiscoveryService(dnsResolver: dns);
      final result = await svc.discover('alice@corp.example');
      expect(result, isNotNull);
      expect(result!.suggestedType, AccountType.genericImap);
      expect(result.imap?.host, 'imap.corp.example');
      expect(result.imap?.port, 993);
      expect(result.imap?.socketType, SocketType.ssl);
      expect(result.smtp?.host, 'smtp.corp.example');
      expect(result.smtp?.socketType, SocketType.ssl);
      expect(result.suggestedLoginName, 'alice@corp.example');
    });

    test('仅明文变体 _imap/_submission → STARTTLS', () async {
      final dns = _FakeDns(srv: {
        '_imap._tcp.corp.example': [
          const SrvRecord(
              priority: 1, weight: 0, port: 143, target: 'imap.corp.example'),
        ],
        '_submission._tcp.corp.example': [
          const SrvRecord(
              priority: 1, weight: 0, port: 587, target: 'smtp.corp.example'),
        ],
      });
      final svc = DiscoveryService(dnsResolver: dns);
      final result = await svc.discover('a@corp.example');
      expect(result?.imap?.socketType, SocketType.starttls);
      expect(result?.imap?.port, 143);
      expect(result?.smtp?.port, 587);
      expect(result?.smtp?.socketType, SocketType.starttls);
    });

    test('SRV 取 priority 最小者', () async {
      final dns = _FakeDns(srv: {
        '_imaps._tcp.corp.example': [
          const SrvRecord(
              priority: 20, weight: 0, port: 993, target: 'backup.corp.example'),
          const SrvRecord(
              priority: 5, weight: 0, port: 993, target: 'primary.corp.example'),
        ],
        '_submissions._tcp.corp.example': [
          const SrvRecord(
              priority: 1, weight: 0, port: 465, target: 'smtp.corp.example'),
        ],
      });
      final svc = DiscoveryService(dnsResolver: dns);
      final result = await svc.discover('a@corp.example');
      expect(result?.imap?.host, 'primary.corp.example');
    });
  });

  group('DiscoveryService.discover（well-known，注入假客户端）', () {
    test('well-known 命中 → imap/smtp/loginName', () async {
      final ac = _FakeAutoconfig(
        result: const AutoconfigResult(
          imap: ServerConfig(
              host: 'imap.corp.example', port: 993, socketType: SocketType.ssl),
          smtp: ServerConfig(
              host: 'smtp.corp.example',
              port: 587,
              socketType: SocketType.starttls),
          loginName: 'user',
        ),
      );
      // 空 DNS：O365 识别 false、SRV 无果 → 走到 well-known。
      final svc = DiscoveryService(dnsResolver: _FakeDns(), autoconfigClient: ac);
      final result = await svc.discover('user@corp.example');
      expect(result, isNotNull);
      expect(result!.imap?.host, 'imap.corp.example');
      expect(result.smtp?.socketType, SocketType.starttls);
      expect(result.suggestedLoginName, 'user');
    });
  });

  group('DiscoveryService.hostingFromMxHost（MX 主机名推断）', () {
    test('Google MX → gmailOAuth', () {
      expect(DiscoveryService.hostingFromMxHost('aspmx.l.google.com'),
          AccountType.gmailOAuth);
      expect(DiscoveryService.hostingFromMxHost('ALT1.ASPMX.L.GOOGLE.COM'),
          AccountType.gmailOAuth);
    });

    test('Microsoft MX → microsoftGraph', () {
      expect(
        DiscoveryService.hostingFromMxHost(
            'corp-com.mail.protection.outlook.com'),
        AccountType.microsoftGraph,
      );
    });

    test('其他 MX → null', () {
      expect(DiscoveryService.hostingFromMxHost('mx.qq.com'), isNull);
      expect(DiscoveryService.hostingFromMxHost('mx1.fastmail.com'), isNull);
    });
  });

  group('DiscoveryService.deriveLoginName', () {
    test('emailAddress -> 完整地址', () {
      expect(
        DiscoveryService.deriveLoginName(
          em.UsernameType.emailAddress,
          'a@b.com',
        ),
        'a@b.com',
      );
    });

    test('emailLocalPart -> @ 前部分（修正 enough_mail 的 bug）', () {
      expect(
        DiscoveryService.deriveLoginName(
          em.UsernameType.emailLocalPart,
          'alice@corp.com',
        ),
        'alice',
      );
    });

    test('realName / unknown / null -> null（UI 回退到邮箱）', () {
      expect(
        DiscoveryService.deriveLoginName(em.UsernameType.realName, 'a@b.com'),
        isNull,
      );
      expect(
        DiscoveryService.deriveLoginName(em.UsernameType.unknown, 'a@b.com'),
        isNull,
      );
      expect(DiscoveryService.deriveLoginName(null, 'a@b.com'), isNull);
    });
  });
}
