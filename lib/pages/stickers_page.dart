import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../services/native_share.dart';
import '../services/sticker_store.dart';
import '../widgets/sticker_tile.dart';
import 'media_picker_page.dart';
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
    _store.addListener(_ensureValidFilter);
    _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_ensureValidFilter);
    _store.dispose();
    super.dispose();
  }

  /// 分类被删除或清空后，把失效的过滤器回退到「全部」。
  void _ensureValidFilter() {
    final active = _activeCategory;
    if (active == null || active.isEmpty) return;
    if (!_store.categories.contains(active) && mounted) {
      setState(() => _activeCategory = null);
    }
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

  /// 导入：直达应用内建内容查看器（相册）；「从文件选择」在查看器内。
  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final paths = await showMediaPicker(context);
      if (!mounted || paths == null || paths.isEmpty) return;
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
              // 覆盖主题里的整行宽度最小尺寸，让删除与取消同排。
              minimumSize: const Size(72, 40),
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

  /// 多选快速分享：把选中的表情包文件一次性分享出去。
  Future<void> _shareSelected() async {
    final ok = await NativeShare.shareFiles([
      for (final s in _store.items)
        if (_selectedIds.contains(s.id)) File(_store.pathOf(s)),
    ]);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('文件不存在，无法分享')));
    }
  }

  /// 多选分类二级菜单：把选中项归入/移出现有分类，或新建分类。
  /// 操作后菜单保持打开，方便连续操作多个分类。
  Future<void> _showCategorySheet() async {
    final ids = _selectedIds.toSet();
    if (ids.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final categories = _store.categories;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '分类（已选 ${ids.length} 项）',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (categories.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '还没有分类，点下方「新建分类」创建',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                for (final c in categories) _sheetCategoryTile(sheetContext, c, ids),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('新建分类'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _createCategory();
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sheetCategoryTile(
      BuildContext sheetContext, String category, Set<String> ids) {
    final colors = Theme.of(context).colorScheme;
    final selectedInCategory = [
      for (final s in _store.items)
        if (ids.contains(s.id) && s.category == category) s.id,
    ];
    return ListTile(
      leading: const Icon(Icons.label_outline_rounded),
      title: Text(category),
      subtitle: selectedInCategory.isEmpty
          ? null
          : Text('已选 ${selectedInCategory.length} 项在该分类'),
      trailing: selectedInCategory.isEmpty
          ? null
          : IconButton(
              tooltip: '把所选移出该分类',
              icon: Icon(Icons.remove_circle_outline_rounded,
                  color: colors.error),
              onPressed: () async {
                final navigator = Navigator.of(sheetContext);
                final count = selectedInCategory.length;
                await _store.removeFromCategory(category, selectedInCategory);
                if (!mounted) return;
                // 操作完成后收起菜单并取消选择。
                navigator.pop();
                _exitSelectMode();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('已从「$category」移出 $count 个表情包')));
              },
            ),
      onTap: () async {
        // 归入完成后收起菜单并取消选择。
        final navigator = Navigator.of(sheetContext);
        await _store.assignCategory(category, ids);
        if (!mounted) return;
        navigator.pop();
        _exitSelectMode();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已把 ${ids.length} 个表情包归入「$category」')));
      },
    );
  }

  /// 新建分类：弹窗内可修改分类名称，确认后把选中项归入该分类。
  Future<void> _createCategory() async {
    final controller = TextEditingController(text: '新分类');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建分类'),
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
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
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
    if (!mounted) return;
    // 创建完成同样取消选择，保持与其他分类操作一致。
    _exitSelectMode();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isNew
          ? '已创建分类「$trimmed」，含 $count 个表情包'
          : '已把 $count 个表情包归入「$trimmed」'),
    ));
  }

  /// 长按分类胶囊删除分类：其下表情包变为未分类。
  Future<void> _confirmDeleteCategory(String name) async {
    final count = _store.items.where((s) => s.category == name).length;
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('删除分类「$name」？其中 $count 个表情包将变为未分类。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              minimumSize: const Size(72, 40),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteCategory(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除分类「$name」')));
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
          tooltip: '分类',
          icon: const Icon(Icons.label_outline_rounded),
          onPressed: _selectedIds.isEmpty ? null : _showCategorySheet,
        ),
        IconButton(
          tooltip: '分享',
          icon: const Icon(Icons.share_rounded),
          onPressed: _selectedIds.isEmpty ? null : _shareSelected,
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

  /// 标题栏下方的分类栏：全部 / 未分类 固定在前，
  /// 自定义分类支持长按拖拽排序（× 删除）。
  PreferredSizeWidget _buildCategoryBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        height: 56,
        alignment: Alignment.centerLeft,
        color: Theme.of(context).appBarTheme.backgroundColor,
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final categories = _store.categories;
            return Row(
              children: [
                const SizedBox(width: 12),
                _categoryChip(label: '全部', value: null),
                _categoryChip(label: '未分类', value: ''),
                Expanded(
                  child: categories.isEmpty
                      ? const SizedBox.shrink()
                      : ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          buildDefaultDragHandles: true,
                          itemCount: categories.length,
                          onReorderItem: (oldIndex, newIndex) =>
                              _store.reorderCategory(oldIndex, newIndex),
                          // 不加 elevation：拖拽时分类标签下方不出现阴影。
                          proxyDecorator: (child, index, animation) => child,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return Padding(
                              key: ValueKey(category),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(category),
                                selected: _activeCategory == category,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(
                                        () => _activeCategory = category);
                                  }
                                },
                                onDeleted: () =>
                                    _confirmDeleteCategory(category),
                                deleteIconColor:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(width: 12),
              ],
            );
          },
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
