/// 原生分享：走自定义 MethodChannel（见 android MainActivity.shareFiles）。
/// 不用 share_plus 的原因：chooser 未设 ClipData，Android 11+ 上微信/QQ
/// 拿不到文件读权限 —— 微信点开无反应、QQ 能选聊天但发不出内容。
library;

import 'dart:io';

import 'package:flutter/services.dart';

class NativeShare {
  static const _channel = MethodChannel('com.haqi.station/share');

  /// 分享本地文件，返回是否成功调起分享面板。
  /// [names] 与 files 一一对应，作为分享时的展示文件名。
  static Future<bool> shareFiles(List<File> files, {List<String>? names}) async {
    // 原生分享通道仅 Android 实现。
    if (!Platform.isAndroid) return false;
    final existing = [for (final f in files) if (f.existsSync()) f];
    if (existing.isEmpty) return false;
    try {
      await _channel.invokeMethod<bool>('shareFiles', {
        'paths': [for (final f in existing) f.path],
        'mimeTypes': [for (final f in existing) _mimeTypeFor(f.path)],
        if (names != null)
          'names': [
            for (var i = 0; i < names.length && i < existing.length; i++)
              names[i],
          ],
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _mimeTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/*',
    };
  }
}
