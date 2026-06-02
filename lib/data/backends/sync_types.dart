import '../../domain/models/mailbox_folder.dart';
import '../../domain/models/message_envelope.dart';
import '../../domain/models/message_ref.dart';

/// 分页游标。IMAP 按 UID 范围向更旧翻页，Graph 用 skip/nextLink。
class PageCursor {
  const PageCursor({this.beforeImapUid, this.graphNextLink, this.offset = 0});

  /// IMAP：取 UID < 此值的更旧邮件；为空表示从最新开始。
  final int? beforeImapUid;

  /// Graph：上一页返回的 @odata.nextLink。
  final String? graphNextLink;

  /// 通用偏移量（兜底）。
  final int offset;

  static const PageCursor start = PageCursor();
}

/// 增量同步结果：自上次游标以来的变更集。
class SyncResult {
  const SyncResult({
    this.added = const [],
    this.updated = const [],
    this.removedRefs = const [],
    this.newToken,
  });

  /// 新增邮件。
  final List<MessageEnvelope> added;

  /// 标志/属性变更的邮件。
  final List<MessageEnvelope> updated;

  /// 被删除（expunge / @removed）邮件的后端引用。
  final List<MessageRef> removedRefs;

  /// 新的同步令牌（IMAP: 序列化的 uidNext/modseq；Graph: deltaLink）。
  final SyncToken? newToken;
}

/// 不透明同步令牌：后端各自序列化自身游标。
class SyncToken {
  const SyncToken(this.value);

  /// IMAP 形如 "uidnext=123;modseq=456"；Graph 为 deltaLink URL。
  final String value;
}

/// 推送事件（IMAP IDLE 实时 / Graph 轮询包装）。
sealed class MailboxEvent {
  const MailboxEvent();
}

/// 有新邮件到达。
class MailArrivedEvent extends MailboxEvent {
  const MailArrivedEvent(this.envelopes);
  final List<MessageEnvelope> envelopes;
}

/// 邮件被删除/移除。
class MailVanishedEvent extends MailboxEvent {
  const MailVanishedEvent(this.refs);
  final List<MessageRef> refs;
}

/// 邮件标志/属性变更。
class MailUpdatedEvent extends MailboxEvent {
  const MailUpdatedEvent(this.envelopes);
  final List<MessageEnvelope> envelopes;
}

/// 文件夹元数据变化（如未读数），建议触发一次轻量重同步。
class FolderChangedEvent extends MailboxEvent {
  const FolderChangedEvent(this.folder);
  final MailboxFolder folder;
}
