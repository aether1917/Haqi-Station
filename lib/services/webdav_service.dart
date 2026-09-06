/// WebDAV 同步：备份 zip 上传 / 列表 / 下载恢复。
/// 纯 Dart 实现，Android 与 Windows 通用。
library;

import 'dart:io';

import 'package:webdav_client/webdav_client.dart' as webdav;

import 'settings_service.dart';

class WebDavService {
  static const _remoteDir = 'haqi-station';

  static webdav.Client? _clientFromSettings() {
    final cfg = SettingsService.instance.webdavConfig;
    if (cfg.url.trim().isEmpty) return null;
    return webdav.newClient(
      cfg.url.trim(),
      user: cfg.username,
      password: cfg.password,
    );
  }

  /// 测试连接（列根目录探测可达性与凭据）。
  static Future<bool> testConnection() async {
    final client = _clientFromSettings();
    if (client == null) return false;
    try {
      await client.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _remoteBackupPath(String fileName) =>
      '/$_remoteDir/$fileName';

  /// 上传备份 zip 到 WebDAV（目录不存在时逐级创建）。
  static Future<bool> uploadBackup(File zip) async {
    final client = _clientFromSettings();
    if (client == null) return false;
    try {
      await client.mkdirAll('/$_remoteDir');
      await client.writeFromFile(zip.path, _remoteBackupPath(zip.uri.pathSegments.last));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 列出远端备份文件名（按名称倒序，仅 .zip）。
  static Future<List<String>> listBackups() async {
    final client = _clientFromSettings();
    if (client == null) return const [];
    try {
      final files = await client.readDir('/$_remoteDir');
      final names = [
        for (final f in files)
          if ((f.name ?? '').endsWith('.zip')) f.name!,
      ];
      names.sort((a, b) => b.compareTo(a));
      return names;
    } catch (_) {
      return const [];
    }
  }

  /// 下载远端备份到本地临时文件，返回本地路径；失败返回 null。
  static Future<String?> downloadBackup(String fileName) async {
    final client = _clientFromSettings();
    if (client == null) return null;
    try {
      final tmp = File(
          '${Directory.systemTemp.path}/webdav_${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await client.read2File(_remoteBackupPath(fileName), tmp.path);
      return tmp.path;
    } catch (_) {
      return null;
    }
  }
}
