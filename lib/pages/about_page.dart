import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../widgets/update_page.dart';

/// 关于：检查更新、预览体验计划与 GitHub 仓库。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _packageInfo;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  Future<void> _checkUpdate({required bool manual}) async {
    if (_checking) return;
    setState(() => _checking = true);
    final current = _packageInfo?.version;
    if (current == null) {
      if (!mounted) return;
      setState(() => _checking = false);
      if (manual) _toast(t('versionNotReady'));
      return;
    }
    final update = await UpdateService.fetchLatest(
      includePrerelease: SettingsService.instance.previewProgram,
    );
    if (!mounted) return;
    setState(() => _checking = false);

    if (update == null) {
      if (manual) _toast(t('checkFailed'));
      return;
    }
    if (!UpdateService.isNewer(update.version, current)) {
      if (manual) _toast(t('latest', {'version': current}));
      return;
    }
    await showUpdatePage(context, update);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openRepo() async {
    final uri = Uri.parse(kRepoUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _toast('${t('unableOpen')}: $kRepoUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final version = _packageInfo?.version;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('about'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  leading: const Icon(Icons.system_update_rounded),
                  title: Text(t('checkUpdate')),
                  subtitle: Text(
                      t('currentVersion', {'version': version ?? '…'}),
                      style: const TextStyle(fontSize: 12)),
                  trailing: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.chevron_right_rounded,
                          color: colors.onSurfaceVariant),
                  onTap: () => _checkUpdate(manual: true),
                ),
                Divider(height: 1, indent: 56, color: colors.outlineVariant),
                ListenableBuilder(
                  listenable: SettingsService.instance,
                  builder: (context, _) => SwitchListTile(
                    secondary: const Icon(Icons.bug_report_outlined),
                    title: Text(t('previewProgram')),
                    subtitle: Text(t('previewProgramDesc'),
                        style: const TextStyle(fontSize: 12)),
                    value: SettingsService.instance.previewProgram,
                    onChanged: (joined) {
                      SettingsService.instance.setPreviewProgram(joined);
                      _toast(joined ? t('joinedPreview') : t('leftPreview'));
                    },
                  ),
                ),
                Divider(height: 1, indent: 56, color: colors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: Text(t('gitHubRepo')),
                  subtitle: const Text('aether1917/Haqi-Station',
                      style: TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.open_in_new_rounded,
                      color: colors.onSurfaceVariant),
                  onTap: _openRepo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
