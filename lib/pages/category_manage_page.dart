import 'package:flutter/material.dart';

import '../services/sticker_store.dart';

/// 分类管理页：点选一个分类后，右上角可重命名或删除。
/// 内置「全部 / 未分类」不可删除，重命名同样受限（校验在 store）。
class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key, required this.store});

  final StickerStore store;

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  String? _selected;

  Future<void> _rename() async {
    final selected = _selected;
    if (selected == null) return;
    final controller = TextEditingController(text: selected);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '分类名称',
            hintText: '最多 3 个汉字（或 6 个英文）',
            counterText: '',
          ),
          onChanged: (value) {
            if (categoryNameWidth(value) > kMaxCategoryNameWidth) {
              controller.text = value.substring(0, value.length - 1);
              controller.selection =
                  TextSelection.collapsed(offset: controller.text.length);
            }
          },
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
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    final newName = await widget.store.renameCategory(selected, name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newName == null
          ? '名称无效：不能为空、超长或与现有分类同名'
          : '已重命名为「$newName」'),
    ));
    if (newName != null) setState(() => _selected = newName);
  }

  Future<void> _delete() async {
    final selected = _selected;
    if (selected == null) return;
    if (selected == kAllCategory || selected == kUncategorizedCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('内置分类不可删除')));
      return;
    }
    final count =
        widget.store.items.where((s) => s.category == selected).length;
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('删除分类「$selected」？其中 $count 个表情包将变为未分类。'),
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
    await widget.store.deleteCategory(selected);
    if (!mounted) return;
    setState(() => _selected = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除分类「$selected」')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理分类', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: '重命名',
            icon: const Icon(Icons.drive_file_rename_outline_rounded),
            onPressed: _selected == null ? null : _rename,
          ),
          IconButton(
            tooltip: '删除',
            icon: Icon(Icons.delete_outline_rounded,
                color: _selected == null ? null : colors.error),
            onPressed: _selected == null ? null : _delete,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('选择一个分类，可在右上角删除或重命名',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
            ),
            for (final c in widget.store.categories)
              ListTile(
                title: Text(c),
                subtitle: c == kAllCategory || c == kUncategorizedCategory
                    ? const Text('内置分类，不可删除', style: TextStyle(fontSize: 12))
                    : null,
                trailing: _selected == c
                    ? Icon(Icons.check_circle_rounded, color: colors.primary)
                    : Icon(Icons.circle_outlined,
                        color: colors.outlineVariant),
                selected: _selected == c,
                onTap: () => setState(() => _selected = c),
              ),
          ],
        ),
      ),
    );
  }
}
