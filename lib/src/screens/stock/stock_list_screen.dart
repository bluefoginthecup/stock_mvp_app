
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/item.dart';
import 'stock_new_item_sheet.dart';
import '../txns/adjust_form.dart';
import '../../ui/common/ui.dart';
import 'package:stockapp_mvp/src/repos/inmem_repo.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final _kw = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ItemRepo>();
    context.watch<InMemoryRepo>(); // 🔔 재고 변경 시 화면 리빌드 트리거
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
                suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _kw.clear(); setState(() {}); }),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: repo.listItems(keyword: _kw.text),
              builder: (context, snap) {
                final items = (snap.data ?? <Item>[]);
                if (items.isEmpty) return Center(child: Text(context.t.stock_list_empty_hint));
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final low = it.qty <= it.minQty;
                    return ListTile(
                      title: Text(it.name),
                      subtitle: Text('${it.sku} • ${it.folder}${it.subfolder!=null?' / ${it.subfolder}':''}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${it.qty}', style: TextStyle(fontWeight: FontWeight.bold, color: low ? Colors.red : null)),
                          Text('min ${it.minQty}', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      onTap: () => showModalBottomSheet(context: context, builder: (_) => AdjustForm(item: it)),
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
          final repo = context.read<InMemoryRepo>();

          // 간단한 기본 경로: 루트(대분류) 첫 번째 폴더에 생성
          // (원하면 여기서 중/소분류 선택 UI로 확장 가능)
          final roots = await repo.listFolderChildren(null);
          if (roots.isEmpty) {
            // 루트가 없으면 하나 만들어서 사용
            final root = await repo.createFolderNode(parentId: null, name: 'Root');
            roots.add(root);
          }
          final path = <String>[roots.first.id]; // 최소 1단계 경로

          // 시트를 띄워 아이템 정보를 입력받음
          final created = await showModalBottomSheet<Item>(
            context: context,
            isScrollControlled: true,
            builder: (_) => StockNewItemSheet(pathIds: path),
          );

          // 입력이 완료되면 실제 생성
          if (created != null) {
            await repo.createItemUnderPath(pathIds: path, item: created);
            // 리스트 갱신
            if (mounted) setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),

    );
  }
}
