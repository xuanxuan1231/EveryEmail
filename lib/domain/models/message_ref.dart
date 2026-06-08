/// 后端无关的邮件标识引用。
///
/// IMAP 用 (folderPath, uid, uidValidity)，Graph 用 (messageId, folderId)。
/// 仓储层用稳定的内部 `localId` 关联到 Drift 行，但与后端交互时需要这个原生引用。
sealed class MessageRef {
  const MessageRef();
}

/// IMAP 邮件引用：UID 在 (folder, uidValidity) 范围内唯一。
class ImapRef extends MessageRef {
  const ImapRef({
    required this.folderPath,
    required this.uid,
    required this.uidValidity,
  });

  final String folderPath;
  final int uid;
  final int uidValidity;

  @override
  bool operator ==(Object other) =>
      other is ImapRef &&
      other.folderPath == folderPath &&
      other.uid == uid &&
      other.uidValidity == uidValidity;

  @override
  int get hashCode => Object.hash(folderPath, uid, uidValidity);

  @override
  String toString() => 'ImapRef($folderPath#$uid/$uidValidity)';
}

/// Graph 邮件引用：immutable message id（建议用 immutable id 头避免移动后失效）。
class GraphRef extends MessageRef {
  const GraphRef({required this.messageId, required this.folderId});

  final String messageId;
  final String folderId;

  @override
  bool operator ==(Object other) =>
      other is GraphRef &&
      other.messageId == messageId &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(messageId, folderId);

  @override
  String toString() => 'GraphRef($messageId@$folderId)';
}

/// Gmail 邮件引用：Gmail REST API 的全邮箱唯一 message id。
///
/// [labelId] 是观察到该邮件时所在的标签（文件夹），移动（改标签）时用作要移除的
/// 源标签——与 [GraphRef.folderId] 同理。[threadId] 为 Gmail 线程 id（落 threadKey）。
class GmailRef extends MessageRef {
  const GmailRef({
    required this.messageId,
    required this.labelId,
    this.threadId,
  });

  final String messageId;
  final String labelId;
  final String? threadId;

  @override
  bool operator ==(Object other) =>
      other is GmailRef &&
      other.messageId == messageId &&
      other.labelId == labelId;

  @override
  int get hashCode => Object.hash(messageId, labelId);

  @override
  String toString() => 'GmailRef($messageId@$labelId)';
}
