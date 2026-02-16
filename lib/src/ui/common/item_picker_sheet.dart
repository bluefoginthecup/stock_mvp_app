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
    }) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemPickerSheet(
      initialItemId: initialItemId,
      title: title,
    ),
  );
}

class _ItemPickerSheet extends StatefulWidget {
  final String? initialItemId;
  final String title;

  const _ItemPickerSheet({
    required this.initialItemId,
    required this.title,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final _searchC = TextEditingController();
  bool _searching = false;
  List<Item> _results = <Item>[];

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsRepo = context.read<ItemRepo>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),

            AppSearchField(
              controller: _searchC,
              hint: '이름/SKU/초성(예: ㅈㅅㅁ ㄹㅇ ㄱㄹㅇ)',
              onChanged: (q) async {
                final qq = q.trim();
                if (qq.isEmpty) {
                  setState(() {
                    _results = [];
                    _searching = false;
                  });
                  return;
                }
                setState(() => _searching = true);
                final res = await itemsRepo.searchItemsGlobal(qq);
                if (!mounted) return;
                setState(() {
                  _results = res;
                  _searching = false;
                });
              },
            ),
            if (_searching) const LinearProgressIndicator(),
            const SizedBox(height: 8),

            if (_results.isNotEmpty)
              SuggestionPanel<Item>(
                items: _results,
                rowHeight: 56,
                maxRows: 8,
                itemBuilder: (_, it) {
                  final selected = (widget.initialItemId != null && it.id == widget.initialItemId);
                  return ListTile(
                    leading: selected ? const Icon(Icons.check) : null,
                    title: Text(it.displayName ?? it.name),
                    subtitle: it.sku.isNotEmpty ? Text(it.sku) : null,
                    onTap: () => Navigator.pop(context, it.id), // ✅ itemId 반환
                  );
                },
              )
            else
              const SizedBox(height: 240, child: Center(child: Text('검색어를 입력하세요'))),
          ],
        ),
      ),
    );
  }
}
