import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../services/sticker_store.dart';
import '../widgets/sticker_tile.dart';
import 'sticker_detail_page.dart';

/// 表情包一级界面：网格展示、拖拽排序、多选删除、导入。
class StickersPage extends StatefulWidget {
  const StickersPage({super.key});

  @override
  State<StickersPage> createState() => _StickersPageState();
}

class _StickersPageState extends State<StickersPage> {
  final StickerStore _store = StickerStore();
  final Set<String> _selectedIds = {};
  bool _selectMode = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelectMode([String? firstId]) {
    setState(() {
      _selectMode = true;
      if (firstId != null) _selectedIds.add(firstId);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      if (!mounted) return;
      final paths = [
        for (final f in picked)
          if (f.path != null) f.path!,
      ];
      if (paths.isEmpty) return;
      final count = await _store.importFiles(paths);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? '已导入 $count 个表情包' : '没有可导入的图片（支持 jpg/png/gif/webp/bmp）'),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除表情包'),
        content: Text('确定删除选中的 $count 个表情包吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteMany(_selectedIds);
    _exitSelectMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除 $count 个表情包')));
  }

  void _openDetail(Sticker sticker) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StickerDetailPage(store: _store, sticker: sticker),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 多选模式下拦截系统返回键：先退出多选而不是退出应用。
    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectMode();
      },
      child: Scaffold(
        appBar: _selectMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
        body: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            if (!_store.loaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_store.items.isEmpty) return _buildEmptyState();
            return _buildGrid();
          },
        ),
        floatingActionButton: _selectMode
            ? null
            : FloatingActionButton.extended(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_rounded),
                label: const Text('导入'),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: const Text('哈气站', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          tooltip: '选择',
          icon: const Icon(Icons.checklist_rounded),
          onPressed: () => _enterSelectMode(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      leading: IconButton(
        tooltip: '退出选择',
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelectMode,
      ),
      title: Text('已选 ${_selectedIds.length} 项',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: colors.surfaceContainerLow,
      actions: [
        IconButton(
          tooltip: _selectedIds.length == _store.count ? '取消全选' : '全选',
          icon: Icon(_selectedIds.length == _store.count
              ? Icons.deselect_rounded
              : Icons.select_all_rounded),
          onPressed: () => setState(() {
            if (_selectedIds.length == _store.count) {
              _selectedIds.clear();
            } else {
              _selectedIds
                ..clear()
                ..addAll(_store.items.map((s) => s.id));
            }
          }),
        ),
        IconButton(
          tooltip: '删除',
          icon: Icon(Icons.delete_outline_rounded, color: colors.error),
          onPressed:
              _selectedIds.isEmpty ? null : () => _deleteSelected(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildGrid() {
    final stickers = _store.items;
    return ReorderableGridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 96),
      childAspectRatio: 1,
      dragEnabled: true,
      onReorder: (oldIndex, newIndex) {
        _store.reorder(oldIndex, newIndex);
        setState(() {});
      },
      children: [
        for (final sticker in stickers)
          StickerTile(
            key: ValueKey(sticker.id),
            store: _store,
            sticker: sticker,
            selectMode: _selectMode,
            selected: _selectedIds.contains(sticker.id),
            onTap: () =>
                _selectMode ? _toggleSelect(sticker.id) : _openDetail(sticker),
            // 普通模式下长按交给拖拽排序；多选模式里长按等同点按切换选中。
            onLongPress:
                _selectMode ? () => _toggleSelect(sticker.id) : null,
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.collections_rounded, size: 88, color: colors.outlineVariant),
          const SizedBox(height: 16),
          Text('还没有表情包', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '点击右下角「导入」添加图片或 GIF',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
