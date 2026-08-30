import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于：应用信息、版本与 GitHub 仓库链接。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _repoUrl = 'https://github.com/aether1917/Haqi-Station';

  Future<void> _openRepo(BuildContext context) async {
    final uri = Uri.parse(_repoUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('无法打开链接：$_repoUrl')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/app_icon.jpg',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Text('哈气站', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Haqi Station v1.3.2',
                  style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 16),
              Text(
                '一个简洁的 Android 表情包管理应用。\n导入图片与 GIF，拖拽排序，一键分享快乐。',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('GitHub 仓库'),
                  subtitle: Text('aether1917/Haqi-Station', style: const TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.open_in_new_rounded, color: colors.onSurfaceVariant),
                  onTap: () => _openRepo(context),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '使用 Flutter 与 Material Design 3 构建',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
