import 'package:flutter/material.dart';

/// 捐赠页：上方二维码，下方一句感谢语。
class DonationPage extends StatelessWidget {
  const DonationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('捐赠', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 二维码：白色圆角容器包裹，适配不同屏幕宽度。
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/donation/qr_code.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      height: 200,
                      alignment: Alignment.center,
                      color: colors.surfaceContainerHigh,
                      child: Icon(Icons.qr_code_2_rounded,
                          size: 64, color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '如果这个软件帮到你了，\n就请我喝杯奶茶吧~\n谢谢你！(´▽`ʃ♡)ƪ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.8,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
