import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import 'search_field.dart';
import 'suggestion_panel.dart';

Future<String?> showItemPickerSheet(
  BuildContext context, {
  String? initialItemId,
  String title = '아이템 선택',
  List<String> contextItemIds = const [],
  String contextTitle = '선택한 아이템',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemPickerSheet(
      initialItemId: initialItemId,
      title: title,
      contextItemIds: contextItemIds,
      contextTitle: contextTitle,
    ),
  );
}

class _ItemPickerSheet extends StatefulWidget {
  final String? initialItemId;
  final String title;
  final List<String> contextItemIds;
  final String contextTitle;

  const _ItemPickerSheet({
    required this.initialItemId,
    required this.title,
    required this.contextItemIds,
    required this.contextTitle,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final _searchC = TextEditingController();
  bool _searching = false;
  bool _loadingContext = false;
  List<Item> _contextItems = <Item>[];
  List<Item> _results = <Item>[];
  final _pathLabels = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadContextItems();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadContextItems() async {
    if (widget.contextItemIds.isEmpty) return;
    setState(() => _loadingContext = true);
    final repo = context.read<ItemRepo>();
    final items = <Item>[];
    for (final id in widget.contextItemIds) {
      final item = await repo.getItem(id);
      if (item != null) items.add(item);
    }
    await _loadPathLabels(repo, items);
    if (!mounted) return;
    setState(() {
      _contextItems = items;
      _loadingContext = false;
    });
  }

  Future<void> _loadPathLabels(ItemRepo repo, List<Item> items) async {
    for (final item in items) {
      if (_pathLabels.containsKey(item.id)) continue;
      final names = await repo.itemPathNames(item.id);
      _pathLabels[item.id] = names.isEmpty ? '경로 없음' : names.join(' > ');
    }
  }

  Future<void> _search(ItemRepo repo, String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await repo.searchItemsGlobal(q);
    await _loadPathLabels(repo, results);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsRepo = context.read<ItemRepo>();
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.contextItemIds.isNotEmpty) ...[
                _buildContextItems(),
                const SizedBox(height: 12),
              ],
              AppSearchField(
                controller: _searchC,
                hint: '이름/SKU/초성(예: ㅈㅅㅁ ㄹㅇ ㄱㄹㅇ)',
                onChanged: (q) => _search(itemsRepo, q),
              ),
              if (_searching) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              if (_results.isNotEmpty)
                Flexible(
                  child: SuggestionPanel<Item>(
                    items: _results,
                    rowHeight: 76,
                    maxRows: 8,
                    itemBuilder: (_, it) {
                      final selected = widget.initialItemId != null &&
                          it.id == widget.initialItemId;
                      return ListTile(
                        leading: selected ? const Icon(Icons.check) : null,
                        title: Text(it.displayName ?? it.name),
                        subtitle: Text(_itemSubtitle(it)),
                        onTap: () => Navigator.pop(context, it.id),
                      );
                    },
                  ),
                )
              else
                const Flexible(
                  child: Center(child: Text('검색어를 입력하세요')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextItems() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.contextTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 168),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _loadingContext
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _contextItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = _contextItems[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item.displayName ?? item.name),
                      subtitle: Text(_itemSubtitle(item)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _itemSubtitle(Item item) {
    final parts = <String>[
      if (item.sku.trim().isNotEmpty) item.sku.trim(),
      _pathLabels[item.id] ?? '경로 확인 중...',
    ];
    return parts.join(' · ');
  }
}
