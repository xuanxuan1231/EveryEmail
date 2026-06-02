import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/color_schemes.dart';
import 'router.dart';

/// 应用根组件。
///
/// 通过 [DynamicColorBuilder] 接入 Material You 壁纸取色（Android 12+）：
/// 有动态配色则做 harmonize（品牌色向壁纸色偏移），否则回退到品牌种子配色。
class EveryMailApp extends ConsumerWidget {
  const EveryMailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme =
            lightDynamic?.harmonized() ?? brandScheme(Brightness.light);
        final ColorScheme darkScheme =
            darkDynamic?.harmonized() ?? brandScheme(Brightness.dark);

        return MaterialApp.router(
          title: 'EveryEmail',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightScheme),
          darkTheme: AppTheme.dark(darkScheme),
          routerConfig: appRouter,
        );
      },
    );
  }
}
