// 从源图生成 Android 启动图标（源图 = 用户提供并复制到 assets/icon/app_icon.jpg 的 app.ico）。
// 策略：全出血 —— 自适应图标的前景/背景两层都铺满整张源图，图标在任何蒙版下
// 都由图片填满，不再有黑边或留白。
// 运行：dart run tool/gen_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const resDir = 'android/app/src/main/res';

/// 自适应图标图层位图边长（108dp 对应各密度）。
const foregroundSizes = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

/// 旧式图标位图边长（48dp 对应各密度）。
const legacySizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

void main() {
  final sourcePath = 'assets/icon/app_icon.jpg';
  final bytes = File(sourcePath).readAsBytesSync();
  final source = img.decodeJpg(bytes);
  if (source == null) {
    stderr.writeln('无法解码 $sourcePath');
    exit(1);
  }

  // 旧版黑边根因：在 3 通道（无 Alpha）画布上"留白居中"，透明区被压成黑色。
  // 现改为全出血 —— 源图直接缩放到整个图层，不存在任何透明区。
  final fullBleed = img.copyResize(
    source,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );

  File('assets/icon/app_icon_fg.png')
      .writeAsBytesSync(img.encodePng(fullBleed));
  stdout.writeln('已生成 assets/icon/app_icon_fg.png（1024x1024 全出血 RGBA）');

  for (final entry in foregroundSizes.entries) {
    final image = img.copyResize(source,
        width: entry.value, height: entry.value);
    _write(
      '$resDir/drawable-${entry.key}/ic_launcher_foreground.png',
      image,
    );
    _write(
      '$resDir/drawable-${entry.key}/ic_launcher_background.png',
      image,
    );
  }
  for (final entry in legacySizes.entries) {
    final image = img.copyResize(source,
        width: entry.value, height: entry.value);
    _write('$resDir/mipmap-${entry.key}/ic_launcher.png', image);
  }
  stdout.writeln('已重新生成 drawable-* 双层图层与 mipmap-* 旧式图标');
}

void _write(String path, img.Image image) {
  final file = File(path);
  file.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('已生成 $path（${image.width}x${image.height}）');
}
