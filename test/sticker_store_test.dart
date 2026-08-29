import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqi_station/services/sticker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;

  Future<StickerStore> seededStore() async {
    final store = StickerStore();
    await store.load();
    return store;
  }

  List<String> ids(StickerStore store) =>
      [for (final s in store.items) s.id];

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('haqi_test');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => docsDir.path);

    final stickers = [
      {'id': 'a', 'name': 'A', 'ext': 'png', 'addedAt': 1},
      {'id': 'b', 'name': 'B', 'ext': 'png', 'addedAt': 2},
      {'id': 'c', 'name': 'C', 'ext': 'png', 'addedAt': 3},
    ];
    Directory('${docsDir.path}/stickers').createSync();
    for (final s in stickers) {
      File('${docsDir.path}/stickers/${s['id']}.${s['ext']}')
          .writeAsStringSync('x');
    }
    SharedPreferences.setMockInitialValues({
      'haqi.stickers.v1': jsonEncode(stickers),
    });
  });

  tearDown(() async {
    if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
  });

  group('StickerStore.reorder（reorderable_grid_view 语义：newIndex 即最终落位）', () {
    test('向后拖一格：A 拖到 B 后面', () async {
      final store = await seededStore();
      await store.reorder(0, 1);
      expect(ids(store), ['b', 'a', 'c']);
    });

    test('向后拖两格：A 拖到 C 后面', () async {
      final store = await seededStore();
      await store.reorder(0, 2);
      expect(ids(store), ['b', 'c', 'a']);
    });

    test('向前拖：C 拖到最前', () async {
      final store = await seededStore();
      await store.reorder(2, 0);
      expect(ids(store), ['c', 'a', 'b']);
    });

    test('排序结果持久化，重新加载后保持', () async {
      final store = await seededStore();
      await store.reorder(0, 1);

      final reloaded = await seededStore();
      expect(ids(reloaded), ['b', 'a', 'c']);
    });

    test('越界或原位的调用是安全的空操作', () async {
      final store = await seededStore();
      await store.reorder(0, 0);
      await store.reorder(-1, 2);
      await store.reorder(0, 3);
      expect(ids(store), ['a', 'b', 'c']);
    });
  });
}
