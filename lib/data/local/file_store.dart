import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 附件与原始 MIME 的文件系统存储。
///
/// 数据库只存元数据（路径、下载状态），实际字节落在
/// `<appSupport>/mail_files/<accountId>/<messageId>/<partId>`。
class FileStore {
  FileStore._(this._root);

  final Directory _root;

  static FileStore? _instance;

  /// 初始化（应用启动时调用一次）。
  static Future<FileStore> init() async {
    if (_instance != null) return _instance!;
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, 'mail_files'));
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
    return _instance = FileStore._(root);
  }

  Directory _messageDir(String accountId, String messageId) {
    return Directory(p.join(_root.path, accountId, messageId));
  }

  /// 写入某邮件某部件的字节，返回文件绝对路径。
  Future<String> writePart(
    String accountId,
    String messageId,
    String partId,
    List<int> bytes,
  ) async {
    final dir = _messageDir(accountId, messageId);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, _sanitize(partId)));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<File?> readPart(
    String accountId,
    String messageId,
    String partId,
  ) async {
    final file =
        File(p.join(_messageDir(accountId, messageId).path, _sanitize(partId)));
    return file.existsSync() ? file : null;
  }

  /// 删除某邮件的所有本地文件。
  Future<void> deleteMessageFiles(String accountId, String messageId) async {
    final dir = _messageDir(accountId, messageId);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// 删除某账户的所有本地文件（账户移除时）。
  Future<void> deleteAccountFiles(String accountId) async {
    final dir = Directory(p.join(_root.path, accountId));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// part id 可能含路径分隔符等非法字符，做一次清洗。
  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
