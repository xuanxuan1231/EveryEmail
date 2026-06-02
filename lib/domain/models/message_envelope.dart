import '../enums/message_enums.dart';
import 'mail_address.dart';
import 'message_ref.dart';

/// 后端无关的邮件信封（列表级元数据，不含正文）。
class MessageEnvelope {
  const MessageEnvelope({
    required this.localId,
    required this.ref,
    required this.accountId,
    required this.folderId,
    required this.subject,
    required this.date,
    this.from,
    this.to = const [],
    this.cc = const [],
    this.preview = '',
    this.flags = const {},
    this.hasAttachments = false,
    this.threadKey,
    this.messageIdHeader,
    this.labels = const [],
  });

  /// 内部稳定主键（= Drift Messages.id）。
  final String localId;

  /// 后端原生引用。
  final MessageRef ref;

  final String accountId;
  final String folderId;

  final String subject;
  final DateTime date;
  final MailAddress? from;
  final List<MailAddress> to;
  final List<MailAddress> cc;
  final String preview;

  /// 归一化标志位。
  final Set<MessageFlag> flags;
  final bool hasAttachments;

  /// 线程键（IMAP 推导 / Graph conversationId）。
  final String? threadKey;
  final String? messageIdHeader;

  /// 后端独有标签（Gmail labels / Graph categories）。
  final List<String> labels;

  bool get isUnread => !flags.contains(MessageFlag.seen);
  bool get isFlagged => flags.contains(MessageFlag.flagged);
}
