// lib/src/screens/stock/stock_browser_helpers.part.dart
part of 'stock_browser_screen.dart';

// ───────────────────────── 공통 필터 로직 ─────────────────────────
List<Item> _applyFilters(List<Item> items,
    {required bool lowOnly, required bool showFavoriteOnly}) {
  var filtered = items;
  if (lowOnly) {
    filtered = filtered.where((it) => it.minQty > 0 && it.qty <= it.minQty).toList();
  }
  if (showFavoriteOnly) {
    filtered = filtered.where((it) => it.isFavorite == true).toList();
  }
  return filtered;
}

// ───────────────────────── PathPicker용 provider ─────────────────────────
ChildrenProvider folderChildrenProvider(FolderTreeRepo repo) {
  return (String? parentId) async {
    final folders = await repo.listFolderChildren(parentId);
    return folders.map((f) => PathNode(f.id, f.name)).toList();
  };
}

// ───────────────────────── 수량 입력 다이얼로그 ─────────────────────────
Future<double?> _askQty(BuildContext context) async {
  final c = TextEditingController(text: '1');
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('발주 수량(공통)'),
      content: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '수량'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        TextButton(
          onPressed: () {
            final v = double.tryParse(c.text.trim());
            Navigator.pop(ctx, (v == null || v <= 0) ? 1.0 : v);
          },
          child: const Text('담기'),
        ),
      ],
    ),
  );
}
