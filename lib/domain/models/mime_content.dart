/// 归一化的邮件正文内容（含正文与附件元数据）。
///
/// IMAP 由 enough_mail 的 MimeMessage 解析而来；Graph 由 message + attachments
/// 端点拼装而来。两者映射到同一结构，UI 不感知来源。
class MimeContent {
  const MimeContent({
    this.plainText,
    this.htmlBody,
    this.attachments = const [],
  });

  final String? plainText;
  final String? htmlBody;
  final List<MailAttachment> attachments;

  /// 是否有可渲染正文。
  bool get hasBody =>
      (plainText != null && plainText!.isNotEmpty) ||
      (htmlBody != null && htmlBody!.isNotEmpty);
}

/// 附件 / 内联部件元数据。字节本身落文件系统（FileStore），这里只持有元信息 + 本地路径。
class MailAttachment {
  const MailAttachment({
    required this.partId,
    required this.mimeType,
    this.filename,
    this.size,
    this.isInline = false,
    this.contentId,
    this.localPath,
  });

  /// 后端定位部件用的标识：IMAP 的 fetchId，或 Graph 的 attachment id。
  final String partId;
  final String mimeType;
  final String? filename;
  final int? size;

  /// 是否为内联（如 HTML 正文里 cid: 引用的图片）。
  final bool isInline;

  /// Content-ID（去掉尖括号），用于把 cid: 链接映射到本地文件。
  final String? contentId;

  /// 已下载时的本地文件绝对路径。
  final String? localPath;

  bool get isDownloaded => localPath != null;

  Map<String, dynamic> toJson() => {
        'partId': partId,
        'mimeType': mimeType,
        if (filename != null) 'filename': filename,
        if (size != null) 'size': size,
        'isInline': isInline,
        if (contentId != null) 'contentId': contentId,
        if (localPath != null) 'localPath': localPath,
      };

  factory MailAttachment.fromJson(Map<String, dynamic> json) => MailAttachment(
        partId: json['partId'] as String,
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        filename: json['filename'] as String?,
        size: json['size'] as int?,
        isInline: json['isInline'] as bool? ?? false,
        contentId: json['contentId'] as String?,
        localPath: json['localPath'] as String?,
      );

  MailAttachment copyWith({String? localPath}) => MailAttachment(
        partId: partId,
        mimeType: mimeType,
        filename: filename,
        size: size,
        isInline: isInline,
        contentId: contentId,
        localPath: localPath ?? this.localPath,
      );
}
