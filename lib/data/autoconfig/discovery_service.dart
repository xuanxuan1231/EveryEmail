import 'package:enough_mail/discover.dart' as em;

import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';

/// 自动配置发现结果。
class DiscoveryResult {
  const DiscoveryResult({
    required this.suggestedType,
    required this.displayName,
    this.imap,
    this.smtp,
  });

  /// 推断的账户类型（决定登录方式与后端）。
  final AccountType suggestedType;

  /// 提供商展示名（如 "Google Mail"），可能为空。
  final String? displayName;

  /// 发现的 IMAP 配置（microsoftGraph 时通常忽略，邮件走 Graph）。
  final ServerConfig? imap;

  /// 发现的 SMTP 配置。
  final ServerConfig? smtp;

  bool get hasImapSmtp => imap != null && smtp != null;
}

/// Thunderbird 式自动配置服务。
///
/// 封装 enough_mail 的 [em.Discover]（autoconfig 子域 + MX + Mozilla ISPDB + 常见域猜测），
/// 把结果归一化为本应用的 [ServerConfig]，并按域名/主机判定提供商类型。
class DiscoveryService {
  const DiscoveryService();

  /// Gmail / Google Workspace 的已知域。
  static const _googleDomains = {'gmail.com', 'googlemail.com'};

  /// Microsoft 个人账户的已知域。
  static const _microsoftDomains = {
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'passport.com',
  };

  /// Office 365 / Exchange Online 的 IMAP/SMTP 服务器。
  static const _office365ImapHosts = {
    'outlook.office365.com',
    'imap-mail.outlook.com',
  };

  /// 根据邮箱地址发现配置。网络失败/无结果时返回 `null`。
  Future<DiscoveryResult?> discover(String email) async {
    final type = classify(email);

    // Microsoft 走 Graph：无需 IMAP/SMTP 发现，直接返回类型即可。
    if (type == AccountType.microsoftGraph) {
      return const DiscoveryResult(
        suggestedType: AccountType.microsoftGraph,
        displayName: 'Microsoft 365 / Outlook',
      );
    }

    // 其余（含 Gmail 与未知域）尝试自动发现 IMAP/SMTP。
    final em.ClientConfig? config =
        await em.Discover.discover(email, forceSslConnection: true);

    if (config == null || config.isNotValid) {
      // Gmail 即使发现失败也能用已知端点兜底。
      if (type == AccountType.gmailOAuth) {
        return DiscoveryResult(
          suggestedType: AccountType.gmailOAuth,
          displayName: 'Google Mail',
          imap: const ServerConfig(
            host: 'imap.gmail.com',
            port: 993,
            socketType: SocketType.ssl,
          ),
          smtp: const ServerConfig(
            host: 'smtp.gmail.com',
            port: 465,
            socketType: SocketType.ssl,
          ),
        );
      }
      return null;
    }

    final imap = _mapServer(config.preferredIncomingImapServer);
    final smtp = _mapServer(config.preferredOutgoingSmtpServer);

    // 若发现的 IMAP 主机指向 Google，且域不在已知列表（如 Workspace 自定义域），
    // 也升级为 Gmail OAuth。
    final resolvedType = _refineType(type, imap);

    return DiscoveryResult(
      suggestedType: resolvedType,
      displayName: config.displayName,
      imap: imap,
      smtp: smtp,
    );
  }

  /// 仅按邮箱域名做初步分类（不触发网络）。
  AccountType classify(String email) {
    final domain = _domainOf(email);
    if (_googleDomains.contains(domain)) return AccountType.gmailOAuth;
    if (_microsoftDomains.contains(domain)) return AccountType.microsoftGraph;
    return AccountType.genericImap;
  }

  /// 结合发现到的 IMAP 主机名细化类型（自定义域托管在 Google 的情况）。
  AccountType _refineType(AccountType initial, ServerConfig? imap) {
    if (initial != AccountType.genericImap) return initial;
    final host = imap?.host.toLowerCase() ?? '';

    // 检查是否是 Google 服务器
    if (host.contains('imap.gmail.com') || host.endsWith('.googlemail.com')) {
      return AccountType.gmailOAuth;
    }

    // 检查是否是 Office 365 服务器
    if (_isOffice365Server(host)) {
      return AccountType.microsoftGraph;
    }

    return AccountType.genericImap;
  }

  /// 检查是否是 Office 365 服务器。
  bool _isOffice365Server(String host) {
    return _office365ImapHosts.contains(host) ||
        host.contains('outlook.office365.com');
  }

  String _domainOf(String email) {
    final at = email.lastIndexOf('@');
    if (at == -1) return email.toLowerCase();
    return email.substring(at + 1).toLowerCase();
  }

  /// enough_mail [em.ServerConfig] → 本应用 [ServerConfig]。
  ServerConfig? _mapServer(em.ServerConfig? server) {
    if (server == null || server.hostname.isEmpty) return null;
    return ServerConfig(
      host: server.hostname,
      port: server.port,
      socketType: _mapSocket(server.socketType),
    );
  }

  SocketType _mapSocket(em.SocketType socket) {
    switch (socket) {
      case em.SocketType.ssl:
        return SocketType.ssl;
      case em.SocketType.starttls:
        return SocketType.starttls;
      case em.SocketType.plain:
      case em.SocketType.plainNoStartTls:
        return SocketType.plain;
      case em.SocketType.unknown:
        return SocketType.ssl; // 安全默认
    }
  }
}
