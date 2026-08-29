/// 哈气站 MD3 主题：白色为默认底色，活力粉为主色（来自设计系统检索结果）。
library;

import 'package:flutter/material.dart';

const Color _primary = Color(0xFFEC4899); // 活力粉
const Color _secondary = Color(0xFFF59E0B); // 喜剧黄
const Color _tertiary = Color(0xFF2563EB); // 分享蓝
const Color _ink = Color(0xFF0F172A); // 前景深灰
const Color _mutedPink = Color(0xFFFDF4F8); // 粉调弱化面
const Color _borderPink = Color(0xFFFCE9F2); // 粉调描边
const Color _error = Color(0xFFDC2626);

const Color _darkPrimary = Color(0xFFF9A8D4);
const Color _darkSurface = Color(0xFF141118);
const Color _darkContainer = Color(0xFF231D22);
const Color _darkOnSurface = Color(0xFFEAE3E9);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.light(
    primary: _primary,
    onPrimary: Colors.black,
    secondary: _secondary,
    onSecondary: _ink,
    tertiary: _tertiary,
    onTertiary: Colors.white,
    error: _error,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: _ink,
    onSurfaceVariant: const Color(0xFF475569),
    outline: const Color(0xFFCBD5E1),
    outlineVariant: _borderPink,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: _mutedPink,
    surfaceContainer: _mutedPink,
    surfaceContainerHigh: _borderPink,
    surfaceContainerHighest: _borderPink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _mutedPink,
      indicatorColor: _borderPink,
      height: 68,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.dark(
    primary: _darkPrimary,
    onPrimary: const Color(0xFF33101F),
    secondary: const Color(0xFFFBBF24),
    onSecondary: const Color(0xFF2B1A00),
    tertiary: const Color(0xFF93C5FD),
    onTertiary: const Color(0xFF0A1E3F),
    error: const Color(0xFFF87171),
    onError: const Color(0xFF2B0505),
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    onSurfaceVariant: const Color(0xFFA8A2AE),
    outline: const Color(0xFF57514E),
    outlineVariant: const Color(0xFF3B3539),
    surfaceContainerLowest: const Color(0xFF0F0D13),
    surfaceContainerLow: _darkContainer,
    surfaceContainer: _darkContainer,
    surfaceContainerHigh: const Color(0xFF2B2429),
    surfaceContainerHighest: const Color(0xFF352E33),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _darkSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkSurface,
      surfaceTintColor: _darkSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _darkContainer,
      indicatorColor: const Color(0xFF3B2A33),
      height: 68,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: const Color(0xFF33101F),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
