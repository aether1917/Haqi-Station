import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/settings_service.dart';
import '../services/update_download_service.dart';
import '../services/update_service.dart';

import '../l10n/l10n.dart';
import '../services/update_service.dart';

/// 全屏「发现新版本」页：展示 Release Notes，右上角 × 可关闭，
/// 底部为内建下载器（页面显示进度；关闭页面后转后台并以通知展示进度）。
Future<void> showUpdatePage(BuildContext context, AppUpdate update) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => UpdatePage(update: update),
  ));
}

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.update});

  final AppUpdate update;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final update = widget.update;

    return PopScope(
      canPop: UpdateDownloadService.instance.phase !=
          UpdateDownloadPhase.downloading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          UpdateDownloadService.instance.onPageClosed();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('downloadInBackground'))));
        }
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 右上角关闭按钮独占一行，避免与内容重叠。
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: t('close'),
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  final dl = UpdateDownloadService.instance;
                  final downloading = dl.phase == UpdateDownloadPhase.downloading;
                  Navigator.pop(context);
                  if (downloading) {
                    dl.onPageClosed();
                  }
                },
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
                    Text(t('updateFound'), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                            child: Text(t('previewBadge'),
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
    ),
    );
  }
}
