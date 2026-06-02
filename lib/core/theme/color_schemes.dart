import 'package:flutter/material.dart';

/// 品牌主色种子。当设备无 Material You 动态取色（Android < 12 或未开启）时，
/// 用它生成回退配色。表现力风格：鲜明的靛紫。
const Color kBrandSeed = Color(0xFF5B4FE9);

/// 由品牌种子生成指定亮度的 [ColorScheme]。
ColorScheme brandScheme(Brightness brightness) =>
    ColorScheme.fromSeed(seedColor: kBrandSeed, brightness: brightness);
