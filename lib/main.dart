import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'pages/home_page.dart';
import 'services/dynamic_scheme.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'theme.dart';
import 'widgets/update_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService.instance;
  await settings.load();
  runApp(HaqiApp(settings: settings));
}

class HaqiApp extends StatefulWidget {
  const HaqiApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<HaqiApp> createState() => _HaqiAppState();
}

class _HaqiAppState extends State<HaqiApp> {
  /// 弹「发现新版本」用：HaqiApp 的 context 在 Navigator 之上，
  /// showDialog 必须挂在 Navigator 之下。
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Android 12+ 系统壁纸调色板，不支持时为 null。
  CorePalette? _corePalette;

  @override
  void initState() {
    super.initState();
    _fetchDynamicPalette();
    Future.delayed(const Duration(seconds: 4), _silentCheckUpdate);
  }

  /// 启动静默检查更新：普通用户只看正式版；加入预览体验计划后
  /// 包含 beta / alpha。发现新版本时全屏展示，右上角 × 可关闭。
  Future<void> _silentCheckUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final update = await UpdateService.fetchLatest(
      includePrerelease: widget.settings.previewProgram,
    );
    if (update == null) return;
    if (!UpdateService.isNewer(update.version, info.version)) return;
    final navigator = _navigatorKey.currentContext;
    if (navigator == null || !navigator.mounted) return;
    await showUpdatePage(navigator, update);
  }

  Future<void> _fetchDynamicPalette() async {
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (mounted) setState(() => _corePalette = palette);
    } catch (_) {
      // 设备/平台不支持动态取色，保持默认配色。
    }
  }

  /// 按色彩模式解析明/暗两套配色：
  /// 默认 → 内置活力粉；动态 → Android 12+ 壁纸取色（不支持时回退默认）；
  /// 自定义 → 用户种子色。
  (ColorScheme, ColorScheme) _resolveSchemes() {
    final lightDynamic = dynamicScheme(_corePalette, brightness: Brightness.light);
    final darkDynamic = dynamicScheme(_corePalette, brightness: Brightness.dark);
    return switch (widget.settings.colorMode) {
      AppColorMode.dynamic => lightDynamic != null && darkDynamic != null
          ? (lightDynamic, darkDynamic)
          : (defaultLightScheme(), defaultDarkScheme()),
      AppColorMode.custom =>
        schemesFromSeed(Color(widget.settings.seedColor)),
      AppColorMode.appDefault => (defaultLightScheme(), defaultDarkScheme()),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final (light, dark) = _resolveSchemes();
        return MaterialApp(
          title: '哈气站',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: buildLightTheme(light),
          darkTheme: buildDarkTheme(dark),
          themeMode: widget.settings.themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
