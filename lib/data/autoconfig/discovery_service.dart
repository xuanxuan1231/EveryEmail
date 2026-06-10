import 'package:enough_mail/discover.dart' as em;

import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';
import 'autoconfig_client.dart';
import 'doh_dns_resolver.dart';
import 'local_provider_presets.dart';

/// 自动配置发现结果。
class DiscoveryResult {
  const DiscoveryResult({
    required this.suggestedType,
    required this.displayName,
    this.imap,
    this.smtp,
    this.suggestedLoginName,
    this.loginHint,
    this.prefersOAuth = false,
  });

  /// 推断的账户类型（决定登录方式与后端）。
  final AccountType suggestedType;

  /// 提供商展示名（如 "Google Mail"），可能为空。
  final String? displayName;

  /// 发现的 IMAP 配置（microsoftGraph 时通常忽略，邮件走 Graph）。
  final ServerConfig? imap;

  /// 发现的 SMTP 配置。
  final ServerConfig? smtp;

  /// 建议的 IMAP/SMTP 登录名：按 autoconfig 的用户名类型推导（全地址或 local-part），
  /// 或本地预设给定。为空表示无明确建议，UI 应回退到完整邮箱地址。
  final String? suggestedLoginName;

  /// 登录引导文案（如「需使用授权码」），来自本地预设；为空则无提示。
  final String? loginHint;

  /// autoconfig 是否声明该入站服务器使用 OAuth2（用于提示/未来扩展）。
  final bool prefersOAuth;

  bool get hasImapSmtp => imap != null && smtp != null;
}

/// Thunderbird 式自动配置服务。
///
/// 发现顺序：域名分类 → Microsoft 短路 → 国内本地预设 → O365 识别（DoH CNAME/SRV）
/// → SRV 记录（DoH）→ well-known autoconfig → enough_mail（子域 + ISPDB + 猜测）
/// → MX 兜底（DoH）。结果归一化为本应用的 [ServerConfig]，按域名/主机判定提供商类型。
class DiscoveryService {
  DiscoveryService({
    DohDnsResolver? dnsResolver,
    AutoconfigClient? autoconfigClient,
  })  : _dns = dnsResolver ?? DohDnsResolver(),
        _autoconfig = autoconfigClient ?? AutoconfigClient();

  final DohDnsResolver _dns;
  final AutoconfigClient _autoconfig;

  /// Gmail / Google Workspace 的固定 IMAP/SMTP 端点。
  /// Workspace 自定义域也用这些（IMAP 始终是 imap.gmail.com）。
  static const ServerConfig gmailImap = ServerConfig(
    host: 'imap.gmail.com',
    port: 993,
    socketType: SocketType.ssl,
  );
  static const ServerConfig gmailSmtp = ServerConfig(
    host: 'smtp.gmail.com',
    port: 465,
    socketType: SocketType.ssl,
  );

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

    // 国内主流邮箱：优先用本地预设，避开 ISPDB 网络不稳定，并附授权码提示。
    final preset = ProviderPresets.lookup(email);
    if (preset != null) {
      return DiscoveryResult(
        suggestedType: AccountType.genericImap,
        displayName: preset.displayName,
        imap: preset.imap,
        smtp: preset.smtp,
        suggestedLoginName: email, // 国内邮箱均以完整地址登录
        loginHint: preset.loginHint,
      );
    }

    final domain = _domainOf(email);

    // O365 自定义域识别：autodiscover CNAME / _autodiscover._tcp SRV 指向 outlook
    // 即判定走 Graph（优先于 IMAP——O365 在本应用走 Graph REST）。
    if (await _isOffice365ByDns(domain)) {
      return const DiscoveryResult(
        suggestedType: AccountType.microsoftGraph,
        displayName: 'Microsoft 365 / Outlook',
      );
    }

    // SRV 记录发现（RFC 6186/8314）：DoH 多端点 fallback，网络受限地区亦可用。
    final viaSrv = await _discoverViaSrv(domain);
    if (viaSrv != null) {
      return DiscoveryResult(
        suggestedType: _refineType(type, viaSrv.imap),
        displayName: domain,
        imap: viaSrv.imap,
        smtp: viaSrv.smtp,
        suggestedLoginName: email,
      );
    }

    // well-known autoconfig（enough_mail 只查 autoconfig 子域，不查主域 well-known）。
    final viaWellKnown = await _autoconfig.fetchWellKnown(domain, email);
    if (viaWellKnown != null) {
      return DiscoveryResult(
        suggestedType: _refineType(type, viaWellKnown.imap),
        displayName: domain,
        imap: viaWellKnown.imap,
        smtp: viaWellKnown.smtp,
        suggestedLoginName: viaWellKnown.loginName ?? email,
      );
    }

    // 其余（含 Gmail 与未知域）尝试自动发现 IMAP/SMTP。
    final em.ClientConfig? config =
        await em.Discover.discover(email, forceSslConnection: true);

    if (config == null || config.isNotValid) {
      // enough_mail 无果：用 DoH 查 MX 推断托管商（大陆可用，绕开被墙的 Google DoH）。
      final viaMx = await _discoverViaMx(domain, email);
      if (viaMx != null) return viaMx;

      // Gmail 已知域即使发现失败也能用已知端点兜底。
      if (type == AccountType.gmailOAuth) {
        return DiscoveryResult(
          suggestedType: AccountType.gmailOAuth,
          displayName: 'Google Mail',
          imap: gmailImap,
          smtp: gmailSmtp,
          suggestedLoginName: email, // Gmail XOAUTH2 以完整邮箱为登录名
        );
      }
      return null;
    }

