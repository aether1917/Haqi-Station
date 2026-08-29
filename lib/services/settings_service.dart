/// 应用设置（主题模式与色彩模式），持久化到 SharedPreferences。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 色彩模式：内置默认粉 / 跟随系统动态取色 / 自定义种子色。
enum AppColorMode {
  appDefault('default'),
  dynamic('dynamic'),
  custom('custom');

  const AppColorMode(this.id);
  final String id;

  static AppColorMode fromId(String? id) => switch (id) {
        'dynamic' => AppColorMode.dynamic,
        'custom' => AppColorMode.custom,
        _ => AppColorMode.appDefault,
      };
}

/// 自定义模式的默认种子色 = 内置活力粉。
const int kDefaultSeedColor = 0xFFEC4899;

class SettingsService extends ChangeNotifier {
  static const _themeKey = 'haqi.themeMode';
  static const _colorModeKey = 'haqi.colorMode';
  static const _seedColorKey = 'haqi.seedColor';

  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();

  SettingsService._() {
    _instance = this;
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  AppColorMode _colorMode = AppColorMode.appDefault;
  AppColorMode get colorMode => _colorMode;

  int _seedColor = kDefaultSeedColor;
  int get seedColor => _seedColor;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _colorMode = AppColorMode.fromId(prefs.getString(_colorModeKey));
    _seedColor = prefs.getInt(_seedColorKey) ?? kDefaultSeedColor;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> setColorMode(AppColorMode mode) async {
    if (mode == _colorMode) return;
    _colorMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorModeKey, mode.id);
  }

  Future<void> setSeedColor(Color color) async {
    final value = color.toARGB32();
    if (value == _seedColor) return;
    _seedColor = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, value);
  }
}
