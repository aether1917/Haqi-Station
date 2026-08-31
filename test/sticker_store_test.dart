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

  group('StickerStore 分类', () {
    test('加载后分类栏始终包含内置「全部 / 未分类」', () async {
      final store = await seededStore();
      expect(store.categories, [kAllCategory, kUncategorizedCategory]);
    });

    test('创建分类并把选中项归入，重载后保持', () async {
      final store = await seededStore();
      final name = await store.createCategory('萌猫', ['a', 'c']);
      expect(name, '萌猫');
      expect(store.categories,
          [kAllCategory, kUncategorizedCategory, '萌猫']);
      expect(
        {for (final s in store.items) s.id: s.category},
        {'a': '萌猫', 'b': null, 'c': '萌猫'},
      );

      final reloaded = await seededStore();
      expect(reloaded.categories,
          [kAllCategory, kUncategorizedCategory, '萌猫']);
      expect(
        {for (final s in reloaded.items) s.id: s.category},
        {'a': '萌猫', 'b': null, 'c': '萌猫'},
      );
    });

    test('同名分类直接归入，不重复创建', () async {
      final store = await seededStore();
      await store.createCategory('萌猫', ['a']);
      await store.createCategory('萌猫', ['b']);
      expect(store.categories,
          [kAllCategory, kUncategorizedCategory, '萌猫']);
      expect(store.items.firstWhere((s) => s.id == 'b').category, '萌猫');
    });

    test('空白名称返回 null 且不产生分类', () async {
      final store = await seededStore();
      expect(await store.createCategory('   ', ['a']), isNull);
      expect(store.categories, [kAllCategory, kUncategorizedCategory]);
      expect(store.items.firstWhere((s) => s.id == 'a').category, isNull);
    });

    test('名称长度限制：3 个汉字以内、超限或与内置同名拒绝', () async {
      final store = await seededStore();
      expect(await store.createCategory('萌猫', ['a']), '萌猫');
      expect(await store.createCategory('四个汉字名', ['a']), isNull);
      expect(await store.createCategory('abc123', ['a']), 'abc123'); // 6 半角 = 3 宽
      expect(await store.createCategory('abc1234', ['a']), isNull);
      expect(await store.createCategory(kUncategorizedCategory, ['a']), isNull);
      expect(store.categories, [kAllCategory, kUncategorizedCategory, '萌猫', 'abc123']);
    });

    test('内置分类不可删除', () async {
      final store = await seededStore();
      await store.deleteCategory(kAllCategory);
      await store.deleteCategory(kUncategorizedCategory);
      expect(store.categories, [kAllCategory, kUncategorizedCategory]);
    });

    test('删除表情包后清理无引用分类，默认分类保留', () async {
      final store = await seededStore();
      await store.createCategory('萌猫', ['a']);
      await store.deleteMany(['a']);
      expect(store.categories, [kAllCategory, kUncategorizedCategory]);

      final reloaded = await seededStore();
      expect(reloaded.categories, [kAllCategory, kUncategorizedCategory]);
    });

    test('deleteCategory 删除分类，其下表情包变为未分类', () async {
      final store = await seededStore();
      await store.createCategory('萌猫', ['a', 'c']);
      await store.deleteCategory('萌猫');
      expect(store.categories, [kAllCategory, kUncategorizedCategory]);
      expect(
        {for (final s in store.items) s.id: s.uncategorized},
        {'a': true, 'b': true, 'c': true},
      );

      final reloaded = await seededStore();
      expect(reloaded.categories, [kAllCategory, kUncategorizedCategory]);
      expect(store.items.every((s) => s.uncategorized), isTrue);
    });

    test('renameCategory 重命名并同步成员，违规时拒绝', () async {
      final store = await seededStore();
      await store.createCategory('萌猫', ['a', 'c']);
      final renamed = await store.renameCategory('萌猫', '喵星');
      expect(renamed, '喵星');
      expect(store.categories,
          [kAllCategory, kUncategorizedCategory, '喵星']);
      expect(store.items.firstWhere((s) => s.id == 'a').category, '喵星');

      // 与内置同名 / 超长 / 重名 均拒绝。
      expect(await store.renameCategory('喵星', kUncategorizedCategory), isNull);
      expect(await store.renameCategory('喵星', '四个汉字名'), isNull);
      await store.createCategory('汪汪', ['b']);
      expect(await store.renameCategory('喵星', '汪汪'), isNull);

      final reloaded = await seededStore();
      expect(reloaded.categories,
          [kAllCategory, kUncategorizedCategory, '喵星', '汪汪']);
    });

    test('removeFromCategory 只移除指定成员，分类变空时一并删除', () async {
      final store = await seededStore();
      await store.createCategory('萌猫', ['a', 'c']);
      await store.removeFromCategory('萌猫', ['a']);
      expect(store.categories,
          [kAllCategory, kUncategorizedCategory, '萌猫']);
      expect(store.items.firstWhere((s) => s.id == 'a').uncategorized, isTrue);
      expect(store.items.firstWhere((s) => s.id == 'c').category, '萌猫');

      await store.removeFromCategory('萌猫', ['c']);
      expect(store.categories, [kAllCategory, kUncategorizedCategory]);
      expect(store.items.every((s) => s.uncategorized), isTrue);
    });

    test('removeFromCategory 对其他分类的成员无影响', () async {
      final store = await seededStore();
      await store.createCategory('萌猫', ['a']);
      await store.createCategory('汪汪', ['b']);
      await store.removeFromCategory('萌猫', ['b']);
      expect(store.items.firstWhere((s) => s.id == 'b').category, '汪汪');
      expect(store.categories,
          containsAll([kAllCategory, kUncategorizedCategory, '萌猫', '汪汪']));
    });

    group('StickerStore.reorderCategory（onReorderItem 语义：newIndex 即最终落位）', () {
      Future<StickerStore> abcStore() async {
        final store = await seededStore();
        await store.createCategory('甲', ['a']);
        await store.createCategory('乙', ['b']);
        await store.createCategory('丙', ['c']);
        return store;
      }

      test('向后拖两格：甲拖到丙后面', () async {
        final store = await abcStore();
        await store.reorderCategory(2, 4);
        expect(store.categories,
            [kAllCategory, kUncategorizedCategory, '乙', '丙', '甲']);
      });

      test('向后拖一格', () async {
        final store = await abcStore();
        await store.reorderCategory(2, 3);
        expect(store.categories,
            [kAllCategory, kUncategorizedCategory, '乙', '甲', '丙']);
      });

      test('向前拖到最前（默认分类也可参与排序）', () async {
        final store = await abcStore();
        await store.reorderCategory(1, 0);
        expect(store.categories,
            [kUncategorizedCategory, kAllCategory, '甲', '乙', '丙']);
      });

      test('原位或越界是安全的空操作', () async {
        final store = await abcStore();
        await store.reorderCategory(0, 0);
        await store.reorderCategory(-1, 0);
        await store.reorderCategory(0, 5);
        expect(store.categories,
            [kAllCategory, kUncategorizedCategory, '甲', '乙', '丙']);
      });

      test('分类顺序持久化，重载后保持', () async {
        final store = await abcStore();
        await store.reorderCategory(2, 4);
        final reloaded = await seededStore();
        expect(reloaded.categories,
            [kAllCategory, kUncategorizedCategory, '乙', '丙', '甲']);
      });
    });
  });
}
