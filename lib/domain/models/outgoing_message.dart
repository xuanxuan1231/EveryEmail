import 'dart:convert';

import 'mail_address.dart';

/// 发送动作，用于后端选择普通撰写 / 回复 / 全部回复 / 转发的专用 API。
enum OutgoingMessageAction { newMessage, reply, replyAll, forward }

/// 一封待发送的邮件（后端无关）。
///
/// 由撰写页构建，交给发送队列持久化与重试，最终由各 [MailBackend.sendMessage]
/// 渲染为对应协议的载荷（IMAP/SMTP + Gmail 用 MIME；Graph 用 JSON）。
///
/// 线程关系通过 [inReplyTo] / [references] 这两个 RFC822 头表达——三种后端都据此
/// 把回复归并到原会话（Gmail/Graph 按 References 归并，无需各自的 threadId）。
class OutgoingMessage {
  const OutgoingMessage({
    required this.from,
    required this.subject,
    required this.text,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.html,
    this.inReplyTo,
    this.references = const [],
    this.attachments = const [],
    this.action = OutgoingMessageAction.newMessage,
    this.sourceMessageId,
    this.serverDraftId,
  });

  /// 发件人（= 选中账户的身份）。
  final MailAddress from;

  final List<MailAddress> to;
  final List<MailAddress> cc;
  final List<MailAddress> bcc;

  final String subject;

  /// 纯文本正文（始终存在，作为 multipart/alternative 的回退部件）。
  final String text;

  /// HTML 正文（可选）。存在时发送 multipart/alternative（text + html）。
  final String? html;

  /// 被回复邮件的 Message-ID（含尖括号），用于 In-Reply-To 头。
  final String? inReplyTo;

  /// References 链（各含尖括号的 Message-ID，按时间升序，末项通常即 [inReplyTo]）。
  final List<String> references;

  final List<OutgoingAttachment> attachments;

  /// 用户触发的发送动作。Graph 依赖它选择 createReply/createReplyAll/createForward。
  final OutgoingMessageAction action;

  /// 被回复/转发的后端原始 message id（Graph 专用；其它后端可忽略）。
  final String? sourceMessageId;

  /// 服务端草稿 id。Gmail 是 draft id；Graph 是 draft message id。
  final String? serverDraftId;

  /// 至少有一个收件人（To/Cc/Bcc 任一非空）。
  bool get hasRecipient => to.isNotEmpty || cc.isNotEmpty || bcc.isNotEmpty;

  /// 全部收件人（用于 SMTP 信封 RCPT）。
  List<MailAddress> get allRecipients => [...to, ...cc, ...bcc];

  OutgoingMessage copyWith({
    MailAddress? from,
    List<MailAddress>? to,
    List<MailAddress>? cc,
    List<MailAddress>? bcc,
    String? subject,
    String? text,
    String? html,
    String? inReplyTo,
    List<String>? references,
    List<OutgoingAttachment>? attachments,
    OutgoingMessageAction? action,
    String? sourceMessageId,
    String? serverDraftId,
  }) {
    return OutgoingMessage(
      from: from ?? this.from,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      text: text ?? this.text,
      html: html ?? this.html,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      references: references ?? this.references,
      attachments: attachments ?? this.attachments,
      action: action ?? this.action,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      serverDraftId: serverDraftId ?? this.serverDraftId,
    );
  }

  Map<String, dynamic> toJson() => {
    'from': from.toJson(),
    'to': [for (final a in to) a.toJson()],
    'cc': [for (final a in cc) a.toJson()],
    'bcc': [for (final a in bcc) a.toJson()],
    'subject': subject,
    'text': text,
    if (html != null) 'html': html,
    if (inReplyTo != null) 'inReplyTo': inReplyTo,
    'references': references,
    'attachments': [for (final a in attachments) a.toJson()],
    'action': action.name,
    if (sourceMessageId != null) 'sourceMessageId': sourceMessageId,
    if (serverDraftId != null) 'serverDraftId': serverDraftId,
  };

  factory OutgoingMessage.fromJson(Map<String, dynamic> json) {
    List<MailAddress> addrs(Object? raw) => ((raw as List?) ?? const [])
        .map((e) => MailAddress.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return OutgoingMessage(
      from: MailAddress.fromJson((json['from'] as Map).cast<String, dynamic>()),
      to: addrs(json['to']),
      cc: addrs(json['cc']),
      bcc: addrs(json['bcc']),
      subject: json['subject'] as String? ?? '',
      text: json['text'] as String? ?? '',
      html: json['html'] as String?,
      inReplyTo: json['inReplyTo'] as String?,
      references: ((json['references'] as List?) ?? const []).cast<String>(),
      attachments: ((json['attachments'] as List?) ?? const [])
          .map(
            (e) =>
                OutgoingAttachment.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      action: _actionFromJson(json['action'] as String?),
      sourceMessageId: json['sourceMessageId'] as String?,
      serverDraftId: json['serverDraftId'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory OutgoingMessage.decode(String raw) =>
      OutgoingMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

OutgoingMessageAction _actionFromJson(String? raw) {
  for (final action in OutgoingMessageAction.values) {
    if (action.name == raw) return action;
  }
  return OutgoingMessageAction.newMessage;
}

/// 待发送附件：字节落本地文件，这里只持有元信息 + 本地路径，避免队列载荷膨胀。
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.filename,
    required this.mimeType,
    required this.localPath,
    required this.size,
  });

  final String filename;
  final String mimeType;

  /// 字节所在的本地文件绝对路径（发送时读取）。
  final String localPath;
  final int size;

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'mimeType': mimeType,
    'localPath': localPath,
    'size': size,
  };

  factory OutgoingAttachment.fromJson(Map<String, dynamic> json) =>
      OutgoingAttachment(
        filename: json['filename'] as String? ?? 'attachment',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        localPath: json['localPath'] as String? ?? '',
        size: json['size'] as int? ?? 0,
      );
}
