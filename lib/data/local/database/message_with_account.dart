import 'app_database.dart';

/// 邮件 + 来源账户信息的联合查询结果（用于统一账户的聚合文件夹）。
class MessageWithAccount {
  const MessageWithAccount({
    required this.message,
    required this.accountEmail,
    required this.accountDisplayName,
    this.accountColorValue,
  });

  final Message message;
  final String accountEmail;
  final String accountDisplayName;
  final int? accountColorValue;
}