    final imapServer = config.preferredIncomingImapServer;
    final imap = _mapServer(imapServer);
    final smtp = _mapServer(config.preferredOutgoingSmtpServer);

    // 若发现的 IMAP 主机指向 Google，且域不在已知列表（如 Workspace 自定义域），
    // 也升级为 Gmail OAuth。
    final resolvedType = _refineType(type, imap);

    return DiscoveryResult(
      suggestedType: resolvedType,
      displayName: config.displayName,
      imap: imap,
      smtp: smtp,
      suggestedLoginName: deriveLoginName(imapServer?.usernameType, email),
      prefersOAuth: imapServer?.authentication == em.Authentication.oauth2,
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

  /// O365 自定义域识别（DoH，大陆可用）：`autodiscover.<域>` CNAME 或
  /// `_autodiscover._tcp.<域>` SRV 目标指向 `*.outlook.com` 即认为托管在 O365。
  Future<bool> _isOffice365ByDns(String domain) async {
    final cnames = await _dns.lookupCname('autodiscover.$domain');
    if (cnames.any((c) => c.contains('outlook.com'))) return true;

    final srv = await _dns.lookupSrv('_autodiscover._tcp.$domain');
    if (srv.any((s) => s.target.toLowerCase().contains('outlook.com'))) {
      return true;
    }
    return false;
  }

  /// 经 SRV 记录发现 IMAP+SMTP（二者齐备才算成功）。
  Future<({ServerConfig imap, ServerConfig smtp})?> _discoverViaSrv(
    String domain,
  ) async {
    final imap = await _bestSrv(
      secureName: '_imaps._tcp.$domain',
      secureSocket: SocketType.ssl,
      plainName: '_imap._tcp.$domain',
      plainSocket: SocketType.starttls,
    );
    if (imap == null) return null;

    final smtp = await _bestSrv(
      secureName: '_submissions._tcp.$domain',
      secureSocket: SocketType.ssl,
      plainName: '_submission._tcp.$domain',
      plainSocket: SocketType.starttls,
    );
    if (smtp == null) return null;

    return (imap: imap, smtp: smtp);
  }

  /// 查一对 SRV：优先安全变体（imaps/submissions→SSL），回退明文变体
  /// （imap/submission→STARTTLS）。取 priority 最小（同级 weight 更大）的记录。
  Future<ServerConfig?> _bestSrv({
    required String secureName,
    required SocketType secureSocket,
    required String plainName,
    required SocketType plainSocket,
  }) async {
    final secure = _lowestPriority(await _dns.lookupSrv(secureName));
    if (secure != null) {
      return ServerConfig(
        host: secure.target,
        port: secure.port,
        socketType: secureSocket,
      );
    }
    final plain = _lowestPriority(await _dns.lookupSrv(plainName));
    if (plain != null) {
      return ServerConfig(
        host: plain.target,
        port: plain.port,
        socketType: plainSocket,
      );
    }
    return null;
  }

  SrvRecord? _lowestPriority(List<SrvRecord> records) {
    if (records.isEmpty) return null;
    final sorted = [...records]..sort(
        (a, b) => a.priority != b.priority
            ? a.priority.compareTo(b.priority)
            : b.weight.compareTo(a.weight),
      );
    return sorted.first;
  }

  /// 按 MX 主机名推断托管商类型（Google / Microsoft）；无法判定返回 `null`。
  /// 公开静态以便单元测试。
  static AccountType? hostingFromMxHost(String mxHost) {
    final host = mxHost.toLowerCase();
    if (host.contains('google') ||
        host.contains('googlemail') ||
        host.contains('aspmx')) {
      return AccountType.gmailOAuth;
    }
    if (host.contains('outlook') ||
        host.contains('office365') ||
        host.contains('protection.outlook')) {
      return AccountType.microsoftGraph;
    }
    return null;
  }

  /// MX 兜底：按 preference 最小的 MX 主机名推断 Gmail / Microsoft 托管。
  Future<DiscoveryResult?> _discoverViaMx(String domain, String email) async {
    final mx = await _dns.lookupMx(domain);
    if (mx.isEmpty) return null;
    final sorted = [...mx]..sort((a, b) => a.preference.compareTo(b.preference));
    switch (hostingFromMxHost(sorted.first.exchange)) {
      case AccountType.gmailOAuth:
        return DiscoveryResult(
          suggestedType: AccountType.gmailOAuth,
          displayName: 'Google Workspace',
          imap: gmailImap,
          smtp: gmailSmtp,
          suggestedLoginName: email,
        );
      case AccountType.microsoftGraph:
        return const DiscoveryResult(
          suggestedType: AccountType.microsoftGraph,
          displayName: 'Microsoft 365 / Outlook',
        );
      case AccountType.genericImap:
      case null:
        return null;
    }
  }

  /// 按 autoconfig 的 [em.UsernameType] 推导建议登录名。
  ///
  /// 注意：不可复用 enough_mail 的 [em.ServerConfig.getUserName]——其 emailLocalPart
  /// 分支误返回域名（取了 `@` 之后的片段）。这里自行取 `@` 之前的本地部分。
  /// 公开静态以便单元测试。
  static String? deriveLoginName(em.UsernameType? type, String email) {
    switch (type) {
      case em.UsernameType.emailAddress:
        return email;
      case em.UsernameType.emailLocalPart:
        final at = email.lastIndexOf('@');
        return at == -1 ? email : email.substring(0, at);
      case em.UsernameType.realName:
      case em.UsernameType.unknown:
      case null:
        return null; // 交由 UI 回退到完整邮箱
    }
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
