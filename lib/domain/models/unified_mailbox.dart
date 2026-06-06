import '../enums/message_enums.dart';

/// 虚拟的统一账户。
///
/// 它不对应远端邮箱账号，也不持久化邮件；统一文件夹通过查询真实账户的
/// 特殊文件夹动态形成。
class UnifiedMailboxAccount {
  const UnifiedMailboxAccount({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.colorValue,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final int colorValue;
}

/// 统一账户下的虚拟文件夹定义与运行时摘要。
class UnifiedMailboxFolder {
  const UnifiedMailboxFolder({
    required this.id,
    required this.displayName,
    required this.title,
    required this.type,
    this.unreadCount = 0,
    this.totalCount = 0,
    this.sourceAccountCount = 0,
  });

  final String id;
  final String displayName;
  final String title;
  final FolderType type;
  final int unreadCount;
  final int totalCount;
  final int sourceAccountCount;

  UnifiedMailboxFolder copyWith({
    int? unreadCount,
    int? totalCount,
    int? sourceAccountCount,
  }) {
    return UnifiedMailboxFolder(
      id: id,
      displayName: displayName,
      title: title,
      type: type,
      unreadCount: unreadCount ?? this.unreadCount,
      totalCount: totalCount ?? this.totalCount,
      sourceAccountCount: sourceAccountCount ?? this.sourceAccountCount,
    );
  }
}

/// 统一化的固定规则。
///
/// 当前没有逐文件夹开关，所有列在这里的特殊文件夹都会被统一化。
class UnifiedMailbox {
  const UnifiedMailbox._();

  static const account = UnifiedMailboxAccount(
    id: 'unified-account',
    displayName: '统一账户',
    subtitle: '聚合文件夹',
    colorValue: 0xFF1A73E8,
  );

  static const inbox = UnifiedMailboxFolder(
    id: 'unified-folder-inbox',
    displayName: '收件箱',
    title: '统一收件箱',
    type: FolderType.inbox,
  );

  static const sent = UnifiedMailboxFolder(
    id: 'unified-folder-sent',
    displayName: '已发送',
    title: '统一已发送',
    type: FolderType.sent,
  );

  static const drafts = UnifiedMailboxFolder(
    id: 'unified-folder-drafts',
    displayName: '草稿箱',
    title: '统一草稿箱',
    type: FolderType.drafts,
  );

  static const folders = <UnifiedMailboxFolder>[inbox, sent, drafts];

  static bool isUnifiedAccountId(String? accountId) {
    return accountId == account.id;
  }

  static bool isUnifiedFolderId(String? folderId) {
    return folderById(folderId) != null;
  }

  static bool isUnifiedFolderType(FolderType type) {
    return folders.any((folder) => folder.type == type);
  }

  static UnifiedMailboxFolder? folderById(String? folderId) {
    if (folderId == null) return null;
    for (final folder in folders) {
      if (folder.id == folderId) return folder;
    }
    return null;
  }
}
