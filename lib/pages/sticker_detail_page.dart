import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/sticker_store.dart';

/// 表情包二级页面：大图预览 + 分享按钮。
class StickerDetailPage extends StatelessWidget {
  const StickerDetailPage({
    super.key,
    required this.store,
    required this.sticker,
  });

  final StickerStore store;
  final Sticker sticker;

  String get _dateLabel {
    final d = DateTime.fromMillisecondsSinceEpoch(sticker.addedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _share(BuildContext context) async {
    final file = File(store.pathOf(sticker));
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('文件不存在，无法分享')));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '${sticker.name} · 来自哈气站'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final file = File(store.pathOf(sticker));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sticker.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Hero(
                  tag: sticker.id,
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      size: 96,
                      color: colors.outline,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  sticker.isGif
                      ? Icons.animation_rounded
                      : Icons.image_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${sticker.isGif ? "GIF 动图" : "图片"} · 添加于 $_dateLabel',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 16 + MediaQuery.paddingOf(context).bottom),
            child: FilledButton.icon(
              onPressed: () => _share(context),
              icon: const Icon(Icons.share_rounded),
              label: const Text('分享'),
            ),
          ),
        ],
      ),
    );
  }
}
