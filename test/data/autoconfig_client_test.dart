import 'package:everyemail/data/autoconfig/autoconfig_client.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoconfigClient.parseAutoconfig', () {
    const standard = '''
<clientConfig version="1.1">
  <emailProvider id="corp.example">
    <domain>corp.example</domain>
    <displayName>Corp</displayName>
    <incomingServer type="imap">
      <hostname>imap.corp.example</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <username>%EMAILADDRESS%</username>
      <authentication>password-cleartext</authentication>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>smtp.corp.example</hostname>
      <port>587</port>
      <socketType>STARTTLS</socketType>
      <username>%EMAILLOCALPART%</username>
    </outgoingServer>
  </emailProvider>
</clientConfig>
''';

    test('标准 autoconfig → imap/smtp + socketType + loginName', () {
      final r = AutoconfigClient.parseAutoconfig(standard, 'alice@corp.example');
      expect(r, isNotNull);
      expect(r!.imap.host, 'imap.corp.example');
      expect(r.imap.port, 993);
      expect(r.imap.socketType, SocketType.ssl);
      expect(r.smtp.host, 'smtp.corp.example');
      expect(r.smtp.port, 587);
      expect(r.smtp.socketType, SocketType.starttls);
      // imap 的 username 模板是 %EMAILADDRESS% → 完整地址
      expect(r.loginName, 'alice@corp.example');
    });

    test('IMAP username=%EMAILLOCALPART% → loginName 取 @ 前', () {
      const x = '''
<clientConfig><emailProvider id="x">
<incomingServer type="imap"><hostname>imap.x.io</hostname><port>993</port>
<socketType>SSL</socketType><username>%EMAILLOCALPART%</username></incomingServer>
<outgoingServer type="smtp"><hostname>smtp.x.io</hostname><port>465</port>
<socketType>SSL</socketType><username>%EMAILADDRESS%</username></outgoingServer>
</emailProvider></clientConfig>''';
      final r = AutoconfigClient.parseAutoconfig(x, 'bob@x.io');
      expect(r?.loginName, 'bob');
    });

    test('缺 outgoingServer → null', () {
      const x = '''
<clientConfig><emailProvider id="x">
<incomingServer type="imap"><hostname>imap.x.io</hostname><port>993</port>
<socketType>SSL</socketType></incomingServer>
</emailProvider></clientConfig>''';
      expect(AutoconfigClient.parseAutoconfig(x, 'a@x.io'), isNull);
    });

    test('非法 XML → null', () {
      expect(AutoconfigClient.parseAutoconfig('not xml at all', 'a@x.io'),
          isNull);
    });
  });
}
