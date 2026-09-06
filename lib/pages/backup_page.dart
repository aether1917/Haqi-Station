import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/media_store.dart';
import '../services/settings_service.dart';
import '../services/sticker_store.dart';
import '../services/webdav_service.dart';

/// 备份页：本地导出/导入（zip）+ WebDAV 云同步（手机/电脑互通）。
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final StickerStore _store = StickerStore.instance;
  bool _busy = false;

  late final TextEditingController _url =
      TextEditingController(text: SettingsService.instance.webdavConfig.url);
  late final TextEditingController _user =
      TextEditingController(text: SettingsService.instance.webdavConfig.username);
  late final TextEditingController _pass =
      TextEditingController(text: SettingsService.instance.webdavConfig.password);
  List<String> _remoteBackups = const [];

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _busyWrap(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- 本地备份（zip） ----------

  Future<void> _exportLocal() => _busyWrap(() async {
        final stamp = _stamp();
        final temp = File('${Directory.systemTemp.path}/haqi-backup-$stamp.zip');
        final ok = await _store.exportBackup(temp);
        if (!mounted) return;
        if (!ok) {
          _toast(t('backupFailed'));
          return;
        }
        bool saved = false;
        if (Platform.isAndroid) {
          saved = await MediaStoreService.pickExportLocation(
            defaultName: 'haqi-backup-$stamp.zip',
            sourcePath: temp.path,
          );
        } else {
          final target = await FilePicker.saveFile(
            fileName: 'haqi-backup-$stamp.zip',
            bytes: temp.readAsBytesSync(),
            mimeType: 'application/zip',
          );
          if (target != null) {
            saved = true;
          }
        }
        if (!mounted) return;
        temp.deleteSync();
        _toast(saved ? t('backupExported') : t('backupCancelled'));
      });

  Future<void> _importLocal() => _busyWrap(() async {
        List<String> paths;
        if (Platform.isAndroid) {
          final cached = await MediaStoreService.importUriToCache();
          if (!mounted) return;
          paths = cached == null ? [] : [cached];
        } else {
          final picked = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['zip'],
          );
          paths = [for (final f in picked) if (f.path != null) f.path!];
        }
        if (paths.isEmpty) {
          _toast(t('backupCancelled'));
          return;
        }
        final count = await _store.importBackup(File(paths.first));
        if (!mounted) return;
        _toast(count < 0 ? t('backupInvalid') : t('backupImported', {'n': count}));
      });

  // ---------- WebDAV ----------

  Future<void> _saveWebDav() => _busyWrap(() async {
        await SettingsService.instance.setWebDavConfig(WebDavConfig(
          url: _url.text.trim(),
          username: _user.text.trim(),
          password: _pass.text,
        ));
        _toast(t('webdavSaved'));
      });

  Future<void> _testWebDav() => _busyWrap(() async {
        await SettingsService.instance.setWebDavConfig(WebDavConfig(
          url: _url.text.trim(),
          username: _user.text.trim(),
          password: _pass.text,
        ));
        final ok = await WebDavService.testConnection();
        _toast(ok ? t('webdavTestOk') : t('webdavTestFail'));
      });

  Future<void> _uploadToWebDav() => _busyWrap(() async {
        final stamp = _stamp();
        final temp = File('${Directory.systemTemp.path}/haqi-backup-$stamp.zip');
        final ok = await _store.exportBackup(temp);
        if (!mounted) return;
        if (!ok) {
          _toast(t('backupFailed'));
          return;
        }
        final uploaded = await WebDavService.uploadBackup(temp);
        if (!mounted) return;
        temp.deleteSync();
        if (uploaded) {
          _remoteBackups = await WebDavService.listBackups();
          if (mounted) setState(() {});
        }
        _toast(uploaded ? t('webdavUploadOk') : t('webdavUploadFail'));
      });

  Future<void> _refreshRemote() => _busyWrap(() async {
        final list = await WebDavService.listBackups();
        if (!mounted) return;
        setState(() => _remoteBackups = list);
        if (list.isEmpty) _toast(t('webdavEmpty'));
      });

  Future<void> _restoreFromWebDav(String fileName) => _busyWrap(() async {
        final cached = await WebDavService.downloadBackup(fileName);
        if (!mounted || cached == null) {
          _toast(t('webdavDownloadFail'));
          return;
        }
        final count = await _store.importBackup(File(cached));
        if (!mounted) return;
        File(cached).deleteSync();
        _toast(count < 0 ? t('backupInvalid') : t('backupImported', {'n': count}));
      });

  String _stamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('backup'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (_busy) const LinearProgressIndicator(),
          _section(context, t('backupLocalSection')),
          _card(context, [
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
              onTap: _exportLocal,
            ),
            Divider(height: 1, indent: 56, color: colors.outlineVariant),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: Text(t('backupImport')),
              subtitle: Text(t('backupImportDesc'),
                  style: const TextStyle(fontSize: 12)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant),
              onTap: _importLocal,
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, t('webdavSection')),
          _card(context, [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: t('webdavUrl'),
                  hintText: 'https://dav.example.com/dav/',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _user,
                decoration: InputDecoration(
                  labelText: t('webdavUser'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t('webdavPassword'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _saveWebDav,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(t('webdavSave')),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _testWebDav,
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: Text(t('webdavTest')),
                  ),
                ],
              ),
            ),
            Divider(height: 16, color: colors.outlineVariant),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(t('webdavUpload')),
              onTap: _uploadToWebDav,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(t('webdavRestore')),
              subtitle: _remoteBackups.isEmpty
                  ? Text(t('webdavEmpty'), style: const TextStyle(fontSize: 12))
                  : null,
              onTap: () async {
                await _refreshRemote();
                if (mounted && _remoteBackups.isNotEmpty) {
                  _showRemotePicker();
                }
              },
            ),
          ]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(t('backupHint'),
                style:
                    TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showRemotePicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(t('webdavRestore'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final name in _remoteBackups)
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title:
                            Text(name, style: const TextStyle(fontSize: 13)),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _restoreFromWebDav(name);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
