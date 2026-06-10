import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';

/// 国内主流邮箱的本地预设配置。
///
/// 这些服务商常因 Mozilla ISPDB（autoconfig.thunderbird.net）在国内访问不稳定
/// 而自动发现失败；且多数要求使用「授权码 / 客户端专用密码」而非登录密码。本表
/// 按邮箱域名精确命中，[DiscoveryService] 中优先于网络发现使用，并顺带给出开启
/// IMAP/授权码的引导文案。
class ProviderPreset {
  const ProviderPreset({
    required this.domains,
    required this.displayName,
    required this.imap,
    required this.smtp,
    this.loginHint,
  });

  /// 命中的邮箱域名（全部小写）。
  final Set<String> domains;

  /// 提供商展示名。
  final String displayName;

  /// IMAP / SMTP 服务器（隐式 SSL）。
  final ServerConfig imap;
  final ServerConfig smtp;

  /// 登录引导（如「需使用授权码」）。非空时展示在密码/手动设置页。
  final String? loginHint;
}

/// 主流个人邮箱预设表 + 域名查找。
class ProviderPresets {
  const ProviderPresets._();

  /// 网易系（163/126/yeah）与新浪、移动通用的授权码提示。
  static const String _authCodeHint =
      '该邮箱需先在网页端开启 IMAP/SMTP 服务，并使用生成的「授权码」代替登录密码。';

  /// 全部预设。匹配时按列表顺序取首个域名命中项。
  static const List<ProviderPreset> all = [
    ProviderPreset(
      domains: {'qq.com', 'vip.qq.com', 'foxmail.com'},
      displayName: 'QQ 邮箱',
      imap: ServerConfig(
        host: 'imap.qq.com',
        port: 993,
        socketType: SocketType.ssl,
      ),
      smtp: ServerConfig(
        host: 'smtp.qq.com',
        port: 465,
        socketType: SocketType.ssl,
      ),
      loginHint: 'QQ 邮箱需在「设置 → 账户」中开启 IMAP/SMTP 服务，并使用生成的授权码代替密码登录。',
    ),
    ProviderPreset(
      domains: {'163.com'},
      displayName: '网易 163 邮箱',
      imap: ServerConfig(
        host: 'imap.163.com',
        port: 993,
        socketType: SocketType.ssl,
      ),
      smtp: ServerConfig(
        host: 'smtp.163.com',
        port: 465,
        socketType: SocketType.ssl,
      ),
      loginHint: _authCodeHint,
    ),
    ProviderPreset(
      domains: {'126.com'},
      displayName: '网易 126 邮箱',
      imap: ServerConfig(
        host: 'imap.126.com',
        port: 993,
        socketType: SocketType.ssl,
      ),
      smtp: ServerConfig(
        host: 'smtp.126.com',
        port: 465,
        socketType: SocketType.ssl,
      ),
      loginHint: _authCodeHint,
    ),
    ProviderPreset(
      domains: {'yeah.net'},
      displayName: '网易 yeah.net 邮箱',
      imap: ServerConfig(
        host: 'imap.yeah.net',
        port: 993,
        socketType: SocketType.ssl,
      ),
      smtp: ServerConfig(
        host: 'smtp.yeah.net',
        port: 465,
        socketType: SocketType.ssl,
      ),
      loginHint: _authCodeHint,
    ),
    ProviderPreset(
      domains: {'sina.com', 'sina.cn'},
      displayName: '新浪邮箱',
      imap: ServerConfig(
        host: 'imap.sina.com',
        port: 993,
        socketType: SocketType.ssl,
      ),
      smtp: ServerConfig(
        host: 'smtp.sina.com',
        port: 465,
        socketType: SocketType.ssl,
      ),
      loginHint: _authCodeHint,
    ),
    ProviderPreset(
      domains: {'aliyun.com'},
      displayName: '阿里邮箱',
      imap: ServerConfig(
        host: 'imap.aliyun.com',
        port: 993,
        socketType: SocketType.ssl,
      ),
      smtp: ServerConfig(
        host: 'smtp.aliyun.com',
        port: 465,
        socketType: SocketType.ssl,
      ),
      loginHint: '阿里邮箱需在网页版开启 IMAP/SMTP 服务，并使用「客户端专用密码」代替登录密码。',
    ),
    ProviderPreset(
      domains: {'139.com'},
      displayName: '中国移动 139 邮箱',
      imap: ServerConfig(
        host: 'imap.139.com',
        port: 993,
        socketType: SocketType.ssl,
      ),
      smtp: ServerConfig(
        host: 'smtp.139.com',
        port: 465,
        socketType: SocketType.ssl,
      ),
      loginHint: _authCodeHint,
    ),
  ];

  /// 按邮箱域名（小写）精确匹配预设；未命中返回 `null`。
  static ProviderPreset? lookup(String email) {
    final at = email.lastIndexOf('@');
    if (at == -1) return null;
    final domain = email.substring(at + 1).toLowerCase();
    for (final preset in all) {
      if (preset.domains.contains(domain)) return preset;
    }
    return null;
  }
}
