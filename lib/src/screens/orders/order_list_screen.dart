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
    final b = context.read<OrderRepo>();
    print('[OrderList]  OrderRepo instance: ${identityHashCode(b)} ${b.runtimeType}');
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.listOrders();
    });
    await _future;
  }

  Future<void> _deleteOrder(Order o, {required bool hard}) async {
    final t = context.t;

    // ❗ showDialog는 null을 반환할 수 있으므로 bool? 로 받기
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          // 타이틀: 하드/소프트에 따라 다른 질문형 제목
          title: Text(hard ? t.common_delete_forever : t.common_delete_title),
          // 본문: 하드/소프트 각각의 설명 (l10n으로 통일)
          content: Text(
            hard ? t.confirm_delete_forever_body : t.confirm_delete_soft_body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(t.common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              // 액션 라벨은 짧고 명확하게: Delete / Permanently delete
              child: Text(hard ? t.common_delete_forever : t.common_delete),
            ),
          ],
        );
      },
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
        SnackBar(
          content: Text(
            hard ? t.toast_order_deleted_forever : t.toast_order_hidden,
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.toast_order_delete_failed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: AppBar(title: Text(t.order_list_title)),
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
                      Text(t.common_error,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${snap.error}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _reload,
                        child: Text(t.common_retry),
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
                final totalQty = o.lines?.fold<int>(0, (a, b) => a + (b.qty)) ?? 0;

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
                          _deleteOrder(o, hard: false);
                          break;
                        case 'hard':
                          _deleteOrder(o, hard: true);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'soft',
                        child: Text(t.menu_delete_hide), // ← l10n
                      ),
                      PopupMenuItem(
                        value: 'hard',
                        child: Text(t.menu_delete_forever), // ← l10n
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
