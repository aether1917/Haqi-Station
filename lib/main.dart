import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'services/settings_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService.instance;
  await settings.load();
  runApp(HaqiApp(settings: settings));
}

class HaqiApp extends StatelessWidget {
  const HaqiApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: '哈气站',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: settings.themeMode,
        home: const HomePage(),
      ),
    );
  }
}
