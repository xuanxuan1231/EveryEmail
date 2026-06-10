import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';

/// well-known autoconfig 的解析结果。
class AutoconfigResult {
  const AutoconfigResult({
    required this.imap,
    required this.smtp,
    this.loginName,
  });

  final ServerConfig imap;
  final ServerConfig smtp;

  /// 按 autoconfig `<username>` 模板推导的登录名；无明确模板则为 null。
  final String? loginName;
}

/// 抓取并解析主域 well-known 下的 Mozilla autoconfig 文件。
///
/// enough_mail 只查 `autoconfig.<域>` 子域，不查主域 `/.well-known/autoconfig/...`，
/// 本类补上这一标准路径（仅 HTTPS，不回退明文 http 以避免 MITM）。XML 格式同
/// Thunderbird autoconfig（clientConfig/emailProvider/incomingServer…）。
class AutoconfigClient {
  AutoconfigClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            );

  final Dio _dio;

  /// 抓取 `https://<domain>/.well-known/autoconfig/mail/config-v1.1.xml`。
  /// 失败/非 XML/缺 IMAP 或 SMTP → null。
  Future<AutoconfigResult?> fetchWellKnown(String domain, String email) async {
    final url = 'https://$domain/.well-known/autoconfig/mail/config-v1.1.xml';
    try {
      final resp = await _dio.get<String>(
        url,
        queryParameters: {'emailaddress': email},
        options: Options(responseType: ResponseType.plain),
      );
      final body = resp.data;
      if (body == null || body.isEmpty) return null;
      return parseAutoconfig(body, email);
    } catch (_) {
      return null;
    }
  }

  /// 解析 Mozilla autoconfig XML：取 `incomingServer[type=imap]` 与
  /// `outgoingServer[type=smtp]` 的 hostname/port/socketType，以及 IMAP 的
  /// `<username>` 模板（→loginName）。任一缺失或非法 → null。公开静态以便单测。
  static AutoconfigResult? parseAutoconfig(String xmlText, String email) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlText);
    } catch (_) {
      return null;
    }

    final incoming = _firstServer(doc, 'incomingServer', 'imap');
    final outgoing = _firstServer(doc, 'outgoingServer', 'smtp');
    final imap = _serverConfigFrom(incoming);
    final smtp = _serverConfigFrom(outgoing);
    if (imap == null || smtp == null || incoming == null) return null;

    final loginName = _loginFromUsername(_childText(incoming, 'username'), email);
    return AutoconfigResult(imap: imap, smtp: smtp, loginName: loginName);
  }

  static XmlElement? _firstServer(XmlDocument doc, String tag, String type) {
    for (final el in doc.findAllElements(tag)) {
      if (el.getAttribute('type')?.toLowerCase() == type) return el;
    }
    return null;
  }

  static ServerConfig? _serverConfigFrom(XmlElement? el) {
    if (el == null) return null;
    final host = _childText(el, 'hostname');
    final port = int.tryParse(_childText(el, 'port') ?? '');
    if (host == null || host.isEmpty || port == null) return null;
    return ServerConfig(
      host: host,
      port: port,
      socketType: _socketFrom(_childText(el, 'socketType')),
    );
  }

  static String? _childText(XmlElement el, String name) {
    for (final c in el.findElements(name)) {
      return c.innerText.trim();
    }
    return null;
  }

  static SocketType _socketFrom(String? socketType) {
    switch (socketType?.toUpperCase()) {
      case 'SSL':
        return SocketType.ssl;
      case 'STARTTLS':
        return SocketType.starttls;
      case 'PLAIN':
        return SocketType.plain;
      default:
        return SocketType.ssl; // 安全默认
    }
  }

  /// autoconfig `<username>` 模板 → 登录名。
  static String? _loginFromUsername(String? username, String email) {
    switch (username?.toUpperCase()) {
      case '%EMAILADDRESS%':
        return email;
      case '%EMAILLOCALPART%':
        final at = email.lastIndexOf('@');
        return at == -1 ? email : email.substring(0, at);
      default:
        return null; // %REALNAME% / 缺失 / 未知 → 交由 UI 回退到邮箱
    }
  }
}
