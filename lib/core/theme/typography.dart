import 'package:flutter/material.dart';

/// 表现力字阶：在基础 M3 字体之上加重显示/标题字重、收紧字距，
/// 让标题更有「表现力」。使用 Google Sans 系列（Android 12+ 系统内置）。
TextTheme buildExpressiveTextTheme(TextTheme base) {
  // Google Sans 系列：Display 用 Google Sans Display，正文用 Google Sans Text
  // Android 12+ 内置，回退到 Roboto
  const displayFont = TextStyle(fontFamily: 'Google Sans Display');
  const textFont = TextStyle(fontFamily: 'Google Sans Text');

  return base.copyWith(
    displayLarge: base.displayLarge
        ?.merge(displayFont)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    displayMedium: base.displayMedium
        ?.merge(displayFont)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.25),
    displaySmall:
        base.displaySmall?.merge(displayFont).copyWith(fontWeight: FontWeight.w700),
    headlineLarge:
        base.headlineLarge?.merge(textFont).copyWith(fontWeight: FontWeight.w700),
    headlineMedium:
        base.headlineMedium?.merge(textFont).copyWith(fontWeight: FontWeight.w600),
    headlineSmall:
        base.headlineSmall?.merge(textFont).copyWith(fontWeight: FontWeight.w600),
    titleLarge: base.titleLarge?.merge(textFont).copyWith(fontWeight: FontWeight.w600),
    // 正文保持 base（Roboto）
  );
}
