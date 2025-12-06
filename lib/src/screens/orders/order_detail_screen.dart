import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import 'order_form_screen.dart';
import '../../utils/item_presentation.dart';

// ⛳ 개별 품목 부족분 모달 (정적 show 사용)
import '../bom/shortage_result_screen.dart';
// ⛳ 전체 주문 품목 부족분 결과 화면
import '../bom/order_shortage_result_screen.dart';

import '../../repos/timeline_repo.dart';
import 'widgets/order_timeline.dart';

import '../../models/work.dart';
import '../../models/types.dart';
import '../works/work_detail_screen.dart';
import '../works/widgets/work_row.dart';
import '../../services/inventory_service.dart';
import '../../models/txn.dart'; // ✅ Txn, TxnType, TxnStatus

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  TimelineData? _timeline;
  bool _tlLoading = false;
  bool _busy = false; // 주문 완료 처리 중 여부

  final ScrollController _mainScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _reload(); // 진입 시 최신화(옵션)
    _loadTimeline(); // 👈 타임라인 로드
  }

  @override
  void dispose() {
    _mainScroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final orderRepo = context.read<OrderRepo>();
    // 프로젝트에서 sync면 await 제거
    final latest = await orderRepo.getOrder(_order.id);
    if (!mounted) return;
    if (latest == null) return;
    setState(() => _order = latest);
    // 주문 편집 후에도 타임라인 갱신
    await _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _tlLoading = true);
    try {
      final tlRepo = context.read<TimelineRepo>();
      final data = await tlRepo.fetchOrderTimeline(_order.id);
      if (!mounted) return;
      setState(() {
        _timeline = data;
        _tlLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timeline = null;
        _tlLoading = false;
      });
      debugPrint('[TL][ERROR] $e');
    }
  }

  Future<void> _goEdit() async {
    final editedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(orderId: _order.id),
      ),
    );
    // 편집 화면에서 저장 시 pop(context, orderId)로 반환한다고 가정
    if (editedId != null && editedId.isNotEmpty) {
      await _reload();
    }
  }

  Future<void> _markAsDone() async {
    if (_busy) return;

    // 미리 캡처 (dialog 안팎 context 혼용 방지)
    final repo = context.read<OrderRepo>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('완료'),
        content: const Text('이 주문을 완료 처리할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('완료'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;

    setState(() => _busy = true);
    try {
      await repo.updateOrderStatus(_order.id, OrderStatus.done);
      if (!mounted) return;

      // 로컬 상태도 즉시 갱신 (리스트로 돌아가면 바로 반영됨)
      setState(() => _order = _order.copyWith(status: OrderStatus.done));
      messenger.showSnackBar(const SnackBar(content: Text('주문을 완료로 변경했어요.')));

      // 원하면 상세 유지 대신 아래 주석을 사용해 리스트로 돌아가기
      // Navigator.pop(context, 'done');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('완료 처리에 실패했습니다: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _order.status == OrderStatus.done; // ✅ 한곳에서 판단

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 상세'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: '편집', onPressed: _goEdit),
        ],
      ),
      body: SingleChildScrollView(
        controller: _mainScroll, // 전용 컨트롤러
        primary: false, // 반드시 false
        padding: const EdgeInsets.all(16),
        child: _buildOrderBody(context),
      ),
      bottomNavigationBar: (isDone)
          ? null
          : SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_circle),
              label: _busy ? const Text('처리중...') : const Text('완료'),
              onPressed: _busy ? null : _markAsDone,
            ),
          ),
        ),
      ),
    );
  }

  /// 단일 바디: 라인이 없을 일은 거의 없지만, 안전하게 안내만 표시
  Widget _buildOrderBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 주문 메타
        Text('고객명: ${_order.customer}'),
        Text('주문일: ${_order.date.toIso8601String().split("T").first}'),
        Row(
          children: [
            const Text('상태: '),
            Chip(
              backgroundColor: _statusColor(_order.status).withOpacity(.08),
              shape: StadiumBorder(
                side: BorderSide(color: _statusColor(_order.status).withOpacity(.35)),
              ),
              label: Text(
                _statusLabel(_order.status),
                style: TextStyle(
                  color: _statusColor(_order.status).shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 👇 타임라인 박스 (리스트 위로)
        Container(
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _tlLoading
              ? const Center(child: CircularProgressIndicator())
              : (_timeline == null
              ? const Center(child: Text('타임라인을 불러오지 못했어요.'))
              : OrderTimeline(data: _timeline!)),
        ),
        const SizedBox(height: 16),

        // ✅ 비스크롤 리스트 (바깥 SingleChildScrollView가 스크롤 담당)
        if (_order.lines.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _order.lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final line = _order.lines[index];
              return _buildLineCard(context, line.itemId, line.qty);
            },
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              '주문 라인이 없습니다',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

        const SizedBox(height: 16),
        // 전체 품목에 대해 한 번에 계산
        ElevatedButton.icon(
          icon: const Icon(Icons.assessment),
          label: const Text('전체 품목 부족분 계산'),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderShortageResultScreen(order: _order),
              ),
            );
            // 부족분 계산/생성 이후 타임라인 갱신
            await _loadTimeline();
          },
        ),
        const SizedBox(height: 8),
        Text(
          '각 품목 카드를 눌러 개별 부족분을 보거나, 전체 버튼으로 한 번에 계산할 수 있어요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  /// 개별 라인 카드
  Widget _buildLineCard(BuildContext context, String itemId, int qty) {
    final workRepo = context.read<WorkRepo>();
    final inv = context.read<InventoryService>();

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목영역
            Row(
              children: [
                Expanded(
                  child: ItemLabel(
                    itemId: itemId,
                    full: false, // 전체 경로까지 표시 (원하면 false)
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                    autoNavigate: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<int>(
              stream: context.read<ItemRepo>().watchCurrentQty(itemId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 6),
                    child: Chip(
                      label: Text('재고 확인 중...', style: TextStyle(color: Colors.grey)),
                      backgroundColor: Color(0xFFEFEFEF),
                    ),
                  );
                }
                final stock = snap.data!;
                final orderQty = qty;
                final shortage = (stock >= orderQty) ? 0 : (orderQty - stock);
                final isEnough = shortage == 0;
                final Color bg = isEnough ? Colors.green.shade50 : Colors.red.shade50;
                final Color fg = isEnough ? Colors.green.shade700 : Colors.red.shade700;
                final String label = isEnough
                    ? '충분 (주문 $orderQty / 현재고 $stock)'
                    : '부족 $shortage개 (주문 $orderQty / 현재고 $stock)';
                return Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: ActionChip(
                    backgroundColor: bg,
                    shape: StadiumBorder(side: BorderSide(color: fg.withOpacity(0.4))),
                    label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final workId = await ShortageResultScreen.show(
                        context,
                        orderId: _order.id,
                        finishedItemId: itemId,
                        orderQty: orderQty,
                      );
                      if (!context.mounted) return;
                      if (workId != null && workId.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('작업이 생성되었습니다.')),
                        );
                        await _reload();
                        await _loadTimeline();
                      }
                    },
                  ),
                );
              },
            ),

            // 액션
            Row(
              children: [
                const SizedBox(width: 8),
                FutureBuilder<bool>(
                  future: context.read<TxnRepo>().existsOutActual(
                    refType: 'order',
                    refId: _order.id,
                    itemId: itemId,
                  ),
                  builder: (context, snap) {
                    final shipped = snap.data ?? false; // 이미 출고됨?
                    final loading = snap.connectionState == ConnectionState.waiting;
                    final disabled = shipped || loading;

                    return FilledButton.icon(
                      icon: Icon(
                        shipped ? Icons.check_circle : Icons.local_shipping,
                        color: shipped ? Colors.grey.shade700 : null,
                      ),
                      label: Text(
                        shipped ? '출고 완료' : '주문 출고',
                        style: TextStyle(
                          color: shipped ? Colors.grey.shade700 : null,
                        ),
                      ),
                      onPressed: disabled
                          ? null
                          : () async {
                        try {
                          await inv.shipOrderLine(
                            orderId: _order.id,
                            itemId: itemId,
                            qty: qty,
                          );
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('출고가 처리되었어요.')),
                          );

                          // ✅ 재출고 방지 위해 FutureBuilder 다시 평가
                          await _loadTimeline();
                          (context as Element).markNeedsBuild();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('출고 실패: $e')),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 🔹 관련 작업 리스트 (이 주문  이 아이템)
            StreamBuilder<List<Work>>(
              stream: workRepo.watchWorksByOrderAndItem(_order.id, itemId),
              builder: (context, snap) {
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text('관련 작업', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    ListView.separated(
                      itemCount: list.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final w = list[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WorkRow(
                              w: w,
                              onStart: (w.status == WorkStatus.planned)
                                  ? () => inv.startWork(w.id)
                                  : null,
                              onDone: (w.status == WorkStatus.inProgress)
                                  ? () => inv.completeWork(w.id)
                                  : null,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WorkDetailScreen(work: w),
                                  ),
                                );
                              },
                            ),
                            ///입고기록
                            const SizedBox(height: 6),
                            const SizedBox(height: 6),
                            _WorkTxnList(refWorkId: w.id),

                            // 🔹 이 품목(아이템) 기준 출고 기록 (주문 한정)
                            const SizedBox(height: 6),
                            _ItemTxnListByOrder(itemId: itemId, orderId: _order.id),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

class _WorkTxnList extends StatelessWidget {
  final String refWorkId;
  const _WorkTxnList({required this.refWorkId});

  @override
  Widget build(BuildContext context) {
    final txns = context.read<TxnRepo>();
    return StreamBuilder<List<Txn>>(
      stream: txns.watchTxnsByRef(refType: 'work', refId: refWorkId),
      builder: (context, snap) {
        final list = (snap.data ?? const []);
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text('기록 없음', style: Theme.of(context).textTheme.bodySmall),
          );
        }
        // ✅ 시간 오름차순 + 최대 5개
        final show = [...list]..sort((a, b) => a.ts.compareTo(b.ts));
        final limited = show.take(5).toList();

        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: limited.length,
              separatorBuilder: (_, __) => const Divider(height: 8, color: Colors.transparent),
              itemBuilder: (_, i) {
                final t = limited[i];
                final isIn = t.type == TxnType.in_;
                final sign = isIn ? '+' : '-';

                // 칩 색상 결정
                Color color;
                if (isIn && t.status == TxnStatus.planned) {
                  // 입고/예약 → 회색 칩
                  color = Colors.grey;
                } else if (isIn) {
                  // 입고/실거래 → 초록
                  color = Colors.green;
                } else {
                  // 출고(예약/실거래) → 빨강
                  color = Colors.red;
                }
                final status = (t.status == TxnStatus.actual) ? '실제' : '예약';
                final ts = _fmtTs(t.ts);
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(.3)),
                      ),
                      child: Text(
                        '${t.type == TxnType.in_ ? '입고' : '출고'}/$status',
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$sign${t.qty}  •  $ts',
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (list.length > 5) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: 필요하면 상세 화면으로 이동 (ref=workId 필터)
                  },
                  child: const Text('더보기'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _fmtTs(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$mi';
  }
}

/// ✅ 아이템+주문 기준 입출고 리스트 (refType='order' 로 좁혀서)
class _ItemTxnListByOrder extends StatelessWidget {
  final String itemId;
  final String orderId;
  const _ItemTxnListByOrder({required this.itemId, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final txns = context.read<TxnRepo>();
    return StreamBuilder<List<Txn>>(
      stream: txns.watchTxnsByRef(
        refType: 'order',
        refId: orderId,
        itemId: itemId, // ← 있으면 이 품목만
      ),
      builder: (context, snap) {
        final list = (snap.data ?? const []);
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text('기록 없음', style: Theme.of(context).textTheme.bodySmall),
          );
        }

        // 버튼 누른 순서대로
        final show = [...list]..sort((a, b) => b.ts.compareTo(a.ts));
        final visibleCount = show.length > 5 ? 5 : show.length; // clamp의 num → int 문제 회피

        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleCount,
              separatorBuilder: (_, __) => const Divider(height: 8, color: Colors.transparent),
              itemBuilder: (_, i) {
                final t = show[i];
                final isIn = (t.type == TxnType.in_);
                final sign = isIn ? '+' : '-';
                final MaterialColor color = isIn ? Colors.green : Colors.red;
                final status = (t.status == TxnStatus.actual) ? '실제' : '예약';
                final ts = _fmtTs(t.ts);

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(.3)),
                      ),
                      child: Text(
                        '${isIn ? '입고' : '출고'}/$status',
                        style: TextStyle(fontSize: 12, color: color.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$sign${t.qty}  •  $ts',
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (list.length > 5)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () {
                      // TODO: 필요하면 아이템+주문 기준 상세 화면으로 이동
                    },
                    child: const Text('더보기')),
              ),
          ],
        );
      },
    );
  }
}

String _fmtTs(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd $hh:$mi';
}

/// --- UI 전용 헬퍼: 저장값은 그대로 두고 라벨만 바꿔서 보여주기 ---
String _statusLabel(OrderStatus s) {
  // 내부 값은 draft지만, 화면에는 "진행중"으로만 표시
  switch (s) {
    case OrderStatus.draft:
      return '진행중';
    case OrderStatus.inProgress:
      return '진행중';
    case OrderStatus.done:
      return '완료';
    case OrderStatus.planned:
      return '계획';
  }
}

MaterialColor _statusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.done:
      return Colors.green;
    case OrderStatus.inProgress:
    case OrderStatus.draft: // draft도 진행중 컬러로
      return Colors.blue;
    case OrderStatus.planned:
      return Colors.amber;
  }
}
