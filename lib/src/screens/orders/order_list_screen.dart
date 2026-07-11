import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';
import 'order_form_screen.dart';
import 'order_detail_screen.dart';
import '../../ui/common/draggable_fab.dart';
import '../../utils/item_presentation.dart'; // ItemLabel / 라벨 유틸

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
        final ongoing =
        orders.where((o) => o.status != OrderStatus.done).toList();
        final completed =
        orders.where((o) => o.status == OrderStatus.done).toList();

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
                  emptyHint: t.order_list_empty_hint,
                  onTapOrder: (o) async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: o.id),
                      ),
                    );
                  },
                ),
                _OrdersListView(
                  orders: completed,
                  emptyHint: t.order_list_empty_hint,
                  onTapOrder: (o) async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: o.id),
                      ),
                    );
                  },
                ),
              ],
            ),

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

/// 공통 리스트 뷰 위젯 (전역 펼침/접힘 토글 포함)
class _OrdersListView extends StatefulWidget {
  final List<Order> orders;
  final String emptyHint;
  final void Function(Order) onTapOrder;

  const _OrdersListView({
    required this.orders,
    required this.emptyHint,
    required this.onTapOrder,
  });

  @override
  State<_OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends State<_OrdersListView> {
  // ✅ 처음부터 전체 열림
  bool _allOpen = true;

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(child: Text(widget.emptyHint)),
          )
        ],
      );
    }

    // 전역 토글 바 (맨 위 1개만)
    final topToggleBar = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _allOpen = !_allOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _allOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.blueGrey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _allOpen ? '모두 펼치기' : '모두 접기',
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // 필요하면 여기 오른쪽에 다른 필터/검색 버튼 배치 가능
        ],
      ),
    );

    return Column(
      children: [
        topToggleBar,
        Expanded(
          child: ListView.separated(
            itemCount: widget.orders.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
            itemBuilder: (_, i) {
              final o = widget.orders[i];
              return _OrderAccordionTile(
                order: o,
                isOpen: _allOpen, // ✅ 전역 상태 적용
                onOpenDetail: () => widget.onTapOrder(o),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 개별 주문 아코디언 타일 (부드러운 슬라이드다운 + 상태별 색감)
class _OrderAccordionTile extends StatelessWidget {
  final Order order;
  final bool isOpen; // ✅ 외부에서 전역 열림/접힘 제어
  final VoidCallback onOpenDetail;

  const _OrderAccordionTile({
    required this.order,
    required this.isOpen,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final o = order;
    final totalQty = o.lines.fold<int>(0, (a, b) => a + b.qty);
    final dateStr = o.date.toIso8601String().substring(0, 10);

    // 🎨 팔레트
    const violet = Color(0xFF5B4B8A);
    final blueGrey600 = Colors.blueGrey.shade600;
    final headerBg = (o.status == OrderStatus.done)
        ? const Color(0xFFF0F8FF) // 완료: 아주 연한 블루
        : const Color(0xFFF7F7F7); // 진행중: 아주 연한 그레이
    final bodyBg = Colors.blueGrey.withValues(alpha: 0.04); // 펼침 영역 배경

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // 헤더 행 (상태별 배경) — 개별 ▼ 아이콘 제거, 전역 토글만 사용
          Container(
            decoration: BoxDecoration(color: headerBg),
            child: InkWell(
              // 개별 토글 제거: 헤더 탭은 상세 진입 롱프레스만 유지(원하면 탭=상세로 바꿔도 됨)
              onTap: onOpenDetail,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 좌측 여백(이전 아이콘 공간 정렬용)
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "김철수 (총 N개)"
                          Text(
                            '${o.customer} ($totalQty개)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateStr • ${o.status.name}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 우측: 주문 상세 진입 버튼
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.chevron_right, color: blueGrey600),
                      onPressed: onOpenDetail,
                      tooltip: '주문 상세',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 펼쳐지는 부분 (부드러운 높이 + 슬라이드 + 페이드)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                // 슬라이드 + 페이드로 "슥" 내려오는 느낌
                final offsetTween = Tween<Offset>(
                    begin: const Offset(0, -0.05), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOut));
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(offsetTween),
                    child: child,
                  ),
                );
              },
              child: isOpen
                  ? Container(
                key: const ValueKey('open'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                decoration: BoxDecoration(
                  color: bodyBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 라인 목록
                    ...o.lines.map(
                          (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: violet, // 포인트 바이올렛 불릿
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ItemLabel(
                                      itemId: line.itemId,
                                      full: false, // shortLabel 포맷
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      autoNavigate:
                                      true, // 탭 시 아이템 상세 이동(원치 않으면 false)
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '· ${line.qty}개',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
