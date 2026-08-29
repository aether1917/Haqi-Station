import 'dart:io';

import 'package:flutter/material.dart';

import '../services/sticker_store.dart';

/// 网格单元：图片缩略图（GIF 自动播放动画）+ 选择态遮罩。
class StickerTile extends StatelessWidget {
  const StickerTile({
    super.key,
    required this.store,
    required this.sticker,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final StickerStore store;
  final Sticker sticker;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;

  /// 普通模式下留空，避免与拖拽排序的长按手势冲突。
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final file = File(store.pathOf(sticker));

    Widget image = Image.file(
      file,
      fit: BoxFit.cover,
      // 非 GIF 缩略图降采样解码，降低网格内存占用；GIF 需要逐帧动画不做降采样。
      cacheWidth: sticker.isGif ? null : 400,
      errorBuilder: (_, _, _) => Container(
        color: colors.surfaceContainerHigh,
        child: Icon(Icons.broken_image_outlined, color: colors.outline),
      ),
    );

    if (selectMode) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          Container(
            color: selected
                ? colors.primary.withValues(alpha: 0.30)
                : Colors.black26,
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 24,
                color: selected ? colors.onPrimary : Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectMode && selected ? colors.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (sticker.isGif)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
