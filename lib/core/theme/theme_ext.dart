import 'package:flutter/material.dart';

import 'expressive_colors.dart';
import 'motion_tokens.dart';
import 'shape_scale.dart';

/// 主题取值便捷扩展：`context.colors` / `context.motion` / `context.shapes` 等。
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;

  MotionTokens get motion =>
      Theme.of(this).extension<MotionTokens>() ?? const MotionTokens();

  ShapeScale get shapes =>
      Theme.of(this).extension<ShapeScale>() ?? const ShapeScale();

  ExpressiveColors get expressive =>
      Theme.of(this).extension<ExpressiveColors>() ??
      const ExpressiveColors.fallback();
}
