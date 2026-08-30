/// 表情包数据模型与元数据持久化。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 允许导入的图片 / GIF 扩展名。
const Set<String> kAllowedExtensions = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
};

class Sticker {
  Sticker({
    required this.id,
    required this.name,
    required this.ext,
    required this.addedAt,
    this.category,
  });

  /// 唯一 ID，同时是存储文件名的主干。
  final String id;

  /// 展示名称（不含扩展名，通常来自原文件名）。
  final String name;

  /// 小写扩展名，如 `png` / `gif`。
  final String ext;

  /// 导入时间（epoch 毫秒）。
  final int addedAt;

  /// 所属分类名；null 或空串表示「未分类」。分类可变，便于归组。
  String? category;

  String get fileName => '$id.$ext';
  bool get isGif => ext == 'gif';
  bool get uncategorized => category == null || category!.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ext': ext,
        'addedAt': addedAt,
        if (category != null) 'category': category,
      };

  factory Sticker.fromJson(Map<String, dynamic> json) => Sticker(
        id: json['id'] as String,
        name: json['name'] as String,
        ext: json['ext'] as String,
        addedAt: json['addedAt'] as int,
        category: json['category'] as String?,
      );
}

/// 表情包仓库：负责文件的复制存储与元数据（含排序）持久化。
class StickerStore extends ChangeNotifier {
  static const _metaKey = 'haqi.stickers.v1';
  static const _categoriesKey = 'haqi.categories.v1';
  static const _randomChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  final List<Sticker> _items = [];
  final List<String> _categories = [];
  bool _loaded = false;
  late Directory _dir;

  List<Sticker> get items => List.unmodifiable(_items);
  List<String> get categories => List.unmodifiable(_categories);
  bool get loaded => _loaded;
  int get count => _items.length;

  /// 表情包文件所在目录（应用私有 Documents/stickers）。
  Future<Directory> ensureDir() async {
    if (!_loaded) await load();
    return _dir;
  }

  String pathOf(Sticker s) => p.join(_dir.path, s.fileName);

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(docs.path, 'stickers'));
    if (!_dir.existsSync()) _dir.createSync(recursive: true);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    _items
      ..clear()
      ..addAll(_decode(raw));
    // 清理孤儿元数据（文件已丢失的记录）。
    _items.removeWhere((s) => !File(pathOf(s)).existsSync());
    // 只保留仍被引用的分类，避免删除表情包后堆积空分类。
    _categories
      ..clear()
      ..addAll(prefs.getStringList(_categoriesKey) ?? const <String>[])
      ..retainWhere((c) => _items.any((s) => s.category == c));
    _loaded = true;
    notifyListeners();
  }

  List<Sticker> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list)
          Sticker.fromJson(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metaKey, jsonEncode([for (final s in _items) s.toJson()]));
    await prefs.setStringList(_categoriesKey, _categories);
  }

  /// 从选中的文件导入表情包，返回成功导入数量。
  Future<int> importFiles(List<String> sourcePaths) async {
    var imported = 0;
    for (final sourcePath in sourcePaths) {
      final ext = p.extension(sourcePath).replaceAll('.', '').toLowerCase();
      if (!kAllowedExtensions.contains(ext)) continue;
      final source = File(sourcePath);
      if (!source.existsSync()) continue;

      final id =
          '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
      final name = p.basenameWithoutExtension(sourcePath);
      try {
        await source.copy(p.join(_dir.path, '$id.$ext'));
      } on FileSystemException {
        continue;
      }
      _items.add(Sticker(
        id: id,
        name: name.isEmpty ? '表情包' : name,
        ext: ext,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ));
      imported++;
    }
    if (imported > 0) {
      await _persist();
      notifyListeners();
    }
    return imported;
  }

  /// 批量删除（同时删除磁盘文件与元数据）。
  Future<void> deleteMany(Iterable<String> ids) async {
    final idSet = ids.toSet();
    for (final s in _items.where((s) => idSet.contains(s.id)).toList()) {
      try {
        File(pathOf(s)).deleteSync();
      } on FileSystemException {
        // 文件可能已不存在，忽略。
      }
    }
    _items.removeWhere((s) => idSet.contains(s.id));
    // 一并清理不再被引用的分类。
    _categories.retainWhere((c) => _items.any((s) => s.category == c));
    await _persist();
    notifyListeners();
  }

  /// 创建分类并把选中的表情包归入其中；同名分类已存在时直接归入不重复建。
  /// 名称去除首尾空白后为空则返回 null。
  Future<String?> createCategory(String name, Iterable<String> stickerIds) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (!_categories.contains(trimmed)) _categories.add(trimmed);
    await assignCategory(trimmed, stickerIds);
    return trimmed;
  }

  /// 把选中的表情包归入指定分类。
  Future<void> assignCategory(String name, Iterable<String> stickerIds) async {
    final ids = stickerIds.toSet();
    for (final s in _items) {
      if (ids.contains(s.id)) s.category = name;
    }
    notifyListeners();
    await _persist();
  }

  /// 把选中的表情包移出指定分类（变为未分类）；分类因此变空时一并删除。
  Future<void> removeFromCategory(String name, Iterable<String> stickerIds) async {
    final ids = stickerIds.toSet();
    for (final s in _items) {
      if (ids.contains(s.id) && s.category == name) s.category = null;
    }
    _categories.retainWhere((c) => _items.any((s) => s.category == c));
    notifyListeners();
    await _persist();
  }

  /// 分类栏拖拽排序。配合框架 `onReorderItem` 回调（已由框架调整索引），
  /// 语义与 [reorder] 一致：newIndex 即最终落位。
  Future<void> reorderCategory(int oldIndex, int newIndex) async {
    final length = _categories.length;
    if (oldIndex < 0 ||
        oldIndex >= length ||
        newIndex < 0 ||
        newIndex >= length ||
        newIndex == oldIndex) {
      return;
    }
    final moved = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, moved);
    notifyListeners();
    await _persist();
  }

  /// 删除分类本身，其下表情包全部变为未分类。
  Future<void> deleteCategory(String name) async {
    _categories.remove(name);
    for (final s in _items) {
      if (s.category == name) s.category = null;
    }
    notifyListeners();
    await _persist();
  }

  /// 拖拽排序：语义与 reorderable_grid_view 一致 ——
  /// newIndex 即松手后的最终落位（包在拖拽中已按目标格预览动画），
  /// 不要做 ReorderableListView 那样的 `newIndex -= 1` 调整，
  /// 否则向后拖会原地弹回。
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _items.length ||
        newIndex < 0 ||
        newIndex >= _items.length ||
        newIndex == oldIndex) {
      return;
    }
    final moved = _items.removeAt(oldIndex);
    _items.insert(newIndex, moved);
    // 先刷新 UI 再落盘，避免等 prefs 写入期间出现一帧旧顺序的闪烁。
    notifyListeners();
    await _persist();
  }

  static String _randomSuffix() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final sb = StringBuffer();
    var seed = now;
    for (var i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      sb.write(_randomChars[seed % _randomChars.length]);
    }
    return sb.toString();
  }
}
