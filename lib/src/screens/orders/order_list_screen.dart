import 'package:flutter/material.dart';
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
  late Future<List<Order>> _future;

  OrderRepo get _repo => context.read<OrderRepo>();

  @override
  void initState() {
    super.initState();
    _future = _repo.listOrders();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.listOrders();
    });
    // await 해서 당겨서 새로고침 인디케이터가 자연스럽게 사라지도록
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.order_list_title)),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t.common_error,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${snap.error}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _reload,
                        child: Text(context.t.common_retry),
                      ),
                    ],
                  ),
                ),
              );
            }

            final orders = (snap.data ?? <Order>[]).toList()
              ..sort((a, b) => b.date.compareTo(a.date)); // 최신순

            if (orders.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(child: Text(context.t.order_list_empty_hint)),
                  )
                ],
              );
            }

            return ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final o = orders[i];
                final totalQty =
                    o.lines?.fold<int>(0, (a, b) => a + (b.qty)) ?? 0;

                return ListTile(
                  title: Text('${o.customer} (${totalQty}ea)'),
                  subtitle: Text(
                    '${o.date.toIso8601String().substring(0, 10)} • ${o.status.name}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: o),
                      ),
                    );
                    await _reload(); // 상세에서 변경되었을 수 있으니 리프레시
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-orders',
        onPressed: () async {
          final id = const Uuid().v4();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OrderFormScreen(orderId: id, createIfMissing: true),
            ),
          );
          await _reload(); // 신규 생성 후 목록 갱신
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
