import 'package:flutter/material.dart';

/// Material 3 Expressive 形状刻度。
///
/// 表现力风格偏好更大的圆角与更鲜明的形状对比。通过 [ThemeExtension] 注入，
/// 供卡片、容器、选中态等统一取用。
@immutable
class ShapeScale extends ThemeExtension<ShapeScale> {
  const ShapeScale({
    this.extraSmall = const BorderRadius.all(Radius.circular(8)),
    this.small = const BorderRadius.all(Radius.circular(12)),
    this.medium = const BorderRadius.all(Radius.circular(16)),
    this.large = const BorderRadius.all(Radius.circular(24)),
    this.extraLarge = const BorderRadius.all(Radius.circular(32)),
  });

  final BorderRadius extraSmall;
  final BorderRadius small;
  final BorderRadius medium;
  final BorderRadius large;
  final BorderRadius extraLarge;

  /// 由圆角快速构造矩形圆角边框。
  RoundedRectangleBorder rounded(BorderRadius radius) =>
      RoundedRectangleBorder(borderRadius: radius);

  @override
  ShapeScale copyWith({
    BorderRadius? extraSmall,
    BorderRadius? small,
    BorderRadius? medium,
    BorderRadius? large,
    BorderRadius? extraLarge,
  }) {
    return ShapeScale(
      extraSmall: extraSmall ?? this.extraSmall,
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      extraLarge: extraLarge ?? this.extraLarge,
    );
  }

  @override
  ShapeScale lerp(ShapeScale? other, double t) {
    if (other is! ShapeScale) return this;
    return ShapeScale(
      extraSmall: BorderRadius.lerp(extraSmall, other.extraSmall, t)!,
      small: BorderRadius.lerp(small, other.small, t)!,
      medium: BorderRadius.lerp(medium, other.medium, t)!,
      large: BorderRadius.lerp(large, other.large, t)!,
      extraLarge: BorderRadius.lerp(extraLarge, other.extraLarge, t)!,
    );
  }
}
