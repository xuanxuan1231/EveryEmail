import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/color_schemes.dart';
import '../data/settings/display_settings.dart';
import 'providers.dart';
import 'router.dart';

/// 应用根组件。
///
/// 通过 [DynamicColorBuilder] 接入 Material You 壁纸取色（Android 12+）：
/// 有动态配色则做 harmonize（品牌色向壁纸色偏移），否则回退到品牌种子配色。
class EveryMailApp extends ConsumerWidget {
  const EveryMailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 字体偏好：变化时整套主题重建，全应用字体即时切换。
    final appFont = ref.watch(appFontProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme =
            lightDynamic?.harmonized() ?? brandScheme(Brightness.light);
        final ColorScheme darkScheme =
            darkDynamic?.harmonized() ?? brandScheme(Brightness.dark);

        return MaterialApp.router(
          title: 'EveryEmail',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightScheme, appFont),
          darkTheme: AppTheme.dark(darkScheme, appFont),
          themeMode: _themeMode(displaySettings.colorMode),
          routerConfig: appRouter,
        );
      },
    );
  }

  ThemeMode _themeMode(AppColorMode colorMode) {
    return switch (colorMode) {
      AppColorMode.system => ThemeMode.system,
      AppColorMode.light => ThemeMode.light,
      AppColorMode.dark => ThemeMode.dark,
    };
  }
}
