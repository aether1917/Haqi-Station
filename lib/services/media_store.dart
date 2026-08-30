/// MediaStore 访问：内建内容查看器的数据源与所选内容的落盘。
/// 原生实现见 android MainActivity 的 queryMedia / resolveMediaPaths。
library;

import 'package:flutter/services.dart';

/// 媒体库里的一条照片或视频。
class MediaItem {
  const MediaItem({
    required this.uri,
    required this.isVideo,
    required this.bucket,
    required this.dateModified,
    required this.path,
  });

  /// content:// URI（读取落盘用）。
  final String uri;

  final bool isVideo;

  /// 所属相册（目录名）。
  final String bucket;

  /// 修改时间（epoch 秒）。
  final int dateModified;

  /// 真实文件路径；云端等内容可能为空串。
  final String path;
}

class MediaStoreService {
  static const _channel = MethodChannel('com.haqi.station/share');

  /// 扫描媒体库（图片 + 视频），按修改时间倒序。
  static Future<List<MediaItem>> queryMedia() async {
    try {
      final rows = await _channel
          .invokeMethod<List<dynamic>>('queryMedia');
      return [
        for (final row in rows ?? const [])
          MediaItem(
            uri: row['uri'] as String,
            isVideo: row['isVideo'] as bool,
            bucket: row['bucket'] as String? ?? '未分类',
            dateModified: (row['dateModified'] as num?)?.toInt() ?? 0,
            path: row['path'] as String? ?? '',
          ),
      ];
    } on PlatformException {
      return const [];
    }
  }

  /// 把选中的 content:// 转成可导入的文件路径
  /// （优先真实路径，云端等内容自动复制到缓存）。
  static Future<List<String>> resolveMediaPaths(List<String> uris) async {
    if (uris.isEmpty) return const [];
    try {
      final paths = await _channel
          .invokeMethod<List<dynamic>>('resolveMediaPaths', {'uris': uris});
      return [for (final p in paths ?? const <dynamic>[]) p as String];
    } on PlatformException {
      return const [];
    }
  }

  /// 调起系统文件管理器（DocumentsUI）多选图片，
  /// 返回已复制到应用缓存的文件路径；取消返回空列表。
  static Future<List<String>> pickFilesSystem() async {
    try {
      final paths =
          await _channel.invokeMethod<List<dynamic>>('pickFilesSystem');
      return [for (final p in paths ?? const <dynamic>[]) p as String];
    } on PlatformException {
      return const [];
    }
  }
}
