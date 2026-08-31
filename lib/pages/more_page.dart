import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../services/settings_service.dart';
import 'about_page.dart';
import 'donation_page.dart';
import 'settings_page.dart';

/// 「更多」一级界面：设置与关于入口。
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('tabMore'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  title: Text(t('settings')),
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
                  title: Text(t('about')),
                  trailing: Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 捐赠入口：独立卡片，位于设置/关于列表下方。
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.volunteer_activism_outlined,
                  color: colors.primary),
              title: Text(t('donation')),
              subtitle: Text(t('donationSubtitle'), style: const TextStyle(fontSize: 12)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DonationPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
