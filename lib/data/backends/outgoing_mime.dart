import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart' as em;

import '../../domain/models/mail_address.dart' as domain;
import '../../domain/models/outgoing_message.dart';

/// 把后端无关的 [OutgoingMessage] 渲染为 enough_mail 的 [em.MimeMessage]。
///
/// IMAP/SMTP 直接发送该 MimeMessage；Gmail 用 `renderMessage()` 取 RFC822 文本再
/// base64url 编码为 `messages.send` 的 `raw`。两者共用此构建，确保正文/附件/线程头一致。
///
/// 正文结构：
/// - 有附件 + HTML：multipart/mixed [ multipart/alternative(text, html), 附件… ]
/// - 有附件 + 仅纯文本：multipart/mixed [ text/plain, 附件… ]
/// - 无附件 + HTML：multipart/alternative(text, html)
/// - 无附件 + 仅纯文本：text/plain
Future<em.MimeMessage> buildOutgoingMime(OutgoingMessage msg) async {
  final builder = em.MessageBuilder()
    ..from = [_addr(msg.from)]
    ..to = [for (final a in msg.to) _addr(a)]
    ..cc = [for (final a in msg.cc) _addr(a)]
    ..bcc = [for (final a in msg.bcc) _addr(a)]
    ..subject = msg.subject;

  final hasHtml = msg.html != null && msg.html!.trim().isNotEmpty;
  final hasAttachments = msg.attachments.isNotEmpty;

  if (hasAttachments) {
    builder.setContentType(em.MediaSubtype.multipartMixed.mediaType);
    if (hasHtml) {
      final alt = builder.addPart(
        mediaSubtype: em.MediaSubtype.multipartAlternative,
      )..addText(msg.text);
      alt.addText(msg.html!, mediaType: em.MediaSubtype.textHtml.mediaType);
    } else {
      builder.addText(msg.text);
    }
    for (final att in msg.attachments) {
      final bytes = await _readBytes(att.localPath);
      builder.addBinary(
        bytes,
        em.MediaType.fromText(att.mimeType),
        filename: att.filename,
      );
    }
  } else if (hasHtml) {
    builder.setContentType(em.MediaSubtype.multipartAlternative.mediaType);
    builder
      ..addText(msg.text)
      ..addText(msg.html!, mediaType: em.MediaSubtype.textHtml.mediaType);
  } else {
    builder.text = msg.text;
  }

  // 线程头：回复时让各后端把邮件归并回原会话（Gmail/Graph 也据 References 归并）。
  final inReplyTo = msg.inReplyTo;
  if (inReplyTo != null && inReplyTo.isNotEmpty) {
    builder.setHeader('In-Reply-To', inReplyTo);
  }
  if (msg.references.isNotEmpty) {
    builder.setHeader('References', msg.references.join(' '));
  }

  return builder.buildMimeMessage();
}

Future<Uint8List> _readBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw Exception('附件文件不存在: $path');
  }
  return file.readAsBytes();
}

em.MailAddress _addr(domain.MailAddress a) =>
    em.MailAddress(a.name, a.email);
