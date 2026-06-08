import 'package:flutter/material.dart';

Color mailListSurfaceColor(ThemeData theme) {
  final colors = theme.colorScheme;
  final dark = colors.brightness == Brightness.dark;
  final base = dark ? colors.surfaceContainerHigh : colors.surfaceContainerLow;

  return Color.alphaBlend(
    colors.primary.withValues(alpha: dark ? 0.04 : 0.018),
    base,
  );
}

Color mailListMessageItemTintColor(
  ThemeData theme, {
  required bool isRead,
  bool isSelected = false,
}) {
  final colors = theme.colorScheme;
  final dark = colors.brightness == Brightness.dark;

  if (isSelected) {
    return colors.primaryContainer.withValues(alpha: dark ? 0.24 : 0.28);
  }

  if (!isRead) {
    return colors.secondaryContainer.withValues(alpha: dark ? 0.12 : 0.18);
  }

  return Colors.transparent;
}

Color mailListAppBarSurfaceColor(ThemeData theme) {
  final colors = theme.colorScheme;
  final dark = colors.brightness == Brightness.dark;
  final base = dark ? colors.surfaceContainerLow : colors.surfaceContainerHigh;

  return Color.alphaBlend(
    colors.primary.withValues(alpha: dark ? 0.025 : 0.012),
    base,
  );
}

Color mailListAppBarDividerColor(ThemeData theme) {
  final colors = theme.colorScheme;
  final dark = colors.brightness == Brightness.dark;

  return colors.outlineVariant.withValues(alpha: dark ? 0.48 : 0.62);
}
