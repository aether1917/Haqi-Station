/// 应用更新检查：以 Gitee Releases 为主源（国内直连稳定），GitHub 兜底。
/// 两平台 latest 接口均返回正式版（排除 prerelease/draft），
/// tag_name 提供版本号，body 提供更新说明，assets 提供 APK 直链。
/// 注意：更新检查匿名访问即可，用户的 Gitee 私人令牌绝不进入应用。
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
    this.prerelease = false,
  });

  /// 版本号（去掉 tag 前缀 v，如 `1.4.0` 或 `1.5.0-beta`）。
  final String version;

  /// Release Notes 原文（Markdown）。
  final String notes;

  /// APK 下载直链。
  final String apkUrl;

  /// 是否为预览版本（beta / alpha）。
  final bool prerelease;
}

class UpdateService {
  static const _giteeRepo = 'https://gitee.com/api/v5/repos/aether2000/Haqi-Station';
  static const _githubRepo = 'https://api.github.com/repos/aether1917/Haqi-Station';
  static const _timeout = Duration(seconds: 12);

  /// 拉取最新版本信息。
  ///
  /// 普通用户 [includePrerelease] 为 false：只看正式版（latest 接口天然
  /// 排除 prerelease/draft）。加入预览体验计划后为 true：改用列表接口，
  /// 取最新的一条（含 beta / alpha 预览版）。
  ///
  /// 两边都失败返回 null（与"无更新"区分开）。
  static Future<AppUpdate?> fetchLatest({required bool includePrerelease}) async {
    if (includePrerelease) {
      final gitee = await _fetchList('$_giteeRepo/releases?per_page=10&direction=desc');
      if (gitee != null) return gitee;
      return _fetchList('$_githubRepo/releases?per_page=10');
    }
    final fromGitee = await _fetchFrom('$_giteeRepo/releases/latest');
    if (fromGitee != null) return fromGitee;
    return _fetchFrom('$_githubRepo/releases/latest');
  }

  static Future<AppUpdate?> _fetchFrom(String url) async {
    final json = await _getJson(url);
    if (json == null) return null;
    if (json['prerelease'] == true || json['draft'] == true) return null;
    return parseRelease(json);
  }

  /// 列表接口：按创建时间倒序，取第一条可解析的 release。
  static Future<AppUpdate?> _fetchList(String url) async {
    final json = await _getJson(url);
    if (json is! List || json.isEmpty) return null;
    for (final entry in json) {
      if (entry is! Map<String, dynamic>) continue;
      if (entry['draft'] == true) continue;
      final update = parseRelease(entry);
      if (update != null) return update;
    }
    return null;
  }

  static Future<dynamic> _getJson(String url) async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        // GitHub API 要求携带 UA，否则 403；Gitee 也建议携带。
        request.headers.set(HttpHeaders.userAgentHeader, 'haqi-station-app');
        final response = await request.close().timeout(_timeout);
        if (response.statusCode != 200) return null;
        final body = await utf8.decoder.bind(response).join();
        return jsonDecode(body);
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// 从 GitHub/Gitee release JSON 解析更新信息（两平台形状兼容），
  /// 数据不完整返回 null。
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
      prerelease: json['prerelease'] == true,
    );
  }

  /// 远程版本是否比本地新。
  ///
  /// 完整语义化比较：数字三段；同号时正式版 > 预发布版；两个预发布版
  /// 按 semver 标识符逐段比较（数字按数值、字母按 ASCII、数字段 <
  /// 字母段、标识符少者小），因此 beta < beta.1 < beta.2 < rc < 正式。
  static bool isNewer(String remote, String local) =>
      compareVersions(remote, local) > 0;

  /// 语义化版本比较，返回正数表示 [a] 比 [b] 新。
  static int compareVersions(String a, String b) {
    final va = _parseVersion(a);
    final vb = _parseVersion(b);
    for (var i = 0; i < 3; i++) {
      if (va.$1[i] != vb.$1[i]) return va.$1[i].compareTo(vb.$1[i]);
    }
    if (va.$2 != vb.$2) return va.$2 ? 1 : -1; // 正式版新于预发布版
    final common = va.$3.length < vb.$3.length ? va.$3.length : vb.$3.length;
    for (var i = 0; i < common; i++) {
      final cmp = _comparePreIdentifier(va.$3[i], vb.$3[i]);
      if (cmp != 0) return cmp;
    }
    return va.$3.length.compareTo(vb.$3.length);
  }

  /// (数字三段, 是否正式版, 预发布标识符列表)。
  static (List<int>, bool, List<String>) _parseVersion(String version) {
    final trimmed = version.trim().replaceFirst(RegExp(r'^v'), '');
    final segments = trimmed.split('-');
    final coreParts = segments.first.split('.');
    final core = <int>[
      for (var i = 0; i < 3; i++)
        i < coreParts.length ? (int.tryParse(coreParts[i]) ?? 0) : 0,
    ];
    final isPrerelease = segments.length > 1;
    final preIds = isPrerelease
        ? segments
            .sublist(1)
            .expand((s) => s.split('.'))
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];
    return (core, !isPrerelease, preIds);
  }

  /// 预发布标识符比较：数字按数值、字母按 ASCII、数字段 < 字母段。
  static int _comparePreIdentifier(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
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
