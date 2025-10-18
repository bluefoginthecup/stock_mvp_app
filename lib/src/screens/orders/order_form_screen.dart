import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/order.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/order_planning_service.dart';
import '../../ui/common/qty_control.dart';
import '../../ui/common/ui.dart';
import '../../ui/common/search_field.dart'; // 🔍 공용 검색필드 (디바운스 내장)


class OrderFormScreen extends StatefulWidget {
  final String orderId;
  final bool createIfMissing;
  const OrderFormScreen({
    super.key,
    required this.orderId,
    this.createIfMissing = false,
  });

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _customerC = TextEditingController();
  final _memoC = TextEditingController();
    final _searchC = TextEditingController();           // 🔍 검색 입력
    bool _searching = false;                            // 🔍 로딩 표시
    List<Item> _results = <Item>[];                     // 🔍 결과 버퍼
  late Order _order;

  @override
  void initState() {
    super.initState();
    _order = Order(
      id: widget.orderId,
      date: DateTime.now(),
      customer: '',
      memo: '',
      status: OrderStatus.draft,
      lines: [],
    );
  }

  @override
    void dispose() {
        _customerC.dispose();
        _memoC.dispose();
        _searchC.dispose(); // 🔍
        super.dispose();
      }

  Future<void> _ensureLoaded() async {
    final repo = context.read<OrderRepo>();
    final existing = await repo.getOrder(widget.orderId);
    if (!mounted) return;
    if (existing != null) {
      setState(() {
        _order = existing;
        _customerC.text = existing.customer;
        _memoC.text = existing.memo ?? '';
      });
    } else if (widget.createIfMissing) {
      await repo.upsertOrder(_order);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  void _addLine(Item item) {

        // ✅ 이미 있으면 수량 +1, 없으면 추가
        final idx = _order.lines.indexWhere((l) => l.itemId == item.id);
        setState(() {
          if (idx >= 0) {
            final cur = _order.lines[idx];
            final next = cur.copyWith(qty: cur.qty + 1);
            final newLines = [..._order.lines]..[idx] = next;
            _order = _order.copyWith(lines: newLines);
          } else {
            final id = const Uuid().v4();
            final line = OrderLine(id: id, itemId: item.id, qty: 1);
            _order = _order.copyWith(lines: [..._order.lines, line]);
          }
        });
  }

  void _updateQty(String lineId, int newQty) {
    setState(() {
      _order = _order.copyWith(
        lines: _order.lines.map((ln) {
          if (ln.id == lineId) {
            final q = newQty < 1 ? 1 : newQty;
            return ln.copyWith(qty: q);
          }
          return ln;
        }).toList(),
      );
    });
  }

  void _removeLine(String lineId) {
    setState(() {
      _order = _order.copyWith(
        lines: _order.lines.where((ln) => ln.id != lineId).toList(),
      );
    });
  }

  Future<void> _save() async {
    final updated = _order.copyWith(
      customer: _customerC.text.trim(),
      memo: _memoC.text.trim(),
    );

    final svc = OrderPlanningService(
      items: context.read<ItemRepo>(),
      orders: context.read<OrderRepo>(),
      works: context.read<WorkRepo>(),
      purchases: context.read<PurchaseRepo>(),
      txns: context.read<TxnRepo>(),
    );

    await svc.saveOrderAndAutoPlanShortage(updated, preferWork: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장 + 부족분 자동 계획 생성 완료')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final itemsRepo = context.read<ItemRepo>();   // 🔍 전역검색용

    return Scaffold(
      appBar: AppBar(title: Text(context.t.order_form_title)),

     // 변경: 전역 검색만 사용 (검색어 없으면 결과 섹션 숨김)
     body: ListView(
       padding: const EdgeInsets.all(16),
       children: [
         AppSearchField(
           controller: _searchC,
           hint: '품목 검색: 이름 또는 SKU',
           onChanged: (q) async {
             final qq = q.trim();
             if (qq.isEmpty) { setState(() { _results = []; _searching = false; }); return; }
             setState(() => _searching = true);
              final res = await itemsRepo.searchItemsGlobal(qq);
             if (!mounted) return;
             setState(() { _results = res; _searching = false; });
           },
         ),
         if (_searching) const LinearProgressIndicator(),
         if (!_searching && _searchC.text.trim().isNotEmpty) ...[
           const SizedBox(height: 8),
           if (_results.isEmpty) Text('검색 결과가 없습니다.'),
           ..._results.map((it) => ListTile(
             leading: const Icon(Icons.inventory_2),
             title: Text(it.name),
             subtitle: Text('SKU: ${it.sku}'),
             trailing: FilledButton(onPressed: () => _addLine(it), child: const Text('+ 추가')),
           )),
           const Divider(height: 24),
         ],
              // 고객/메모
              TextField(
                controller: _customerC,
                decoration: InputDecoration(labelText: context.t.field_customer),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _memoC,
                decoration: InputDecoration(labelText: context.t.field_memo),
              ),
              const SizedBox(height: 16),
              Text(context.t.section_order_items, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 주문 라인 목록 (각 라인에서 ItemRepo로 이름 조회)
              ..._order.lines.map((ln) {
                return FutureBuilder<Item?>(
                  future: itemsRepo.getItem(ln.itemId),
                  builder: (context, snap) {
                    final itemName = snap.data?.name ?? context.t.item_loading_or_missing;
                    return ListTile(
                      key: ValueKey(ln.id),
                      leading: const Icon(Icons.shopping_cart),
                      title: Text(itemName),
                      subtitle: Text(context.t.order_line_qty(ln.qty)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QtyControl(
                            value: ln.qty,
                            min: 1,
                            step: 1,
                            onChanged: (q) => _updateQty(ln.id, q),
                          ),
                          IconButton(
                            tooltip: context.t.tooltip_delete_line,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeLine(ln.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                child: Text(context.t.btn_save),
              ),
            ],
          ),
    );
  }
}

