import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import 'order_form_screen.dart';
import 'package:stockapp_mvp/src/repos/inmem_repo.dart';

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<OrderRepo>();
    context.watch<InMemoryRepo>(); // 🔔 주문 변경 시 리빌드

    return Scaffold(
      appBar: AppBar(title: const Text('주문 목록')),
      body: FutureBuilder(
        future: repo.listOrders(),
        builder: (context, snap) {
          final orders = (snap.data ?? <Order>[]);
          if (orders.isEmpty) {
            return const Center(child: Text('주문이 없습니다. + 버튼으로 추가하세요.'));
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
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: o.id)));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final id = const Uuid().v4();
          await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: id, createIfMissing: true)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
