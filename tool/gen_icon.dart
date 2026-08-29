// 生成自适应图标前景：把 348x348 的 JPEG 源图缩放并居中放到
// 1024x1024 透明画布上（四周留白约 1/3），避免被系统圆形蒙版裁掉。
// 运行：dart run tool/gen_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final sourcePath = 'assets/icon/app_icon.jpg';
  final outputPath = 'assets/icon/app_icon_fg.png';

  final bytes = File(sourcePath).readAsBytesSync();
  final source = img.decodeJpg(bytes);
  if (source == null) {
    stderr.writeln('无法解码 $sourcePath');
    exit(1);
  }

  final canvas = img.Image(width: 1024, height: 1024); // 透明背景
  final scaled = img.copyResize(source, width: 680);
  final dx = (1024 - scaled.width) ~/ 2;
  final dy = (1024 - scaled.height) ~/ 2;
  img.compositeImage(canvas, scaled, dstX: dx, dstY: dy);

  File(outputPath).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('已生成 $outputPath（${scaled.width}x${scaled.height} 居中）');
}
