import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/sticker_store.dart';
import '../widgets/sticker_tile.dart';
import 'sticker_detail_page.dart';

/// 搜索一级界面：按名称（与所属分类名）搜索表情包。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final StickerStore _store = StickerStore.instance;
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _store.load();
    _controller.addListener(() => setState(() => _query = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Sticker> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return [
      for (final s in _store.items)
        if (s.name.toLowerCase().contains(query) ||
            (s.category ?? '').toLowerCase().contains(query))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: t('searchHint'),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final results = _results;
          if (_query.trim().isEmpty) {
            return _hint(context, Icons.search_rounded, t('searchHint'));
          }
          if (results.isEmpty) {
            return _hint(context, Icons.search_off_rounded, t('searchEmpty'));
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            itemCount: results.length,
            itemBuilder: (context, index) => StickerTile(
              key: ValueKey(results[index].id),
              store: _store,
              sticker: results[index],
              selectMode: false,
              selected: false,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => StickerDetailPage(
                    store: _store, sticker: results[index]),
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _hint(BuildContext context, IconData icon, String message) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 88, color: colors.outlineVariant),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
