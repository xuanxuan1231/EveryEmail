import 'package:flutter/material.dart';

/// Material 3 Expressive 动效令牌。
///
/// Flutter 无官方 M3 Expressive 支持，这里把「表现力」动效收敛为一组令牌，
/// 通过 [ThemeExtension] 注入主题，供页面转场、列表入场、选中态形变等复用。
@immutable
class MotionTokens extends ThemeExtension<MotionTokens> {
  const MotionTokens({
    this.short = const Duration(milliseconds: 200),
    this.medium = const Duration(milliseconds: 350),
    this.long = const Duration(milliseconds: 500),
    this.emphasized = Curves.easeInOutCubicEmphasized,
    this.emphasizedDecelerate = const Cubic(0.05, 0.7, 0.1, 1.0),
    this.emphasizedAccelerate = const Cubic(0.3, 0.0, 0.8, 0.15),
    this.standard = const Cubic(0.2, 0.0, 0.0, 1.0),
  });

  /// 小幅状态切换（涟漪、勾选）。
  final Duration short;

  /// 常规转场（页面、容器形变）。
  final Duration medium;

  /// 大幅/全屏转场。
  final Duration long;

  /// M3 强调缓动（进出都强调）。
  final Curve emphasized;

  /// 元素进入屏幕（强调减速）。
  final Curve emphasizedDecelerate;

  /// 元素离开屏幕（强调加速）。
  final Curve emphasizedAccelerate;

  /// 标准缓动。
  final Curve standard;

  /// 空间弹簧：用于位置/尺寸形变（FAB 展开、选中态），略带回弹。
  SpringDescription get spatialSpring =>
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);

  /// 效果弹簧：用于颜色/透明度等，临界阻尼无回弹。
  SpringDescription get effectsSpring =>
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1600, ratio: 1.0);

  @override
  MotionTokens copyWith({
    Duration? short,
    Duration? medium,
    Duration? long,
    Curve? emphasized,
    Curve? emphasizedDecelerate,
    Curve? emphasizedAccelerate,
    Curve? standard,
  }) {
    return MotionTokens(
      short: short ?? this.short,
      medium: medium ?? this.medium,
      long: long ?? this.long,
      emphasized: emphasized ?? this.emphasized,
      emphasizedDecelerate: emphasizedDecelerate ?? this.emphasizedDecelerate,
      emphasizedAccelerate: emphasizedAccelerate ?? this.emphasizedAccelerate,
      standard: standard ?? this.standard,
    );
  }

  @override
  MotionTokens lerp(MotionTokens? other, double t) {
    // 动效令牌为离散设计值，主题切换时直接吸附到目标，不做曲线插值。
    if (other is! MotionTokens) return this;
    return t < 0.5 ? this : other;
  }
}
