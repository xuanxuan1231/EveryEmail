import 'app_database.dart';
import '../../../domain/enums/message_enums.dart';

/// 邮件 + 来源账户信息的联合查询结果（用于统一账户的聚合文件夹）。
class MessageWithAccount {
  const MessageWithAccount({
    required this.message,
    required this.accountId,
    required this.accountEmail,
    required this.accountDisplayName,
    required this.folderType,
    this.accountColorValue,
  });

  final Message message;
  final String accountId;
  final String accountEmail;
  final String accountDisplayName;
  final FolderType folderType;
  final int? accountColorValue;
}
