import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqi_station/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService 色彩模式', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('默认为内置配色与活力粉种子色', () async {
      final settings = SettingsService.instance;
      await settings.load();
      expect(settings.colorMode, AppColorMode.appDefault);
      expect(settings.seedColor, kDefaultSeedColor);
    });

    test('自定义模式：设置种子色并持久化，重载后还原', () async {
      final settings = SettingsService.instance;
      await settings.load();

      await settings.setColorMode(AppColorMode.custom);
      await settings.setSeedColor(const Color(0xFF3B82F6));
      expect(settings.colorMode, AppColorMode.custom);
      expect(settings.seedColor, 0xFF3B82F6);

      final reloaded = SettingsService.instance;
      await reloaded.load();
      expect(reloaded.colorMode, AppColorMode.custom);
      expect(reloaded.seedColor, 0xFF3B82F6);
    });

    test('动态模式持久化', () async {
      final settings = SettingsService.instance;
      await settings.load();

      await settings.setColorMode(AppColorMode.dynamic);
      final reloaded = SettingsService.instance;
      await reloaded.load();
      expect(reloaded.colorMode, AppColorMode.dynamic);
    });

    test('无效的持久化值回退到默认配色', () async {
      SharedPreferences.setMockInitialValues({'haqi.colorMode': 'bogus'});
      final settings = SettingsService.instance;
      await settings.load();
      expect(settings.colorMode, AppColorMode.appDefault);
    });
  });
}
