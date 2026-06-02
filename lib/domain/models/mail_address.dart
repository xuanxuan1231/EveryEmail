/// 邮件地址（姓名 + 邮箱）。
class MailAddress {
  const MailAddress({required this.email, this.name});

  final String email;
  final String? name;

  /// 用于显示的名称：有 name 用 name，否则用 email。
  String get displayName => (name != null && name!.isNotEmpty) ? name! : email;

  Map<String, dynamic> toJson() => {'email': email, if (name != null) 'name': name};

  factory MailAddress.fromJson(Map<String, dynamic> json) => MailAddress(
        email: json['email'] as String? ?? '',
        name: json['name'] as String?,
      );

  @override
  String toString() => name == null ? email : '$name <$email>';

  @override
  bool operator ==(Object other) =>
      other is MailAddress && other.email == email && other.name == name;

  @override
  int get hashCode => Object.hash(email, name);
}
