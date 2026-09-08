import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqi_station/services/media_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaStoreService.resolveMediaPaths', () {
    test('只把 content:// URI 交给原生解析（回归：文件路径二次解析）', () async {
      final calls = <Map<dynamic, dynamic>>[];
      const channel = MethodChannel('com.haqi.station/share');
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.arguments as Map<dynamic, dynamic>);
        return <String>['/cache/resolved.jpg'];
      });

      // 文件路径（无 scheme）不应触发原生调用，也不应报错。
      final fromPaths = await MediaStoreService.resolveMediaPaths(
          ['/data/user/0/com.haqi.station/cache/shared_import/a.jpg']);
      expect(fromPaths, isEmpty);
      expect(calls, isEmpty);

      // 真正的 content:// 才会走原生解析。
      final fromUris = await MediaStoreService.resolveMediaPaths(
          ['content://media/external/images/media/123']);
      expect(fromUris, ['/cache/resolved.jpg']);
      expect(calls, hasLength(1));
      expect(calls.first['uris'], ['content://media/external/images/media/123']);
    });
  });
}
