import 'package:flutter_test/flutter_test.dart';
import 'package:haqi_station/services/update_service.dart';

void main() {
  group('UpdateService.isNewer（语义化版本三段比较）', () {
    test('高一位补丁版本算更新', () {
      expect(UpdateService.isNewer('1.3.2', '1.3.1'), isTrue);
    });
    test('次版本/主版本跨级比较正确', () {
      expect(UpdateService.isNewer('1.4.0', '1.3.9'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
    });
    test('按数字而不是字符串比较（避免 1.10 < 1.9 的坑）', () {
      expect(UpdateService.isNewer('1.10.0', '1.9.0'), isTrue);
      expect(UpdateService.isNewer('1.9.0', '1.10.0'), isFalse);
    });
    test('相同或更旧不算更新', () {
      expect(UpdateService.isNewer('1.3.2', '1.3.2'), isFalse);
      expect(UpdateService.isNewer('1.3.1', '1.3.2'), isFalse);
    });
    test('容忍 v 前缀与 pre-release 后缀', () {
      expect(UpdateService.isNewer('v1.4.0', '1.3.2'), isTrue);
      expect(UpdateService.isNewer('1.4.0-beta', '1.3.2'), isTrue);
      expect(UpdateService.isNewer('v1.4.0-beta', 'v1.3.2'), isTrue);
    });
    test('缺段按 0 补齐', () {
      expect(UpdateService.isNewer('1.4', '1.3.2'), isTrue);
      expect(UpdateService.isNewer('1', '1.3.2'), isFalse);
    });
  });

  group('UpdateService.parseRelease（GitHub release JSON）', () {
    test('解析 tag、notes 与 APK 直链', () {
      final update = UpdateService.parseRelease({
        'tag_name': 'v1.4.0',
        'body': '## 新增\n- 检查更新',
        'assets': [
          {
            'name': 'haqi-station-v1.4.0.apk',
            'browser_download_url':
                'https://github.com/aether1917/Haqi-Station/releases/download/v1.4.0/haqi-station-v1.4.0.apk',
          },
          {
            'name': 'Source code (zip)',
            'browser_download_url': 'https://github.com/a/zip',
          },
        ],
      });
      expect(update, isNotNull);
      expect(update!.version, '1.4.0');
      expect(update.notes, contains('检查更新'));
      expect(update.apkUrl, endsWith('.apk'));
    });

    test('缺 tag 或 APK 资产时返回 null', () {
      expect(UpdateService.parseRelease({'tag_name': 'v1.4.0', 'assets': []}),
          isNull);
      expect(
          UpdateService.parseRelease({
            'tag_name': '',
            'assets': [
              {
                'name': 'x.apk',
                'browser_download_url': 'https://x/y.apk',
              }
            ],
          }),
          isNull);
    });
  });
}
