import 'dart:convert';

/// 邮件附件模型。
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

  /// 附件部件 ID（用于下载）。
  final String partId;

  /// MIME 类型。
  final String mimeType;

  /// 文件名。
  final String? filename;

  /// 文件大小（字节）。
  final int? size;

  /// 是否为内联附件（如图片）。
  final bool isInline;

  /// 内容 ID（用于 HTML 中引用）。
  final String? contentId;

  /// 本地缓存路径。
  final String? localPath;

  /// 从 JSON 解析。
  factory MailAttachment.fromJson(Map<String, dynamic> json) {
    return MailAttachment(
      partId: json['partId'] as String,
      mimeType: json['mimeType'] as String,
      filename: json['filename'] as String?,
      size: json['size'] as int?,
      isInline: json['isInline'] as bool? ?? false,
      contentId: json['contentId'] as String?,
      localPath: json['localPath'] as String?,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() {
    return {
      'partId': partId,
      'mimeType': mimeType,
      'filename': filename,
      'size': size,
      'isInline': isInline,
      'contentId': contentId,
      'localPath': localPath,
    };
  }

  /// 获取文件扩展名。
  String get extension {
    if (filename != null && filename!.contains('.')) {
      return filename!.split('.').last.toLowerCase();
    }
    // 根据 MIME 类型推断
    return _extensionFromMimeType(mimeType);
  }

  /// 获取图标。
  String get icon {
    if (mimeType.startsWith('image/')) return '🖼️';
    if (mimeType.startsWith('video/')) return '🎬';
    if (mimeType.startsWith('audio/')) return '🎵';
    if (mimeType.contains('pdf')) return '📄';
    if (mimeType.contains('word') || mimeType.contains('document')) return '📝';
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return '📊';
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) return '📽️';
    if (mimeType.contains('zip') || mimeType.contains('compressed')) return '🗜️';
    return '📎';
  }

  /// 格式化文件大小。
  String get formattedSize {
    if (size == null) return '未知大小';

    final bytes = size!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _extensionFromMimeType(String mimeType) {
    final map = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'application/pdf': 'pdf',
      'application/msword': 'doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
      'application/vnd.ms-excel': 'xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
      'application/zip': 'zip',
      'text/plain': 'txt',
      'text/html': 'html',
    };
    return map[mimeType] ?? 'bin';
  }
}

/// 附件工具类。
class AttachmentUtils {
  /// 从 JSON 字符串解析附件列表。
  static List<MailAttachment> parseAttachments(String? json) {
    if (json == null || json.isEmpty || json == '[]') {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((item) => MailAttachment.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 将附件列表转换为 JSON 字符串。
  static String encodeAttachments(List<MailAttachment> attachments) {
    return jsonEncode(attachments.map((a) => a.toJson()).toList());
  }
}
