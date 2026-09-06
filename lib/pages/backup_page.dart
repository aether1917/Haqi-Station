import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/media_store.dart';
import '../services/sticker_store.dart';

/// 备份页：导出（表情包文件 + 分类为 zip）与导入恢复。
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final StickerStore _store = StickerStore.instance;
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final temp = File(
          '${Directory.systemTemp.path}/haqi-backup-$stamp.zip');
      final ok = await _store.exportBackup(temp);
      if (!mounted) return;
      if (!ok) {
        _toast(t('backupFailed'));
        return;
      }
      final saved = await MediaStoreService.pickExportLocation(
        defaultName: 'haqi-backup-$stamp.zip',
        sourcePath: temp.path,
      );
      if (!mounted) return;
      temp.deleteSync();
      _toast(saved ? t('backupExported') : t('backupCancelled'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final cached = await MediaStoreService.importUriToCache();
      if (!mounted || cached == null) {
        if (mounted) _toast(t('backupCancelled'));
        return;
      }
      final count = await _store.importBackup(File(cached));
      if (!mounted) return;
      File(cached).deleteSync();
      _toast(count < 0
          ? t('backupInvalid')
          : t('backupImported', {'n': count}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('backup'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  leading: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded),
                  title: Text(t('backupExport')),
                  subtitle: Text(t('backupExportDesc'),
                      style: const TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant),
                  onTap: _busy ? null : _export,
                ),
                Divider(height: 1, indent: 56, color: colors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: Text(t('backupImport')),
                  subtitle: Text(t('backupImportDesc'),
                      style: const TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant),
                  onTap: _busy ? null : _import,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(t('backupHint'),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
