import 'package:flutter/material.dart';

/// 语义化扩展色板：基础 [ColorScheme] 没有覆盖的领域语义色，
/// 例如「未读强调色」、成功/警告色。通过 [ThemeExtension] 注入。
@immutable
class ExpressiveColors extends ThemeExtension<ExpressiveColors> {
  const ExpressiveColors({
    required this.unread,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  /// 未读邮件的强调色（圆点、加粗标题等）。
  final Color unread;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  /// 由当前 [ColorScheme] 派生一组协调的语义色。
  factory ExpressiveColors.fromScheme(ColorScheme scheme) {
    final bool dark = scheme.brightness == Brightness.dark;
    return ExpressiveColors(
      unread: scheme.primary,
      success: dark ? const Color(0xFF7ADBA0) : const Color(0xFF1B6B3A),
      onSuccess: dark ? const Color(0xFF003919) : const Color(0xFFFFFFFF),
      warning: dark ? const Color(0xFFFFB86B) : const Color(0xFF8A5000),
      onWarning: dark ? const Color(0xFF4A2800) : const Color(0xFFFFFFFF),
    );
  }

  /// 主题扩展缺失时的安全回退。
  const ExpressiveColors.fallback()
      : unread = const Color(0xFF5B4FE9),
        success = const Color(0xFF1B6B3A),
        onSuccess = const Color(0xFFFFFFFF),
        warning = const Color(0xFF8A5000),
        onWarning = const Color(0xFFFFFFFF);

  @override
  ExpressiveColors copyWith({
    Color? unread,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
  }) {
    return ExpressiveColors(
      unread: unread ?? this.unread,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  ExpressiveColors lerp(ExpressiveColors? other, double t) {
    if (other is! ExpressiveColors) return this;
    return ExpressiveColors(
      unread: Color.lerp(unread, other.unread, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}
