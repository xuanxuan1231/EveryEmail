import 'dart:math';

/// 生成一个紧凑的随机字符串 ID（用于账户/文件夹/邮件本地主键）。
///
/// 非加密用途，仅需在本地库内唯一。格式：时间戳 base36 + 随机后缀。
String generateId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = Random();
  final suffix =
      List.generate(6, (_) => _alphabet[rand.nextInt(_alphabet.length)]).join();
  return '$now$suffix';
}

const String _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
