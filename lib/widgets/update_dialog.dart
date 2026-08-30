import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// 「发现新版本」弹窗：展示 Release Notes，跳浏览器下载 APK。
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) {
  final colors = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('发现新版本 v${update.version}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            update.notes.trim().isEmpty ? '体验优化与问题修复。' : update.notes,
            style: TextStyle(height: 1.5, color: colors.onSurfaceVariant),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('以后再说'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            UpdateService.downloadApk(update.apkUrl);
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text('下载更新'),
        ),
      ],
    ),
  );
}
