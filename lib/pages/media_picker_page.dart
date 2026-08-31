import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/l10n.dart';

import '../services/media_store.dart';

/// 应用内建内容查看器：按相册浏览媒体库中的照片与视频并多选，
/// 返回所选内容的 content:// URI 列表（取消返回 null，视频不可选）。
Future<List<String>?> showMediaPicker(BuildContext context) {
  return Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const MediaPickerPage(),
    ),
  );
}

class MediaPickerPage extends StatefulWidget {
  const MediaPickerPage({super.key});

  @override
  State<MediaPickerPage> createState() => _MediaPickerPageState();
}

class _MediaPickerPageState extends State<MediaPickerPage> {
  bool _loading = true;
  bool _denied = false;
  List<MediaItem> _items = const [];
  String? _activeBucket; // null = 全部相册
  final Set<String> _selectedUris = {};

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    final granted = await _ensurePermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }
    final items = await MediaStoreService.queryMedia();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// Android 13+ 走细分媒体权限，12 及以下看存储权限，任一授权即可。
  Future<bool> _ensurePermission() async {
    if (await Permission.photos.isGranted ||
        await Permission.videos.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }
    final results = await [
      Permission.photos,
      Permission.videos,
      Permission.storage,
    ].request();
    return results.values.any((status) => status.isGranted);
  }

  List<MediaItem> get _visibleItems {
    final bucket = _activeBucket;
    if (bucket == null) return _items;
    return [for (final item in _items) if (item.bucket == bucket) item];
  }

  Map<String, int> get _bucketCounts {
    final counts = <String, int>{};
    for (final item in _items) {
      counts[item.bucket] = (counts[item.bucket] ?? 0) + 1;
    }
    return counts;
  }

  void _toggleSelection(MediaItem item) {
    if (item.isVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('videoNotSupported'))));
      return;
    }
    setState(() {
      if (!_selectedUris.add(item.uri)) _selectedUris.remove(item.uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedUris.isEmpty
                ? t('pickImages')
                : t('selectedCount', {'n': _selectedUris.length}),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: t('systemFiles'),
              icon: const Icon(Icons.folder_outlined),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final paths = await MediaStoreService.pickFilesSystem();
                if (!mounted || paths.isEmpty) return;
                navigator.pop(paths);
              },
            ),
            if (_selectedUris.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final paths = await MediaStoreService.resolveMediaPaths(
                      _selectedUris.toList());
                  if (!mounted) return;
                  navigator.pop(paths);
                },
                child: Text(t('import')),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: _buildBody(colors),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 88, color: colors.outlineVariant),
              const SizedBox(height: 16),
              Text(t('mediaPermissionTitle'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(t('mediaPermissionDesc'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_rounded),
                label: Text(t('goGrant')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _prepare,
                child: Text(t('retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(t('mediaEmpty'), style: Theme.of(context).textTheme.titleMedium),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              _bucketChip(label: t('all'), value: null),
              for (final entry in _bucketCounts.entries)
                _bucketChip(
                  label: '${entry.key} (${entry.value})',
                  value: entry.key,
                ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _visibleItems.length,
            itemBuilder: (context, index) =>
                _mediaTile(_visibleItems[index]),
          ),
        ),
      ],
    );
  }

  Widget _bucketChip({required String label, required String? value}) {
    final selected = _activeBucket == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (selected) {
          if (selected) setState(() => _activeBucket = value);
        },
      ),
    );
  }

  Widget _mediaTile(MediaItem item) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selectedUris.contains(item.uri);
    final hasThumb = item.path.isNotEmpty && !item.isVideo;
    return GestureDetector(
      onTap: () => _toggleSelection(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasThumb)
            Image.file(
              File(item.path),
              fit: BoxFit.cover,
              cacheWidth: 240,
              errorBuilder: (_, _, _) => Container(color: colors.surfaceContainerHigh),
            )
          else
            Container(
              color: colors.surfaceContainerHigh,
              child: Icon(
                item.isVideo ? Icons.videocam_rounded : Icons.broken_image_outlined,
                color: colors.onSurfaceVariant,
              ),
            ),
          if (item.isVideo)
            Container(color: Colors.black38),
          if (item.isVideo)
            Center(
              child: Icon(Icons.play_arrow_rounded,
                  size: 36, color: colors.onSurface),
            ),
          // 选中遮罩
          Container(
            decoration: BoxDecoration(
              border: selected ? Border.all(color: colors.primary, width: 3) : null,
            ),
          ),
          if (selected)
            Container(
              color: colors.primary.withValues(alpha: 0.25),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.check_circle_rounded,
                      size: 22, color: colors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
