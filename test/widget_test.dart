import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqi_station/services/sticker_store.dart';

void main() {
  group('Sticker 序列化', () {
    test('toJson / fromJson 往返一致', () {
      final sticker = Sticker(
        id: '1724900000000_abc123',
        name: '开心猫',
        ext: 'gif',
        addedAt: 1724900000000,
        category: '萌猫',
      );

      final restored = Sticker.fromJson(
          jsonDecode(jsonEncode(sticker.toJson())) as Map<String, dynamic>);

      expect(restored.id, sticker.id);
      expect(restored.name, sticker.name);
      expect(restored.ext, sticker.ext);
      expect(restored.addedAt, sticker.addedAt);
      expect(restored.category, '萌猫');
      expect(restored.fileName, '1724900000000_abc123.gif');
    });

    test('未分类序列化不写入 category 键，读取时为 null', () {
      final sticker = Sticker(id: 'a', name: 'a', ext: 'png', addedAt: 0);
      expect(sticker.uncategorized, isTrue);
      expect(sticker.toJson().containsKey('category'), isFalse);
      final restored = Sticker.fromJson(sticker.toJson());
      expect(restored.category, isNull);
    });

    test('isGif 由扩展名判断', () {
      expect(
        Sticker(id: 'a', name: 'a', ext: 'gif', addedAt: 0).isGif,
        isTrue,
      );
      expect(
        Sticker(id: 'b', name: 'b', ext: 'png', addedAt: 0).isGif,
        isFalse,
      );
    });
  });

  group('允许的扩展名', () {
    test('包含常见图片与 GIF 格式', () {
      expect(kAllowedExtensions, containsAll(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']));
      expect(kAllowedExtensions.contains('mp4'), isFalse);
    });
  });
}
