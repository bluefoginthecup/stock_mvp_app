import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';
import 'order_form_screen.dart';
import 'order_detail_screen.dart';
import '../../ui/common/draggable_fab.dart';
import '../../utils/item_presentation.dart'; // ✅ 아이템 이름 포맷 함수

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
        return _OrderAccordionTile(
                      order: o,
                      onOpenDetail: () => onTapOrder(o),
                );
      },
    );
  }
}
/// 개별 주문 아코디언 타일 (부드러운 슬라이드다운)
class _OrderAccordionTile extends StatefulWidget {
    final Order order;
    final VoidCallback onOpenDetail;
    const _OrderAccordionTile({
      required this.order,
      required this.onOpenDetail,
    });

    @override
    State<_OrderAccordionTile> createState() => _OrderAccordionTileState();
  }

class _OrderAccordionTileState extends State<_OrderAccordionTile>
    with TickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final totalQty = o.lines.fold<int>(0, (a, b) => a + b.qty);
    final dateStr = o.date.toIso8601String().substring(0, 10);

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // 헤더 행
          InkWell(
            onTap: () => setState(() => _open = !_open),
            onLongPress: widget.onOpenDetail,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
    // ▼ / ▲ 아이콘 (펼침 상태에 따라 전환)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _open
                            ? const Icon(Icons.keyboard_arrow_up, key: ValueKey('up'))
                            : const Icon(Icons.keyboard_arrow_down, key: ValueKey('down')),
                      ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "김철수 (총 N개)"
                        Text(
                          '${o.customer} (${totalQty}개)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateStr • ${o.status.name}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              // 우측: 주문 상세 진입 버튼
                                IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.chevron_right),
                                  onPressed: widget.onOpenDetail,
                                  tooltip: '주문 상세',
                                ),
                ],
              ),
            ),
          ),

          // 펼쳐지는 부분 (부드러운 높이  슬라이드  페이드)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                // 슬라이드  페이드로 "슥" 내려오는 느낌
                final offsetTween =
                    Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.easeOut));
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: animation.drive(offsetTween), child: child),
                );
              },
              child: _open
                  ? Container(
                      key: const ValueKey('open'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
                      // 48 = 화살표 좌측 여백 정렬
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 라인 목록
    ...o.lines.map((line) => Padding(
       padding: const EdgeInsets.only(bottom: 6),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('• '),
           const SizedBox(width: 6),
           Expanded(
             child: Row(
               children: [
                 Expanded(
                   child: ItemLabel(
                     itemId: line.itemId,
                     full: false,                // ← shortLabel과 동일 포맷
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                     style: const TextStyle(fontSize: 14),
                     autoNavigate: true,         // 탭 시 아이템 상세 이동 원치 않으면 false
                   ),
                 ),
                 const SizedBox(width: 8),
                 Text('· ${line.qty}개', style: const TextStyle(fontSize: 14)),
               ],
             ),
           ),
         ],
       ),
     )),

    // 목록 하단 여백/구분용 Chip 등을 원하면 여기 추가
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('closed')),
            ),
          ),
        ],
      ),
    );
  }
}