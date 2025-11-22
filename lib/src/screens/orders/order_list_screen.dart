
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

  Future<void> _deleteOrder(Order o, {required bool hard}) async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(hard ? t.common_delete_forever : t.common_delete_title),
        content: Text(
          hard
              ? '정말 완전 삭제할까요? 이 작업은 되돌릴 수 없습니다.'
              : '주문을 삭제(숨김)합니다. 목록에서 보이지 않게 됩니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.common_cancel)),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(hard ? t.common_delete_forever : t.common_delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (hard) {
        await _repo.hardDeleteOrder(o.id);
      } else {
        await _repo.softDeleteOrder(o.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hard ? '완전 삭제되었습니다.' : '삭제(숨김)되었습니다.')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: o),
                      ),
                    );
                    await _reload(); // 상세에서 변경되었을 수 있으니 리프레시
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'soft':
                          _deleteOrder(o,hard: false);
                          break;
                        case 'hard':
                          _deleteOrder(o,hard: true);
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'soft', child: Text('삭제(숨김)')),
                      PopupMenuItem(
                        value: 'hard',
                        child: Text('완전 삭제'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
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
