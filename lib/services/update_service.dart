/// 应用更新检查：以 GitHub Releases 为唯一更新源。
/// /releases/latest 只返回最新正式版（排除 prerelease/draft），
/// tag_name 提供版本号，body 提供更新说明，assets 提供 APK 直链。
library;

import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// GitHub 仓库主页（关于页与更新检查共用）。
const String kRepoUrl = 'https://github.com/aether1917/Haqi-Station';

/// 一个可更新的远程版本。
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.notes,
    required this.apkUrl,
  });

  /// 版本号（去掉 tag 前缀 v，如 `1.4.0`）。
  final String version;

  /// Release Notes 原文（Markdown）。
  final String notes;

  /// APK 下载直链。
  final String apkUrl;
}

class UpdateService {
  static const _latestApi =
      'https://api.github.com/repos/aether1917/Haqi-Station/releases/latest';
  static const _timeout = Duration(seconds: 12);

  /// 拉取最新版本信息；网络失败或数据不完整返回 null（与"无更新"区分开）。
  static Future<AppUpdate?> fetchLatest() async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(_latestApi));
        // GitHub API 要求携带 UA，否则 403。
        request.headers.set(HttpHeaders.userAgentHeader, 'haqi-station-app');
        final response =
            await request.close().timeout(_timeout);
        if (response.statusCode != 200) return null;
        final body = await utf8.decoder.bind(response).join();
        return parseRelease(
            jsonDecode(body) as Map<String, dynamic>);
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// 从 GitHub release JSON 解析更新信息，数据不完整返回 null。
  static AppUpdate? parseRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '')
        .trim()
        .replaceFirst(RegExp(r'^v'), '');
    final apkUrl = [
      for (final asset in json['assets'] as List<dynamic>? ?? const [])
        if (asset is Map<String, dynamic> &&
            (asset['name'] as String? ?? '').endsWith('.apk'))
          asset['browser_download_url'] as String,
    ].firstOrNull;
    if (tag.isEmpty || apkUrl == null || apkUrl.isEmpty) return null;
    return AppUpdate(
      version: tag,
      notes: json['body'] as String? ?? '',
      apkUrl: apkUrl,
    );
  }

  /// 远程版本是否比本地新。比较 X.Y.Z 数字三段（忽略 pre-release 后缀），
  /// versionCode 不在远端元数据里，语义化版本三段足够可靠。
  static bool isNewer(String remote, String local) {
    final r = _versionTriple(remote);
    final l = _versionTriple(local);
    for (var i = 0; i < 3; i++) {
      if (r[i] != l[i]) return r[i] > l[i];
    }
    return false;
  }

  static List<int> _versionTriple(String version) {
    final core =
        version.trim().replaceFirst(RegExp(r'^v'), '').split('-').first;
    final parts = core.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.sublist(0, 3);
  }

  /// 用系统浏览器打开 APK 下载链接，返回是否成功调起。
  static Future<bool> downloadApk(String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
