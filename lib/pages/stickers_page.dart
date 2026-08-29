import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../services/sticker_store.dart';
import '../widgets/sticker_tile.dart';
import 'sticker_detail_page.dart';

/// 表情包一级界面：分类栏过滤、网格展示、拖拽排序、多选删除、导入、
/// 多选创建分类。
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

  /// 当前过滤的分类：null = 全部；空串 = 未分类；其他 = 分类名。
  String? _activeCategory;

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

  /// 按分类栏过滤后的可见表情包。
  List<Sticker> get _visibleItems {
    final active = _activeCategory;
    if (active == null) return _store.items;
    if (active.isEmpty) {
      return [for (final s in _store.items) if (s.uncategorized) s];
    }
    return [for (final s in _store.items) if (s.category == active) s];
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

  /// 多选创建分类：弹窗内可修改分类名称，确认后把选中项归入该分类。
  Future<void> _createCategory() async {
    final controller = TextEditingController(text: '新分类');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '分类名称',
            hintText: '给这个分类起个名字',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final isNew = !_store.categories.contains(trimmed);
    final count = _selectedIds.length;
    await _store.createCategory(trimmed, _selectedIds);
    _exitSelectMode();
    if (!mounted) return;
    setState(() => _activeCategory = trimmed);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isNew
          ? '已创建分类「$trimmed」，含 $count 个表情包'
          : '已把 $count 个表情包归入「$trimmed」'),
    ));
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
        appBar: _selectMode
            ? _buildSelectionAppBar()
            : _buildNormalAppBar(),
        body: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            if (!_store.loaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final visible = _visibleItems;
            if (visible.isEmpty) {
              return _buildEmptyState(storeEmpty: _store.items.isEmpty);
            }
            return _buildGrid(visible);
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
      bottom: _buildCategoryBar(),
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
          tooltip: '创建分类',
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: _selectedIds.isEmpty ? null : _createCategory,
        ),
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
      bottom: _buildCategoryBar(),
    );
  }

  /// 标题栏下方的分类栏：全部 / 未分类 / 自定义分类。
  PreferredSizeWidget _buildCategoryBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        height: 56,
        alignment: Alignment.centerLeft,
        color: Theme.of(context).appBarTheme.backgroundColor,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) => Row(
              children: [
                _categoryChip(label: '全部', value: null),
                _categoryChip(label: '未分类', value: ''),
                for (final c in _store.categories) _categoryChip(label: c, value: c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip({required String label, required String? value}) {
    final selected = _activeCategory == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (selected) {
          if (selected) setState(() => _activeCategory = value);
        },
      ),
    );
  }

  Widget _buildGrid(List<Sticker> visible) {
    return ReorderableGridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 96),
      childAspectRatio: 1,
      dragEnabled: true,
      onReorder: (oldIndex, newIndex) => _reorder(oldIndex, newIndex, visible),
      children: [
        for (final sticker in visible)
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

  /// 过滤态下网格索引与全量列表不一致，换算成全量索引后再排序。
  void _reorder(int oldIndex, int newIndex, List<Sticker> visible) {
    if (_activeCategory == null) {
      _store.reorder(oldIndex, newIndex);
      return;
    }
    final full = _store.items;
    final fullOld = full.indexOf(visible[oldIndex]);
    final fullNew = full.indexOf(visible[newIndex]);
    if (fullOld >= 0 && fullNew >= 0) {
      _store.reorder(fullOld, fullNew);
    }
  }

  Widget _buildEmptyState({required bool storeEmpty}) {
    final colors = Theme.of(context).colorScheme;
    final filtering = !storeEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.collections_rounded, size: 88, color: colors.outlineVariant),
          const SizedBox(height: 16),
          Text(
            filtering ? '该分类下还没有表情包' : '还没有表情包',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            filtering ? '长按表情包可在多选里归入分类' : '点击右下角「导入」添加图片或 GIF',
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
