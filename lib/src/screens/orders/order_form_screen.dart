import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/order.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/order_planning_service.dart';
import '../../ui/common/qty_control.dart';
import '../../ui/common/ui.dart';
import '../../ui/common/search_field.dart'; // 🔍 공용 검색필드 (디바운스 내장)
import '../../utils/item_presentation.dart';
import '../../ui/common/delete_more_menu.dart';
import '../../ui/common/suggestion_panel.dart';




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
  final _searchC = TextEditingController(); // 🔍 검색 입력
  final ScrollController _pageScroll = ScrollController(); // ✅ 페이지 스크롤 컨트롤러
  bool _searching = false; // 🔍 로딩 표시
  List<Item> _results = <Item>[]; // 🔍 결과 버퍼
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
    _pageScroll.dispose();
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

    if (idx < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageScroll.hasClients) {
          final target = _pageScroll.position.maxScrollExtent + 200;
          _pageScroll.animateTo(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        }
      });
    }
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

    final isInternal = updated.customer.trim() == '재고보충';

    final svc = OrderPlanningService(
      items: context.read<ItemRepo>(),
      orders: context.read<OrderRepo>(),
      works: context.read<WorkRepo>(),
      purchases: context.read<PurchaseOrderRepo>(),
      txns: context.read<TxnRepo>(),
    );

    await svc.saveOrderAndAutoPlanShortage(
      updated,
      preferWork: true,
      forceMake: isInternal,
    );

    if (!mounted) return;

    // 컨텍스트 기반 스낵바 + 액션
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: const Text('저장 + 부족분 자동 계획 생성 완료'),
          action: SnackBarAction(
            label: '주문상세 보기',
            onPressed: () {
              // 현재 화면이 pop된 후에도 동작하도록 rootNavigator 사용
              if (!mounted) return;
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/orders/detail', arguments: _order.id);
            },
          ),
        ),
      );

    // 현재 화면 닫기 (호출부가 결과를 사용할 수도 있음)
    Navigator.of(context).pop(_order.id);
  }

  @override
  Widget build(BuildContext context) {
    final itemsRepo = context.read<ItemRepo>(); // 🔍 전역검색용
    final orderId = widget.orderId; // non-null

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.order_form_title),
        actions: [
          if (orderId.isNotEmpty)
            FutureBuilder<Order?>(
              future: context.read<OrderRepo>().getOrder(orderId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                final order = snap.data;
                if (order == null) return const SizedBox.shrink();

                return DeleteMoreMenu<Order>(
                  entity: order,
                  onChanged: () {
                    Navigator.maybePop(context);
                  },
                );
              },
            ),
        ],
      ),
      body: ListView(
        controller: _pageScroll,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          AppSearchField(
            controller: _searchC,
            hint: '품목 검색: 이름 또는 SKU',
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
          if (_results.isNotEmpty)
            SuggestionPanel<Item>(
              items: _results,
              rowHeight: 56,
              maxRows: 5,
              itemBuilder: (_, it) => ListTile(
                title: Text(it.displayName ?? it.name),
                subtitle: (it.sku.isNotEmpty) ? Text(it.sku) : null,
                onTap: () => _addLine(it),
              ),
            ),

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
          Text(
            context.t.section_order_items,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ..._order.lines.map((ln) {
            return ListTile(
              key: ValueKey(ln.id),
              leading: const Icon(Icons.shopping_cart),
              title: ItemLabel(
                itemId: ln.itemId,
                full: false,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  QtyControl(
                    label: '수량',
                    value: ln.qty,
                    min: 1,
                    step: 1,
                    onChanged: (q) => _updateQty(ln.id, q),
                    dense: true,
                    fieldWidth: 48,
                    labelGap: 8,
                    gap: 4,
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeLine(ln.id),
              ),
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
