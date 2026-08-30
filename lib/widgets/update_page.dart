import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// 全屏「发现新版本」页：展示 Release Notes，右上角 × 可关闭，
/// 底部一键跳浏览器下载 APK。启动静默检查与关于页手动检查共用。
Future<void> showUpdatePage(BuildContext context, AppUpdate update) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => UpdatePage(update: update),
  ));
}

class UpdatePage extends StatelessWidget {
  const UpdatePage({super.key, required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 右上角关闭按钮独占一行，避免与内容重叠。
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.rocket_launch_rounded,
                        size: 56, color: colors.primary),
                    const SizedBox(height: 16),
                    Text('发现新版本', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('v${update.version}',
                            style: text.titleMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                        if (update.prerelease) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('预览版',
                                style: text.labelSmall?.copyWith(
                                    color: colors.onSecondaryContainer)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, color: colors.outlineVariant),
                    const SizedBox(height: 20),
                    Text(
                      update.notes.trim().isEmpty ? '体验优化与问题修复。' : update.notes,
                      style: text.bodyMedium
                          ?.copyWith(height: 1.6, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: FilledButton.icon(
                onPressed: () => UpdateService.downloadApk(update.apkUrl),
                icon: const Icon(Icons.download_rounded),
                label: const Text('下载更新'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
