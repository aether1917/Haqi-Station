/// Android 12+ 壁纸动态取色：CorePalette → 框架 ColorScheme。
/// 转换逻辑与 dynamic_color 官方实现（corepalette_to_colorscheme.dart）一致，
/// 不直接用其 DynamicColorBuilder 是因为它产出 material_ui 包的 ColorScheme 类型，
/// 与 flutter/material.dart 的 ColorScheme 不是同一个类型。
// 官方转换本身仍基于 deprecated 的 CorePalette/Scheme API，此处保持一致。
// ignore_for_file: deprecated_member_use
library;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

ColorScheme? dynamicScheme(
  CorePalette? palette, {
  required Brightness brightness,
}) {
  if (palette == null) return null;
  final Scheme scheme = switch (brightness) {
    Brightness.light => Scheme.lightFromCorePalette(palette),
    Brightness.dark => Scheme.darkFromCorePalette(palette),
  };

  // 以种子色生成打底，补齐 Scheme 未覆盖的新角色（如 surfaceContainer*），
  // 再用系统动态调色板覆盖核心角色，保证与系统取色输出一致。
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Color(scheme.primary),
    brightness: brightness,
  );

  return colorScheme.copyWith(
    primary: Color(scheme.primary),
    onPrimary: Color(scheme.onPrimary),
    primaryContainer: Color(scheme.primaryContainer),
    onPrimaryContainer: Color(scheme.onPrimaryContainer),
    secondary: Color(scheme.secondary),
    onSecondary: Color(scheme.onSecondary),
    secondaryContainer: Color(scheme.secondaryContainer),
    onSecondaryContainer: Color(scheme.onSecondaryContainer),
    tertiary: Color(scheme.tertiary),
    onTertiary: Color(scheme.onTertiary),
    tertiaryContainer: Color(scheme.tertiaryContainer),
    onTertiaryContainer: Color(scheme.onTertiaryContainer),
    error: Color(scheme.error),
    onError: Color(scheme.onError),
    errorContainer: Color(scheme.errorContainer),
    onErrorContainer: Color(scheme.onErrorContainer),
    outline: Color(scheme.outline),
    outlineVariant: Color(scheme.outlineVariant),
    surface: Color(scheme.surface),
    onSurface: Color(scheme.onSurface),
    surfaceVariant: Color(scheme.surfaceVariant),
    onSurfaceVariant: Color(scheme.onSurfaceVariant),
    inverseSurface: Color(scheme.inverseSurface),
    onInverseSurface: Color(scheme.inverseOnSurface),
    inversePrimary: Color(scheme.inversePrimary),
    shadow: Color(scheme.shadow),
    surfaceTint: Color(scheme.primary),
    scrim: Color(scheme.scrim),
  );
}
