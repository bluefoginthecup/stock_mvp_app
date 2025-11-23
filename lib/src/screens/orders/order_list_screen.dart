import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';
import 'order_form_screen.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {

  OrderRepo get _repo => context.read<OrderRepo>();


  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.order_list_title)),
      body: StreamBuilder<List<Order>>(                   // ✅ 변경
        stream: _repo.watchOrders(),                     // ✅ 변경
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = (snap.data ?? const <Order>[])
            ..sort((a, b) => b.date.compareTo(a.date));

            if (orders.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(child: Text(t.order_list_empty_hint)),
                  )
                ],
              );
            }

          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final o = orders[i];
              final totalQty = o.lines.fold<int>(0, (a, b) => a + b.qty);
              return ListTile(
                title: Text('${o.customer} (${totalQty}ea)'),
                subtitle: Text('${o.date.toIso8601String().substring(0, 10)} • ${o.status.name}'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                  );
                  // ✅ 별도 리로드 필요 없음 (스트림이 자동 반영)
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'soft': await _repo.softDeleteOrder(o.id); break;
                      case 'hard': await _repo.hardDeleteOrder(o.id); break;
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v == 'hard' ? t.toast_order_deleted_forever : t.toast_order_hidden)),
                    );
                    // ✅ 리로드 호출 불필요
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'soft', child: Text(t.menu_delete_hide)),
                    PopupMenuItem(value: 'hard', child: Text(t.menu_delete_forever)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-orders',
        onPressed: () async {
          final id = const Uuid().v4();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: id, createIfMissing: true),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
