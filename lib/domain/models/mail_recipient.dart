import 'dart:convert';

/// 邮件收件人模型。
class MailRecipient {
  const MailRecipient({
    required this.email,
    this.name,
  });

  final String email;
  final String? name;

  /// 显示名称（优先使用 name，如果为空则使用 email）。
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) {
      return name!;
    }
    return email;
  }

  /// 从 JSON 解析。
  factory MailRecipient.fromJson(Map<String, dynamic> json) {
    return MailRecipient(
      email: json['email'] as String,
      name: json['name'] as String?,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
    };
  }
}

/// 收件人工具类。
class RecipientUtils {
  /// 从 JSON 字符串解析收件人列表。
  static List<MailRecipient> parseRecipients(String? json) {
    if (json == null || json.isEmpty || json == '[]') {
      return [];
    }

    try {
      // 尝试解析为 JSON 数组
      final List<dynamic> list = jsonDecode(json);
      return list.map((item) {
        if (item is Map<String, dynamic>) {
          return MailRecipient.fromJson(item);
        } else if (item is String) {
          // 兼容简单的字符串格式
          return MailRecipient(email: item);
        }
        return MailRecipient(email: '');
      }).where((r) => r.email.isNotEmpty).toList();
    } catch (e) {
      // 解析失败，尝试简单分割
      try {
        final parts = json.split(',');
        return parts
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .map((p) => MailRecipient(email: p))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// 将收件人列表转换为 JSON 字符串。
  static String encodeRecipients(List<MailRecipient> recipients) {
    return jsonEncode(recipients.map((r) => r.toJson()).toList());
  }

  /// 格式化收件人列表为显示字符串。
  static String formatRecipients(List<MailRecipient> recipients, {int maxCount = 3}) {
    if (recipients.isEmpty) return '';

    if (recipients.length <= maxCount) {
      return recipients.map((r) => r.displayName).join(', ');
    }

    final shown = recipients.take(maxCount).map((r) => r.displayName).join(', ');
    final remaining = recipients.length - maxCount;
    return '$shown 和其他 $remaining 人';
  }
}
