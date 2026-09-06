/// 表情包数据模型与元数据持久化。
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 允许导入的图片 / GIF 扩展名。
const Set<String> kAllowedExtensions = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
};

/// 内置默认分类（始终存在于分类栏，不可删除/重命名，可拖拽排序）。
const String kAllCategory = '全部';
const String kUncategorizedCategory = '未分类';

/// 分类名显示宽度上限：一个中文（全角）计 1，其他字符计 0.5。
const double kMaxCategoryNameWidth = 3.0;

double categoryNameWidth(String name) {
  var width = 0.0;
  for (final rune in name.runes) {
    final isFullWidth = (rune >= 0x2E80 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0xFF01 && rune <= 0xFF60) ||
        (rune >= 0x3000 && rune <= 0x303E);
    width += isFullWidth ? 1 : 0.5;
  }
  return width;
}

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

  /// 展示名称（不含扩展名，通常来自原文件名；可重命名）。
  String name;

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

  /// 应用级单例：表情包页 / 搜索页 / 管理页共享同一份数据。
  /// （测试可另建独立实例。）
  static final StickerStore instance = StickerStore();

  StickerStore();

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
    // 分类栏完整顺序（含默认两个分类）。老数据没有默认分类时补到最前；
    // 用户自建分类只在仍被引用时保留，默认分类永远保留（可排序不可删）。
    final saved = prefs.getStringList(_categoriesKey) ?? const <String>[];
    _categories
      ..clear()
      ..addAll(saved)
      ..remove(kAllCategory)
      ..remove(kUncategorizedCategory)
      ..retainWhere((c) => _items.any((s) => s.category == c))
      ..insert(0, kUncategorizedCategory)
      ..insert(0, kAllCategory);
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
    // 一并清理不再被引用的分类（默认分类保留）。
    _pruneCategories();
    await _persist();
    notifyListeners();
  }

  /// 创建分类并把选中的表情包归入其中；同名分类已存在时直接归入不重复建。
  /// 名称去除首尾空白、不得超过显示宽度上限、不得与内置分类同名，
  /// 违规或为空返回 null。
  Future<String?> createCategory(String name, Iterable<String> stickerIds) async {
    final trimmed = _validateCategoryName(name);
    if (trimmed == null) return null;
    if (!_categories.contains(trimmed)) _categories.add(trimmed);
    await assignCategory(trimmed, stickerIds);
    return trimmed;
  }

  /// 重命名分类：其下表情包的分类标记同步更新。
  /// 名称违规/与内置同名/重名/原分类不存在时返回 null。
  Future<String?> renameCategory(String oldName, String newName) async {
    final trimmed = _validateCategoryName(newName);
    if (trimmed == null) return null;
    if (trimmed == oldName) return oldName;
    if (!_categories.contains(oldName)) return null;
    if (_categories.contains(trimmed)) return null;
    final index = _categories.indexOf(oldName);
    _categories[index] = trimmed;
    for (final s in _items) {
      if (s.category == oldName) s.category = trimmed;
    }
    notifyListeners();
    await _persist();
    return trimmed;
  }

  /// 分类名规范化校验：非空、去首尾空白、不超宽度上限、不与内置同名。
  /// 通过返回去除空白后的名称，否则返回 null。
  String? _validateCategoryName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == kAllCategory || trimmed == kUncategorizedCategory) {
      return null;
    }
    if (categoryNameWidth(trimmed) > kMaxCategoryNameWidth) return null;
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
    _pruneCategories();
    notifyListeners();
    await _persist();
  }

  /// 清理不再被任何表情包引用的分类（内置默认分类保留）。
  void _pruneCategories() {
    _categories.retainWhere((c) =>
        c == kAllCategory ||
        c == kUncategorizedCategory ||
        _items.any((s) => s.category == c));
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

  /// 删除分类本身，其下表情包全部变为未分类；内置分类不可删除。
  Future<void> deleteCategory(String name) async {
    if (name == kAllCategory || name == kUncategorizedCategory) return;
    _categories.remove(name);
    for (final s in _items) {
      if (s.category == name) s.category = null;
    }
    notifyListeners();
    await _persist();
  }

  /// 重命名表情包（仅展示名；非法字符或空名返回 false）。
  Future<bool> renameSticker(Sticker sticker, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == sticker.name) return false;
    if (trimmed.contains(RegExp(r'[\\/:*?"<>|]'))) return false;
    final index = _items.indexWhere((s) => s.id == sticker.id);
    if (index == -1) return false;
    _items[index].name = trimmed;
    notifyListeners();
    await _persist();
    return true;
  }

  /// 导出备份 zip（表情包文件 + meta.json），返回是否成功。
  Future<bool> exportBackup(File targetZip) async {
    try {
      final archive = Archive();
      archive.addFile(ArchiveFile.bytes(
        'meta.json',
        utf8.encode(jsonEncode({
          'app': 'haqi-station',
          'backupVersion': 1,
          'stickers': [for (final s in _items) s.toJson()],
          'categories': _categories,
        })),
      ));
      for (final s in _items) {
        final f = File(pathOf(s));
        if (!f.existsSync()) continue;
        archive.addFile(ArchiveFile.bytes(
          'files/${s.fileName}',
          f.readAsBytesSync(),
        ));
      }
      final encoded = ZipEncoder().encode(archive);
      targetZip
        ..createSync(recursive: true)
        ..writeAsBytesSync(encoded);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 从备份 zip 导入：合并表情包与分类（已有同 id 的跳过），
  /// 返回导入的表情包数量；zip 无效返回 -1。
  Future<int> importBackup(File zipFile) async {
    Archive archive;
    try {
      final bytes = zipFile.readAsBytesSync();
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return -1;
    }

    final metaEntry = archive.findFile('meta.json');
    if (metaEntry == null) return -1;
    Map<String, dynamic> meta;
    try {
      meta = jsonDecode(utf8.decode(metaEntry.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      return -1;
    }

    var imported = 0;
    for (final entry in meta['stickers'] as List<dynamic>? ?? const []) {
      if (entry is! Map<String, dynamic>) continue;
      final sticker = Sticker.fromJson(
          Map<String, dynamic>.from(entry as Map<dynamic, dynamic>));
      if (_items.any((s) => s.id == sticker.id)) continue;
      final dataEntry = archive.findFile('files/${sticker.fileName}');
      if (dataEntry == null) continue;
      final target = File(pathOf(sticker));
      target.writeAsBytesSync(List<int>.from(dataEntry.content as List<int>));
      _items.add(sticker);
      imported++;
    }
    // 合并备份里的分类（内置分类天然保留；无引用的会在导入后自然消失?——
    // 这里保留有引用的即可）。
    for (final c in meta['categories'] as List<dynamic>? ?? const []) {
      if (c is String &&
          c != kAllCategory &&
          c != kUncategorizedCategory &&
          !_categories.contains(c) &&
          _items.any((s) => s.category == c)) {
        _categories.add(c);
      }
    }
    await _persist();
    notifyListeners();
    return imported;
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
