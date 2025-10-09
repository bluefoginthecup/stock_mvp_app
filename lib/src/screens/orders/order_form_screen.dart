import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/order.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/order_planning_service.dart';

class OrderFormScreen extends StatefulWidget {
  final String orderId;
  final bool createIfMissing;
  const OrderFormScreen({super.key, required this.orderId, this.createIfMissing = false});

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
    _order = Order(id: widget.orderId, date: DateTime.now(), customer: '', memo: '', status: OrderStatus.draft, lines: []);
  }

  Future<void> _ensureLoaded() async {
    final repo = context.read<OrderRepo>();
    final existing = await repo.getOrder(widget.orderId);
    if (existing != null) {
      setState(() { _order = existing; _customerC.text = existing.customer; _memoC.text = existing.memo ?? ''; });
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
    setState(() => _order = _order.copyWith(lines: [..._order.lines, line]));
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
      body: FutureBuilder(
        future: itemRepo.listItems(folder: 'finished'),
        builder: (context, snap) {
          final finished = (snap.data ?? <Item>[]);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _customerC, decoration: const InputDecoration(labelText: '고객명')),
              const SizedBox(height: 8),
              TextField(controller: _memoC, decoration: const InputDecoration(labelText: '메모')),
              const SizedBox(height: 16),
              const Text('주문 품목', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: finished.map((it) => ActionChip(
                  label: Text(it.name),
                  onPressed: () => _addLine(it),
                )).toList(),
              ),
              const SizedBox(height: 12),
              ..._order.lines.map((ln) => ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: Text(finished.firstWhere((f) => f.id == ln.itemId, orElse: () => Item(id:'?', name:'?', sku:'', unit:'EA', folder:'finished', minQty:0, qty:0)).name),
                subtitle: Text('수량: ${ln.qty}'),
              )),
              const SizedBox(height: 32),
              FilledButton(onPressed: _save, child: const Text('저장')),
            ],
          );
        },
      ),
    );
  }
}
