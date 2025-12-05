import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';
import 'order_form_screen.dart';
import 'order_detail_screen.dart';
import '../../ui/common/draggable_fab.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  OrderRepo get _repo => context.read<OrderRepo>();

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return StreamBuilder<List<Order>>(
      stream: _repo.watchOrders(),
      builder: (context, snap) {
        // 로딩
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(t.order_list_title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // 데이터 정렬 (최신일자 우선)
        final orders = (snap.data ?? const <Order>[])
          ..sort((a, b) => b.date.compareTo(a.date));

        // 탭용 필터링
        final ongoing = orders.where((o) => o.status != OrderStatus.done).toList();
        final completed = orders.where((o) => o.status == OrderStatus.done).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(t.order_list_title),
              bottom: TabBar(
                tabs: [
                  Tab(text: '진행중 (${ongoing.length})'),
                  Tab(text: '완료된 주문 (${completed.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OrdersListView(
                  orders: ongoing,
                  emptyHint: t.order_list_empty_hint, // 필요하면 진행중 전용 힌트로 바꿔도 됨
                  onTapOrder: (o) async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                    );
                  },
                  onDeleteSoft: (o) async {
                    await _repo.softDeleteOrder(o.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.toast_order_hidden)),
                    );
                  },
                  onDeleteHard: (o) async {
                    await _repo.hardDeleteOrder(o.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.toast_order_deleted_forever)),
                    );
                  },
                ),
                _OrdersListView(
                  orders: completed,
                  emptyHint: t.order_list_empty_hint, // 필요하면 완료 전용 힌트로 바꿔도 됨
                  onTapOrder: (o) async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                    );
                  },
                  onDeleteSoft: (o) async {
                    await _repo.softDeleteOrder(o.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.toast_order_hidden)),
                    );
                  },
                  onDeleteHard: (o) async {
                    await _repo.hardDeleteOrder(o.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.toast_order_deleted_forever)),
                    );
                  },
                ),
              ],
            ),

            // ✔ 필요하면 진행중 탭에서만 보여주도록 개선 가능하지만,
            //   일단은 두 탭 공통으로 노출한다.
            floatingActionButton: DraggableFab(
              storageKey: 'fab_offset_order_list',
              child: FloatingActionButton(
                heroTag: 'fab-orders',
                onPressed: () async {
                  final id = const Uuid().v4();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderFormScreen(
                        orderId: id,
                        createIfMissing: true,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 공통 리스트 뷰 위젯
class _OrdersListView extends StatelessWidget {
  final List<Order> orders;
  final String emptyHint;
  final void Function(Order) onTapOrder;
  final Future<void> Function(Order) onDeleteSoft;
  final Future<void> Function(Order) onDeleteHard;

  const _OrdersListView({
    required this.orders,
    required this.emptyHint,
    required this.onTapOrder,
    required this.onDeleteSoft,
    required this.onDeleteHard,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(child: Text(emptyHint)),
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
        final dateStr = o.date.toIso8601String().substring(0, 10);

        return ListTile(
          title: Text('${o.customer} (${totalQty}ea)'),
          subtitle: Text('$dateStr • ${o.status.name}'),
          onTap: () => onTapOrder(o),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'soft') {
                await onDeleteSoft(o);
              } else if (v == 'hard') {
                await onDeleteHard(o);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'soft', child: Text('숨김(소프트 삭제)')),
              PopupMenuItem(value: 'hard', child: Text('완전 삭제')),
            ],
          ),
        );
      },
    );
  }
}
