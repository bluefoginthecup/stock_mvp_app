
import 'package:provider/provider.dart';

import '../../repos/drift_unified_repo.dart';     // ⬅️ Drift 구현체 직접 사용
import '../../models/item.dart';
import 'stock_new_item_sheet.dart';
import '../txns/adjust_form.dart';
import '../../ui/common/ui.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final _kw = TextEditingController();

  @override
  Widget build(BuildContext context ) {
    // ⬇️ DriftUnifiedRepo 직접 사용 (ItemRepo로 선언하지 않음)
    final drift = context.read<DriftUnifiedRepo>();

    return Scaffold(
      appBar: AppBar(title: Text(context.t.stock_list_title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _kw,
              decoration: InputDecoration(
                hintText: 'context.t.search_name_code_hint',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () { _kw.clear(); setState(() {}); },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            // ⬇️ Drift의 watchItems 스트림으로 즉시 반영
            child: StreamBuilder<List<Item>>(
              stream: drift.watchItems(keyword: _kw.text),
              builder: (context, snap) {
                final items = (snap.data ?? <Item>[]);
                if (items.isEmpty) {
                  return Center(child: Text(context.t.stock_list_empty_hint));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final low = it.qty <= it.minQty;
                    return ListTile(
                      title: Text(it.name),
                      subtitle: Text(
                        '${it.sku} • ${it.folder}${it.subfolder!=null ? ' / ${it.subfolder}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ⭐ 즐겨찾기 토글
                          IconButton(
                            tooltip: '즐겨찾기',
                            icon: Icon(
                              it.isFavorite ? Icons.star : Icons.star_border,
                              color: it.isFavorite ? Colors.amber : null,
                            ),
                            onPressed: () async {
                              await drift.toggleFavorite(it.id, !it.isFavorite);
                            },
                          ),
                          // 수량 표시
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${it.qty}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: low ? Colors.red : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('min ${it.minQty}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => showModalBottomSheet(
                        context: context,
                        builder: (_) => AdjustForm(item: it),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // ⬇️ Drift 폴더 API 사용 (InMemoryRepo 제거)
          final roots = await drift.listFolderChildren(null);
          List<String> pathIds = [];
          if (roots.isEmpty) {
            // 루트가 없으면 하나 만들어서 사용
            final root = await drift.createFolderNode(parentId: null, name: 'Root');
            pathIds = [root.id];
          } else {
            pathIds = [roots.first.id];
          }

          // 새 아이템 입력 시트
          final created = await showModalBottomSheet<Item>(
            context: context,
            isScrollControlled: true,
            builder: (_) => StockNewItemSheet(pathIds: pathIds),
          );

          if (created != null) {
            // pathIds → l1/l2/l3로 변환하여 저장
            final l1 = pathIds.isNotEmpty ? pathIds[0] : null;
            final l2 = pathIds.length > 1 ? pathIds[1] : null;
            final l3 = pathIds.length > 2 ? pathIds[2] : null;

            await drift.upsertItemWithPath(created, l1, l2, l3);
            if (mounted) setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
