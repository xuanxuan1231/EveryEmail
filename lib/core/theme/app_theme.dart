import 'package:flutter/material.dart';

import 'expressive_colors.dart';
import 'motion_tokens.dart';
import 'shape_scale.dart';
import 'typography.dart';

/// 应用主题工厂。
///
/// 在基础 Material 3 之上叠加「表现力层」：表现力字阶、Spark 涟漪，
/// 以及动效/形状/语义色三组 [ThemeExtension]。配色由外部传入
/// （动态取色或品牌回退），故 light/dark 共用同一构建逻辑。
class AppTheme {
  const AppTheme._();

  static ThemeData light(ColorScheme scheme) => _build(scheme);
  static ThemeData dark(ColorScheme scheme) => _build(scheme);

  static ThemeData _build(ColorScheme scheme) {
    final ThemeData base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: buildExpressiveTextTheme(base.textTheme),
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[
        const MotionTokens(),
        const ShapeScale(),
        ExpressiveColors.fromScheme(scheme),
      ],
    );
  }
}
