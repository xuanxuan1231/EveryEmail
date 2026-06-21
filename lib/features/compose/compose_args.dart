import '../../domain/models/mail_address.dart';
import '../../domain/models/outgoing_message.dart';

/// 撰写模式：新邮件 / 回复 / 全部回复 / 转发 / 编辑草稿。
enum ComposeMode { newMail, reply, replyAll, forward, draft }

/// 撰写页入口参数（经 go_router 的 `extra` 传入）。
///
/// 回复/转发由详情页据原邮件构建（预填收件人、主题、引用正文与线程头）；新邮件
/// 与草稿编辑也复用此结构。所有字段均为预填初值，用户可在页面内继续编辑。
class ComposeArgs {
  const ComposeArgs({
    this.mode = ComposeMode.newMail,
    this.accountId,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.subject = '',
    this.bodyText = '',
    this.inReplyTo,
    this.references = const [],
    this.sourceMessageId,
    this.serverDraftId,
    this.draftMessageId,
    this.attachments = const [],
  });

  final ComposeMode mode;

  /// 预选发件账户 id（回复/转发取原邮件所属账户；为空则页面默认取第一个账户）。
  final String? accountId;

  final List<MailAddress> to;
  final List<MailAddress> cc;
  final List<MailAddress> bcc;

  final String subject;

  /// 预填正文（回复/转发时为引用原文）。
  final String bodyText;

  /// 被回复邮件的 Message-ID（In-Reply-To 头）。
  final String? inReplyTo;

  /// References 链（线程归并用）。
  final List<String> references;

  /// 被回复/转发的后端原始 message id（Graph 专用；其它后端可忽略）。
  final String? sourceMessageId;

  /// 服务端草稿 id。Gmail 是 draft id；Graph 是 draft message id。
  final String? serverDraftId;

  /// 编辑/发送的本地草稿邮件 id（发送成功后删除该草稿）。
  final String? draftMessageId;

  /// 预置附件（转发时为原邮件附件，草稿恢复时为草稿附件）。
  final List<OutgoingAttachment> attachments;

  bool get hasCcOrBcc => cc.isNotEmpty || bcc.isNotEmpty;
}

/// 收件人文本解析工具：把 `Name <a@x.com>, b@y.com；c@z.com` 解析为地址列表。
class RecipientParsing {
  RecipientParsing._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// 按逗号/分号/换行切分为若干地址；引号内的分隔符不切分（保留含逗号的显示名）。
  /// 无法识别 email 的片段仍保留（交由校验提示）。
  static List<MailAddress> parse(String raw) {
    final result = <MailAddress>[];
    final buf = StringBuffer();
    var inQuotes = false;

    void flush() {
      final token = buf.toString().trim();
      buf.clear();
      if (token.isNotEmpty) result.add(_parseOne(token));
    }

    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '"') {
        inQuotes = !inQuotes;
        buf.write(c);
      } else if (!inQuotes && (c == ',' || c == ';' || c == '\n')) {
        flush();
      } else {
        buf.write(c);
      }
    }
    flush();
    return result;
  }

  static MailAddress _parseOne(String s) {
    final lt = s.lastIndexOf('<');
    final gt = s.lastIndexOf('>');
    if (lt != -1 && gt > lt) {
      final email = s.substring(lt + 1, gt).trim();
      var name = s.substring(0, lt).trim();
      if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
        name = name.substring(1, name.length - 1);
      }
      return MailAddress(email: email, name: name.isEmpty ? null : name);
    }
    return MailAddress(email: s);
  }

  /// 格式化为输入框可显示的文本（有名字用 `Name <email>`，否则仅 email）。
  static String format(List<MailAddress> addresses) {
    return addresses
        .map(
          (a) => a.name == null || a.name!.isEmpty
              ? a.email
              : '${a.name} <${a.email}>',
        )
        .join(', ');
  }

  static bool isValidEmail(String email) => _email.hasMatch(email.trim());
}
