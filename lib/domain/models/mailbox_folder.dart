import '../enums/message_enums.dart';

/// 后端无关的文件夹模型（UI 消费）。
///
/// 同步游标（uidValidity/deltaLink 等）不在这里，存在 SyncState 表。
class MailboxFolder {
  const MailboxFolder({
    required this.id,
    required this.accountId,
    required this.remoteId,
    required this.displayName,
    required this.type,
    this.parentId,
    this.unreadCount = 0,
    this.totalCount = 0,
  });

  /// 内部稳定主键。
  final String id;
  final String accountId;

  /// 后端原生标识：IMAP 路径或 Graph folderId。
  final String remoteId;
  final String displayName;
  final FolderType type;
  final String? parentId;
  final int unreadCount;
  final int totalCount;

  MailboxFolder copyWith({
    String? displayName,
    FolderType? type,
    String? parentId,
    int? unreadCount,
    int? totalCount,
  }) {
    return MailboxFolder(
      id: id,
      accountId: accountId,
      remoteId: remoteId,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      unreadCount: unreadCount ?? this.unreadCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
