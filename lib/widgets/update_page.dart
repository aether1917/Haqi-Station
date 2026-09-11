import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/update_download_service.dart';
import '../services/update_service.dart';

/// 全屏「发现新版本」页：展示 Release Notes，右上角 × 可关闭。
/// Android 底部按钮跳浏览器下载 APK；Windows 为内建下载器（页面显示
/// 实时进度，完成后静默调起安装器并自动重启应用）。
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
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final update = widget.update;

    return PopScope(
      // Windows：关闭页面后下载继续（完成后自动调起安装器），
      // 不阻挡返回；Android 保持下载中锁定返回（转后台需确认）。
      canPop: Platform.isWindows ||
          UpdateDownloadService.instance.phase !=
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
              child: ListenableBuilder(
                listenable: UpdateDownloadService.instance,
                builder: (context, _) {
                  final dl = UpdateDownloadService.instance;
                  final phase = dl.phase;
                  if (!Platform.isWindows) {
                    // Android 保持跳浏览器下载 APK。
                    return FilledButton.icon(
                      onPressed: () => UpdateService.downloadApk(update.apkUrl),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(t('download')),
                    );
                  }
                  if (phase == UpdateDownloadPhase.idle ||
                      phase == UpdateDownloadPhase.failed) {
                    final failed = phase == UpdateDownloadPhase.failed;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (failed) ...[
                          Text(t('updateDownloadFail'),
                              textAlign: TextAlign.center,
                              style: text.bodySmall
                                  ?.copyWith(color: colors.error)),
                          const SizedBox(height: 8),
                        ],
                        FilledButton.icon(
                          onPressed: () =>
                              UpdateDownloadService.instance.start(update),
                          icon: const Icon(Icons.download_rounded),
                          label: Text(failed ? t('retryDownload') : t('download')),
                        ),
                      ],
                    );
                  }
                  if (phase == UpdateDownloadPhase.downloading) {
                    final pct =
                        dl.progress >= 0 ? (dl.progress * 100).round() : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(value: dl.progress < 0 ? null : dl.progress),
                        if (pct != null) ...[
                          const SizedBox(height: 8),
                          Text('${dl.received}'
                              '${dl.totalSize.isNotEmpty ? ' / ${dl.totalSize}' : ''}'
                              '（$pct%）',
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontFeatures: const [FontFeature.tabularFigures()])),
                        ],
                      ],
                    );
                  }
                  // done：安装器已在启动中，应用即将自动重启。
                  return Text(t('updateWindowsHint'),
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant, height: 1.5));
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
