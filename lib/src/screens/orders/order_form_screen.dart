import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/order.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/order_planning_service.dart';
import '../../ui/common/qty_control.dart';

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
    final id = const Uuid().v4();
    final line = OrderLine(id: id, itemId: item.id, qty: 1);
    setState(() {
      _order = _order.copyWith(lines: [..._order.lines, line]);
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
    final itemRepo = context.read<ItemRepo>();
    return Scaffold(
      appBar: AppBar(title: const Text('주문 편집')),
      body: FutureBuilder<List<Item>>(
        future: itemRepo.listItems(folder: 'finished'),
        builder: (context, snap) {
          final finished = (snap.data ?? <Item>[]);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _customerC,
                decoration: const InputDecoration(labelText: '고객명'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _memoC,
                decoration: const InputDecoration(labelText: '메모'),
              ),
              const SizedBox(height: 16),
              const Text('주문 품목', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 품목 선택 영역
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ))
              else if (finished.isEmpty)
                const Text('등록된 완제품이 없습니다. 먼저 품목을 추가하세요.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: finished
                      .map((it) => ActionChip(
                    label: Text(it.name),
                    onPressed: () => _addLine(it),
                  ))
                      .toList(),
                ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // 주문 라인 목록
              ..._order.lines.map((ln) {
                final item = finished.firstWhere(
                      (f) => f.id == ln.itemId,
                  orElse: () => Item(
                    id: '?',
                    name: '(삭제되었거나 찾을 수 없음)',
                    sku: '',
                    unit: 'EA',
                    folder: 'finished',
                    minQty: 0,
                    qty: 0,
                  ),
                );

                return ListTile(
                  key: ValueKey(ln.id),
                  leading: const Icon(Icons.shopping_cart),
                  title: Text(item.name),
                  subtitle: Text('수량: ${ln.qty}'),
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
                        tooltip: '라인 삭제',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeLine(ln.id),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }
}
