import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 账户头像图片选择器。
class AvatarImagePicker {
  const AvatarImagePicker._();

  static Future<String?> pickAccountAvatarImage(String accountId) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'account_avatars'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final safeAccountId = accountId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await for (final entity in directory.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('${safeAccountId}_')) {
        await entity.delete();
      }
    }

    final extension = _avatarExtension(image.path);
    final target = File(
      p.join(
        directory.path,
        '${safeAccountId}_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
    );
    await File(image.path).copy(target.path);
    return target.path;
  }

  /// 删除某账户的全部头像图片文件（账户移除时调用）。
  ///
  /// 头像按 `<safeAccountId>_<时间戳>.<ext>` 命名存放于 `account_avatars/`，
  /// 这里按前缀清理，逻辑与 [pickAccountAvatarImage] 里覆盖旧图的一段一致。
  static Future<void> deleteAccountAvatarImages(String accountId) async {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'account_avatars'),
    );
    if (!await directory.exists()) return;

    final safeAccountId = accountId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await for (final entity in directory.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('${safeAccountId}_')) {
        await entity.delete();
      }
    }
  }

  static String _avatarExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    return switch (extension) {
      '.jpg' || '.jpeg' || '.png' || '.webp' || '.gif' => extension,
      _ => '.jpg',
    };
  }
}
