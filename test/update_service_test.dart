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
    test('同号正式版优先于预览版（决胜规则）', () {
      expect(UpdateService.isNewer('1.5.1', '1.5.1-beta'), isTrue);
      expect(UpdateService.isNewer('1.5.1-beta', '1.5.1'), isFalse);
      expect(UpdateService.isNewer('1.5.1-alpha', '1.5.1-beta'), isFalse);
      expect(UpdateService.isNewer('1.5.1-beta', '1.5.0'), isTrue);
    });
    test('预发布标识符按 semver 逐段比较（回归：beta.1 之前被判不更新）', () {
      expect(UpdateService.isNewer('1.5.1-beta.1', '1.5.1-beta'), isTrue);
      expect(UpdateService.isNewer('1.5.1-beta.2', '1.5.1-beta.1'), isTrue);
      expect(UpdateService.isNewer('1.5.1-beta.1', '1.5.1-beta.2'), isFalse);
      expect(UpdateService.isNewer('1.5.1-beta.1', '1.5.1-beta'), isTrue);
      expect(UpdateService.isNewer('1.5.1-rc', '1.5.1-beta.1'), isTrue);
      expect(UpdateService.isNewer('1.5.1-rc', '1.5.1-beta'), isTrue);
      expect(UpdateService.isNewer('1.5.1-beta.1', '1.5.1-rc'), isFalse);
    });
    test('发布阶段排序：alpha < beta < rc（字母标识符按 ASCII）', () {
      expect(UpdateService.isNewer('1.6.0-beta', '1.6.0-alpha'), isTrue);
      expect(UpdateService.isNewer('1.6.0-rc', '1.6.0-beta'), isTrue);
      expect(UpdateService.isNewer('1.6.0', '1.6.0-rc'), isTrue);
      expect(UpdateService.isNewer('1.6.0-alpha', '1.6.0-beta'), isFalse);
      expect(UpdateService.isNewer('1.6.0-rc', '1.6.0'), isFalse);
      expect(UpdateService.isNewer('1.6.0-rc.2', '1.6.0-rc.1'), isTrue);
    });
    test('解析 prerelease 标记', () {
      final pre = UpdateService.parseRelease({
        'tag_name': 'v1.5.0-beta',
        'prerelease': true,
        'body': 'preview',
        'assets': [
          {
            'name': 'app.apk',
            'browser_download_url': 'https://x/app.apk',
          }
        ],
      });
      expect(pre!.prerelease, isTrue);
      expect(pre.version, '1.5.0-beta');

      final stable = UpdateService.parseRelease({
        'tag_name': 'v1.5.0',
        'body': 'stable',
        'assets': [
          {
            'name': 'app.apk',
            'browser_download_url': 'https://x/app.apk',
          }
        ],
      });
      expect(stable!.prerelease, isFalse);
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

    test('Gitee 形状的 release JSON 同样可解析（双源兼容）', () {
      final update = UpdateService.parseRelease({
        'id': 995355,
        'tag_name': 'v1.4.3',
        'target_commitish': '47b7af6',
        'prerelease': false,
        'name': '哈气站 v1.4.3',
        'body': '## 修改\n- 检查更新源切到 Gitee',
        'assets': [
          {
            'name': 'haqi-station-v1.4.3.apk',
            'browser_download_url':
                'https://gitee.com/aether2000/haqi-station/releases/download/v1.4.3/haqi-station-v1.4.3.apk',
          },
        ],
      });
      expect(update, isNotNull);
      expect(update!.version, '1.4.3');
      expect(update.notes, contains('Gitee'));
      expect(update.apkUrl, startsWith('https://gitee.com/'));
    });

    test('Windows 更新匹配 Inno Setup 安装包（回归：v1.8.0 起 portable zip 弃用）', () {
      final update = UpdateService.parseRelease({
        'tag_name': 'v1.8.0',
        'body': '',
        'assets': [
          {
            'name': 'haqi-station-v1.7.6.apk',
            'browser_download_url': 'https://x/haqi-station-v1.7.6.apk',
          },
          {
            'name': 'haqi-station-v1.8.0-windows-setup.exe',
            'browser_download_url':
                'https://x/haqi-station-v1.8.0-windows-setup.exe',
          },
        ],
      });
      expect(update, isNotNull);
      expect(update!.windowsUrl,
          'https://x/haqi-station-v1.8.0-windows-setup.exe');
      expect(update.downloadUrl, update.windowsUrl);
    });

    test('zip 附件不再视为 Windows 更新包（仅剩旧 Release 时回退 APK 直链）', () {
      final update = UpdateService.parseRelease({
        'tag_name': 'v1.8.0',
        'assets': [
          {
            'name': 'haqi-station-v1.8.0.apk',
            'browser_download_url': 'https://x/haqi-station-v1.8.0.apk',
          },
          {
            'name': 'haqi-station-windows.zip',
            'browser_download_url': 'https://x/haqi-station-windows.zip',
          },
        ],
      });
      expect(update, isNotNull);
      expect(update!.windowsUrl, isNull);
      expect(update.downloadUrl, 'https://x/haqi-station-v1.8.0.apk');
    });
  });
}
