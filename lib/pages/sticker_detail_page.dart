import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/native_share.dart';
import '../services/sticker_store.dart';

/// 表情包二级页面：大图预览 + 重命名 + 分享按钮。
class StickerDetailPage extends StatefulWidget {
  const StickerDetailPage({
    super.key,
    required this.store,
    required this.sticker,
  });

  final StickerStore store;
  final Sticker sticker;

  @override
  State<StickerDetailPage> createState() => _StickerDetailPageState();
}

class _StickerDetailPageState extends State<StickerDetailPage> {
  Sticker get sticker => widget.sticker;
  StickerStore get store => widget.store;

  String get _dateLabel {
    final d = DateTime.fromMillisecondsSinceEpoch(sticker.addedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _share(BuildContext context) async {
    final ok = await NativeShare.shareFiles(
      [File(store.pathOf(sticker))],
      names: [sticker.name],
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('noFileShare'))));
    }
  }

  /// 重命名表情包（展示名；分享时文件名同步使用）。
  Future<void> _renameSticker() async {
    final controller = TextEditingController(text: sticker.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('renameSticker')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(labelText: t('stickerName')),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(t('confirm')),
          ),
        ],
      ),
    );
    if (name == null) return;
    final ok = await store.renameSticker(sticker, name);
    if (!mounted) return;
    if (ok) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? t('stickerRenamed') : t('invalidName')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final file = File(store.pathOf(sticker));

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _renameSticker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  sticker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded,
                  size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
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
