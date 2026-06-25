import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/id_generator.dart' as id_gen;
import '../../domain/models/outgoing_message.dart';

/// 待发送附件的本地暂存：把用户选中的文件复制到应用私有目录，得到稳定路径，
/// 供发送队列持久化与重试（选择器返回的临时路径可能被系统清理）。
class OutgoingAttachmentStore {
  OutgoingAttachmentStore._();

  /// 把 [sourcePath] 的文件复制进 `<app docs>/outgoing/`，返回 [OutgoingAttachment]。
  static Future<OutgoingAttachment> stageFile(
    String sourcePath, {
    required String filename,
  }) async {
    final dir = await _outgoingDir();
    final dest = File(p.join(dir.path, '${id_gen.generateId()}-$filename'));
    // 用 File.copy 做 OS 级流式复制，避免把（最大可达上百 MB 的）整个附件读入内存。
    await File(sourcePath).copy(dest.path);
    return OutgoingAttachment(
      filename: filename,
      mimeType: guessMimeType(filename),
      localPath: dest.path,
      size: await dest.length(),
    );
  }

  static Future<Directory> _outgoingDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'outgoing'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 由文件扩展名粗略推断 MIME 类型，未知则 application/octet-stream。
  static String guessMimeType(String filename) {
    final ext = p.extension(filename).toLowerCase().replaceFirst('.', '');
    return _mimeByExt[ext] ?? 'application/octet-stream';
  }

  static const Map<String, String> _mimeByExt = {
    'pdf': 'application/pdf',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'heic': 'image/heic',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'html': 'text/html',
    'htm': 'text/html',
    'md': 'text/markdown',
    'json': 'application/json',
    'xml': 'application/xml',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
    'gz': 'application/gzip',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };
}
