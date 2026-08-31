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
  static const _previewProgramKey = 'haqi.previewProgram';
  static const _categoryBarRowsKey = 'haqi.categoryBarRows';

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

  bool _previewProgram = false;
  bool get previewProgram => _previewProgram;

  /// 分类栏布局：1 = 单排（横向滚动，支持拖拽排序），2 = 双排（换行展示）。
  int _categoryBarRows = 1;
  int get categoryBarRows => _categoryBarRows;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _colorMode = AppColorMode.fromId(prefs.getString(_colorModeKey));
    _seedColor = prefs.getInt(_seedColorKey) ?? kDefaultSeedColor;
    _previewProgram = prefs.getBool(_previewProgramKey) ?? false;
    _categoryBarRows = prefs.getInt(_categoryBarRowsKey) == 2 ? 2 : 1;
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

  /// 加入/退出预览体验计划：加入后检查更新会包含 beta / alpha 预览版。
  Future<void> setPreviewProgram(bool joined) async {
    if (joined == _previewProgram) return;
    _previewProgram = joined;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_previewProgramKey, joined);
  }

  /// 设置分类栏布局：单排（1）或双排（2）。
  Future<void> setCategoryBarRows(int rows) async {
    final value = rows == 2 ? 2 : 1;
    if (value == _categoryBarRows) return;
    _categoryBarRows = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_categoryBarRowsKey, value);
  }
}
