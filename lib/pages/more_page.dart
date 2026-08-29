import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import 'about_page.dart';
import 'settings_page.dart';

/// 「更多」一级界面：设置与关于入口。
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('更多', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('设置'),
                  trailing: Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            SettingsPage(settings: SettingsService.instance)),
                  ),
                ),
                Divider(height: 1, indent: 56, color: colors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('关于'),
                  trailing: Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
