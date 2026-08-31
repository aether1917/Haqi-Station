import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../l10n/l10n.dart';

import '../services/native_share.dart';
import '../services/sticker_store.dart';
import '../widgets/sticker_tile.dart';
import 'category_manage_page.dart';
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
  /// 当前过滤的分类：null = 不过滤（全部）；「未分类」为其自身。
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

  /// 分类被删除/重命名后，把失效的过滤器回退到「全部」。
  void _ensureValidFilter() {
    final active = _activeCategory;
    if (active == null) return;
    if (!_store.categories.contains(active) && mounted) {
      setState(() => _activeCategory = null);
    }
  }

  /// 按分类栏过滤后的可见表情包。
  List<Sticker> get _visibleItems {
    final active = _activeCategory;
    // 「全部」与未选择时都显示所有表情包。
    if (active == null || active == kAllCategory) return _store.items;
    if (active == kUncategorizedCategory) {
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
          content: Text(count > 0 ? t('imported', {'count': count}) : t('importNone')),
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
        title: Text(t('delete')),
        content: Text(t('deleteStickersConfirm', {'count': count})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              // 覆盖主题里的整行宽度最小尺寸，让删除与取消同排。
              minimumSize: const Size(72, 40),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteMany(_selectedIds);
    _exitSelectMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('deleted', {'count': count}))));
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
          .showSnackBar(SnackBar(content: Text(t('noFileShare'))));
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
                      '${t('category')}（${t('selectedCount', {'n': ids.length})}）',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // 分类多时可滚动，避免内容溢出无法操作（修复无法滚动 bug）。
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (categories.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t('noCategoriesHint'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                              ),
                            ),
                          ),
                        for (final c in categories)
                          _sheetCategoryTile(sheetContext, c, ids),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: Text(t('createCategory')),
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
                    content: Text(t('removed', {'name': category, 'n': count}))));
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
            SnackBar(content: Text(t('assigned', {'name': category, 'n': ids.length}))));
      },
    );
  }

  /// 新建分类：弹窗内可修改分类名称（限长），确认后把选中项归入该分类。
  Future<void> _createCategory() async {
    final controller = TextEditingController(text: '新分类');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('createCategory')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: t('categoryName'),
            hintText: t('maxNameHint'),
            counterText: '',
          ),
          onChanged: (value) {
            if (categoryNameWidth(value) > kMaxCategoryNameWidth) {
              controller.text = value.substring(0, value.length - 1);
              controller.selection = TextSelection.collapsed(
                  offset: controller.text.length);
            }
          },
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(t('create')),
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
          ? t('categoryCreated', {'name': trimmed, 'n': count})
          : t('assigned', {'name': trimmed, 'n': count})),
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
                label: Text(t('import')),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Text(t('appName'), style: const TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          tooltip: t('select'),
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
        tooltip: t('deselectAll'),
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelectMode,
      ),
      title: Text(t('selectedCount', {'n': _selectedIds.length}),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: colors.surfaceContainerLow,
      actions: [
        IconButton(
          tooltip: t('category'),
          icon: const Icon(Icons.label_outline_rounded),
          onPressed: _selectedIds.isEmpty ? null : _showCategorySheet,
        ),
        IconButton(
          tooltip: t('share'),
          icon: const Icon(Icons.share_rounded),
          onPressed: _selectedIds.isEmpty ? null : _shareSelected,
        ),
        IconButton(
          tooltip: _selectedIds.length == _store.count ? t('deselectAll') : t('selectAll'),
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
          tooltip: t('delete'),
          icon: Icon(Icons.delete_outline_rounded, color: colors.error),
          onPressed:
              _selectedIds.isEmpty ? null : () => _deleteSelected(),
        ),
        const SizedBox(width: 4),
      ],
      bottom: _buildCategoryBar(),
    );
  }

  /// 分类栏：默认「全部 / 未分类」与自定义分类都在列表里，可长按拖拽排序
  /// （单排横向滚动），末尾有管理按钮。
  PreferredSizeWidget _buildCategoryBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        height: 56,
        color: Theme.of(context).appBarTheme.backgroundColor,
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final categories = _store.categories;
            return Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: true,
                    itemCount: categories.length,
                    // 拖到边缘的自动滚动速度调慢（默认 50 → 20）。
                    autoScrollerVelocityScalar: 20,
                    onReorderItem: (oldIndex, newIndex) =>
                        _store.reorderCategory(oldIndex, newIndex),
                    // 不加 elevation：拖拽时分类标签下方不出现阴影。
                    proxyDecorator: (child, index, animation) => child,
                    itemBuilder: (context, index) => Padding(
                      key: ValueKey(categories[index]),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _categoryChip(
                          label: _categoryLabel(categories[index]),
                          value: categories[index]),
                    ),
                  ),
                ),
                _manageButton(),
                const SizedBox(width: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 分类管理入口：进入管理页选择分类，右上角删除 / 重命名。
  Widget _manageButton() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        tooltip: t('manageCategories'),
        icon: Icon(Icons.tune_rounded, color: colors.onSurfaceVariant),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => CategoryManagePage(store: _store)),
        ),
      ),
    );
  }

  /// 分类栏显示名：内置「全部 / 未分类」跟随界面语言，其余原样。
  String _categoryLabel(String category) => switch (category) {
        kAllCategory => t('all'),
        kUncategorizedCategory => t('uncategorized'),
        _ => category,
      };

  Widget _categoryChip({required String label, required String? value}) {
    final selected = _activeCategory == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (selected) {
        if (selected) setState(() => _activeCategory = value);
      },
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
            filtering ? t('emptyCategory') : t('emptyStickers'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            filtering ? t('emptyCategoryHint') : t('emptyStickersHint'),
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
