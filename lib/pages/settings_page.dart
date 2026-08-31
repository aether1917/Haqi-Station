import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../widgets/color_picker.dart';

/// 设置：外观（深色模式）与色彩（默认 / 动态取色 / 自定义选色）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _sectionLabel(context, '分类栏'),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => RadioGroup<int>(
                groupValue: settings.categoryBarRows,
                onChanged: (rows) {
                  if (rows != null) settings.setCategoryBarRows(rows);
                },
                child: const Column(
                  children: [
                    RadioListTile<int>(
                      value: 1,
                      title: Text('单排显示'),
                      subtitle: Text('横向滚动，支持长按拖拽排序'),
                      secondary: Icon(Icons.view_stream_outlined),
                    ),
                    RadioListTile<int>(
                      value: 2,
                      title: Text('双排显示'),
                      subtitle: Text('分类全部展示，不适合排序'),
                      secondary: Icon(Icons.view_agenda_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _sectionLabel(context, '外观'),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (mode) {
                  if (mode != null) settings.setThemeMode(mode);
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('跟随系统'),
                      secondary: Icon(Icons.brightness_auto_rounded),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text('浅色模式'),
                      secondary: Icon(Icons.light_mode_outlined),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text('深色模式'),
                      secondary: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _sectionLabel(context, '色彩'),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => RadioGroup<AppColorMode>(
                groupValue: settings.colorMode,
                onChanged: (mode) {
                  if (mode != null) settings.setColorMode(mode);
                },
                child: Column(
                  children: [
                    const RadioListTile<AppColorMode>(
                      value: AppColorMode.appDefault,
                      title: Text('默认配色'),
                      subtitle: Text('活力粉主题'),
                      secondary: Icon(Icons.palette_outlined),
                    ),
                    const RadioListTile<AppColorMode>(
                      value: AppColorMode.dynamic,
                      title: Text('动态取色'),
                      subtitle: Text('跟随 Android 12+ 系统壁纸配色，\n不支持时自动回退默认配色'),
                      secondary: Icon(Icons.wallpaper_rounded),
                    ),
                    RadioListTile<AppColorMode>(
                      value: AppColorMode.custom,
                      title: const Text('自定义颜色'),
                      subtitle: const Text('手动挑选主题色，自动生成整套配色'),
                      secondary: Icon(Icons.colorize_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              if (settings.colorMode != AppColorMode.custom) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SeedColorPicker(
                  color: Color(settings.seedColor),
                  onChanged: settings.setSeedColor,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
