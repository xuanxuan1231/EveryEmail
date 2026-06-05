import 'package:flutter/material.dart';

import '../../data/settings/app_font_settings.dart';

/// 表现力字阶：在基础 M3 字体之上加重显示/标题字重、收紧字距，
/// 让标题更有「表现力」。
///
/// [font] 决定字族来源：
/// - [AppFont.system]：标题用 Android 12+ 系统内置的 Google Sans Display/Text，
///   正文保持系统默认（回退 Roboto）—— 与历史行为一致。
/// - [AppFont.googleSansFlex]：整套文本（含正文）改用随应用打包的 Google Sans Flex
///   可变字体，代替系统字体；字重经 wght 轴呈现层次。
TextTheme buildExpressiveTextTheme(TextTheme base, {required AppFont font}) {
  final bool useFlex = font == AppFont.googleSansFlex;

  // 开启 Flex 时整套文本（含正文）切到打包字体；否则维持系统字体不变。
  final TextTheme themed =
      useFlex ? base.apply(fontFamily: 'Google Sans Flex') : base;
  // Display 用 Google Sans Display，标题用 Google Sans Text；Flex 模式下统一用 Google Sans Flex。
  final TextStyle displayFont =
      TextStyle(fontFamily: useFlex ? 'Google Sans Flex' : 'Google Sans Display');
  final TextStyle textFont =
      TextStyle(fontFamily: useFlex ? 'Google Sans Flex' : 'Google Sans Text');

  return themed.copyWith(
    displayLarge: themed.displayLarge
        ?.merge(displayFont)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    displayMedium: themed.displayMedium
        ?.merge(displayFont)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.25),
    displaySmall:
        themed.displaySmall?.merge(displayFont).copyWith(fontWeight: FontWeight.w700),
    headlineLarge:
        themed.headlineLarge?.merge(textFont).copyWith(fontWeight: FontWeight.w700),
    headlineMedium:
        themed.headlineMedium?.merge(textFont).copyWith(fontWeight: FontWeight.w600),
    headlineSmall:
        themed.headlineSmall?.merge(textFont).copyWith(fontWeight: FontWeight.w600),
    titleLarge: themed.titleLarge?.merge(textFont).copyWith(fontWeight: FontWeight.w600),
    // 正文：Flex 模式下已随 themed 切到 Google Sans Flex；系统模式保持 base（Roboto）。
  );
}
