import '../enums/account_enums.dart';

/// 服务器连接配置（IMAP / SMTP）。来自自动配置或手动输入。
class ServerConfig {
  const ServerConfig({
    required this.host,
    required this.port,
    required this.socketType,
  });

  final String host;
  final int port;
  final SocketType socketType;

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'socketType': socketType.index,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        host: json['host'] as String,
        port: json['port'] as int,
        socketType: SocketType.values[json['socketType'] as int],
      );
}

/// 账户领域模型（UI / 后端工厂消费）。
///
/// 凭据本身不在此（存安全存储），这里只有指向它的 [secretRef]。
class AccountConfig {
  const AccountConfig({
    required this.id,
    required this.email,
    required this.displayName,
    required this.type,
    required this.authType,
    this.secretRef,
    this.imap,
    this.smtp,
    this.loginName,
    this.colorValue,
  });

  final String id;
  final String email;
  final String displayName;
  final AccountType type;
  final AuthType authType;

  /// 安全存储中凭据条目的键。
  final String? secretRef;

  /// IMAP/SMTP 配置（microsoftGraph 类型为空）。
  final ServerConfig? imap;
  final ServerConfig? smtp;

  /// 登录名（默认等于 email）。
  final String? loginName;
  final int? colorValue;

  String get effectiveLoginName => loginName ?? email;
}
