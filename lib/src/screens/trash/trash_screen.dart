import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/order.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  String _query = '';

  Future<List<Order>> _load(BuildContext context) async {
    final repo = context.read<OrderRepo>();
    final all = await repo.listOrders(includeDeleted: true);
    // 휴지된 것만
    final del = all.where((o) => o.isDeleted).toList();
    if (_query.isEmpty) return del;
    final q = _query.toLowerCase();
    return del.where((o) =>
    o.customer.toLowerCase().contains(q) ||
        (o.memo ?? '').toLowerCase().contains(q) ||
        o.id.toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _restore(BuildContext ctx, Order o) async {
    final repo = ctx.read<OrderRepo>();
    await repo.restoreOrder(o.id);
    if (!mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('복구되었습니다')),
    );
    setState(() {});
  }

  Future<void> _hardDelete(BuildContext ctx, Order o) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('완전 삭제'),
        content: const Text('되돌릴 수 없습니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    final repo = ctx.read<OrderRepo>();
    await repo.hardDeleteOrder(o.id);
    if (!mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('완전 삭제되었습니다')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴지통 • 주문')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '고객명/메모/ID 검색',
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _load(context),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const <Order>[];
                if (items.isEmpty) {
                  return const Center(child: Text('삭제된 주문이 없습니다.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final o = items[i];
                    final totalQty = o.lines.fold<int>(0, (a, b) => a + b.qty);
                    final dateStr = o.date.toIso8601String().substring(0, 10);
                    return ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('${o.customer} (${totalQty}ea)'),
                      subtitle: Text('$dateStr • ${o.status.name} • ${o.id}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          switch (v) {
                            case 'restore':
                              _restore(context, o);
                              break;
                            case 'hard':
                              _hardDelete(context, o);
                              break;
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'restore', child: Text('복구')),
                          PopupMenuItem(value: 'hard', child: Text('완전 삭제')),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
