import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import 'order_form_screen.dart';
import '../../utils/item_presentation.dart';

// ⛳ 개별 품목 부족분 모달
import '../bom/shortage_result_screen.dart';
// ⛳ 전체 주문 품목 부족분 결과 화면
import '../bom/order_shortage_result_screen.dart';

import '../../repos/timeline_repo.dart';
import 'widgets/order_timeline.dart';

import '../../models/work.dart';
import '../../models/types.dart';
import '../works/widgets/work_row.dart';
import '../works/work_detail_view.dart';
import '../works/work_detail_screen.dart';
import '../works/work_action_view.dart';
import 'order_line_edit_sheet.dart';

import '../../services/inventory_service.dart';
import '../../models/txn.dart'; // ✅ Txn, TxnType, TxnStatus

enum _SheetAction { toInProgress, toDone, cancel, restore }

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order; // ✅ orderId로 로드
  TimelineData? _timeline;
  bool _tlLoading = false;
  bool _loading = true;
  bool _busy = false; // 주문 완료/상태변경 처리 중 여부

  final ScrollController _mainScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _reload(); // 진입 시 최신화
  }

  @override
  void dispose() {
    _mainScroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final orderRepo = context.read<OrderRepo>();
    final latest = await orderRepo.getOrder(widget.orderId);

    if (!mounted) return;
    setState(() {
      _order = latest;
      _loading = false;
    });

    if (latest != null) {
      await _loadTimeline();
    }
  }

  Future<void> _loadTimeline() async {
    final o = _order;
    if (o == null) return;

    setState(() => _tlLoading = true);
    try {
      final tlRepo = context.read<TimelineRepo>();
      final data = await tlRepo.fetchOrderTimeline(o.id);
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
    final o = _order;
    if (o == null) return;

    final editedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(orderId: o.id),
      ),
    );

    if (editedId != null && editedId.isNotEmpty) {
      await _reload();
    }
  }

  Future<void> _markAsDone() async {
    final o = _order;
    if (o == null) return;
    if (_busy) return;

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
      await repo.updateOrderStatus(o.id, OrderStatus.done);
      if (!mounted) return;

      setState(() => _order = o.copyWith(status: OrderStatus.done));
      messenger.showSnackBar(const SnackBar(content: Text('주문을 완료로 변경했어요.')));
      await _loadTimeline();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('완료 처리에 실패했습니다: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return  Scaffold(
        appBar: AppBar(title: Text('주문 상세')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final o = _order;
    if (o == null) {
      return Scaffold(
        appBar: AppBar(title: Text('주문 상세')),
        body: Center(child: Text('주문을 찾을 수 없어요.')),
      );
    }

    final isDone = o.status == OrderStatus.done;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 상세'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: '편집', onPressed: _goEdit),
        ],
      ),
      body: SingleChildScrollView(
        controller: _mainScroll,
        primary: false,
        padding: const EdgeInsets.all(16),
        child: _buildOrderBody(context, o),
      ),
      bottomNavigationBar: (isDone || o.isDeleted)
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

  Widget _buildOrderBody(BuildContext context, Order o) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('고객명: ${o.customer}'),
        Text('주문일: ${o.date.toIso8601String().split("T").first}'),
        Row(
          children: [
            const Text('상태: '),
            Tooltip(
              message: o.isDeleted ? '길게 눌러 “취소 복구”' : '길게 눌러 상태 선택',
              child: GestureDetector(
                onLongPress: _busy ? null : _openStatusSheet,
                child: Chip(
                  backgroundColor: _overallColor(o).withOpacity(.08),
                  shape: StadiumBorder(
                    side: BorderSide(color: _overallColor(o).withOpacity(.35)),
                  ),
                  label: Text(
                    _overallLabel(o),
                    style: TextStyle(
                      color: _overallColor(o).shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 타임라인
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

        // 라인 리스트
        if (o.lines.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: o.lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final line = o.lines[index];
              return _buildLineCard(context, o, line);
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

        ElevatedButton.icon(
          icon: const Icon(Icons.assessment),
          label: const Text('전체 품목 부족분 계산'),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderShortageResultScreen(order: o),
              ),
            );
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

  Widget _buildLineCard(BuildContext context, Order o, OrderLine line) {
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
            // 제목
            Row(
              children: [
                Expanded(
                  child: ItemLabel(
                    itemId: line.itemId,
                    full: false,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                    autoNavigate: true,
                  ),

                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () async{
                    final result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => OrderLineEditSheet(
                      orderId: o.id,
                      lineId: line.id,
                      itemId: line.itemId,
                      qty: line.qty,
                    ),
                  );

                  if (result == true) {
                    await _reload();
                  }

                  },
                ),

              ],
            ),
            const SizedBox(height: 10),

            // 부족분 칩
            StreamBuilder<int>(
              stream: context.read<ItemRepo>().watchCurrentQty(line.itemId),
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
                final orderQty = line.qty;
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
                        orderId: o.id,
                        finishedItemId: line.itemId,
                        orderQty: orderQty,
                      );
                      if (!context.mounted) return;
                      if (workId != null && workId.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('작업이 생성되었습니다.')),
                        );
                        await _reload();
                      }
                    },
                  ),
                );
              },
            ),

            // 출고 버튼
            Row(
              children: [
                const SizedBox(width: 8),
                FutureBuilder<bool>(
                  future: context.read<TxnRepo>().existsOutActual(
                    refType: 'order',
                    refId: o.id,
                    itemId: line.itemId,
                  ),
                  builder: (context, snap) {
                    final shipped = snap.data ?? false;
                    final loading = snap.connectionState == ConnectionState.waiting;
                    final disabled = shipped || loading;

                    return FilledButton.icon(
                      icon: Icon(
                        shipped ? Icons.check_circle : Icons.local_shipping,
                        color: shipped ? Colors.grey.shade700 : null,
                      ),
                      label: Text(
                        shipped ? '출고 완료' : '주문 출고',
                        style: TextStyle(color: shipped ? Colors.grey.shade700 : null),
                      ),
                      onPressed: disabled
                          ? null
                          : () async {
                        try {
                          await inv.shipOrderLine(
                            orderId: o.id,
                            itemId: line.itemId,
                            qty: line.qty,
                          );
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('출고가 처리되었어요.')),
                          );

                          await _loadTimeline();
                          if (mounted) setState(() {});
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

            // 관련 작업 리스트
    StreamBuilder<List<Work>>(
    stream: workRepo.watchWorksByOrder(o.id),
    builder: (context, snap) {
    final all = snap.data ?? const <Work>[];
    final list = all.where((w) => w.itemId == line.itemId).toList();

    if (list.isEmpty) return const SizedBox.shrink();

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
    WorkActionView(workId: w.id, embedded: true),
    const SizedBox(height: 8),
    _WorkTxnList(refWorkId: w.id),
    const SizedBox(height: 6),
    _ItemTxnListByOrder(itemId: line.itemId, orderId: o.id),
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

  Future<void> _openStatusSheet() async {
    final o = _order;
    if (o == null) return;

    final actions = <_SheetAction>[
      if (o.isDeleted)
        _SheetAction.restore
      else ...[
        if (o.status == OrderStatus.done) _SheetAction.toInProgress else _SheetAction.toDone,
        _SheetAction.cancel,
      ]
    ];

    final picked = await showModalBottomSheet<_SheetAction>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('상태 선택', style: Theme.of(c).textTheme.titleMedium),
              ),
              ...actions.map((a) {
                final (icon, title, desc, color) = switch (a) {
                  _SheetAction.toInProgress => (Icons.play_arrow, '진행중', '작업/출고 등 처리 중 상태', Colors.blue),
                  _SheetAction.toDone => (Icons.check_circle, '완료', '모든 출고가 끝난 상태', Colors.green),
                  _SheetAction.cancel => (Icons.cancel, '취소', '주문을 소프트 삭제(복구 가능)', Colors.red),
                  _SheetAction.restore => (Icons.settings_backup_restore, '취소 복구', '취소된 주문을 되살립니다', Colors.blueGrey),
                };
                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(title, style: TextStyle(color: color.shade700)),
                  subtitle: Text(desc),
                  onTap: () => Navigator.pop(c, a),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || picked == null) return;

    final from = _overallLabel(o);
    final to = switch (picked) {
      _SheetAction.toInProgress => _statusLabel(OrderStatus.draft),
      _SheetAction.toDone => _statusLabel(OrderStatus.done),
      _SheetAction.cancel => '취소됨',
      _SheetAction.restore => _statusLabel(o.status),
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('확인'),
        content: Text('“$from” → “$to”로 변경할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('변경')),
        ],
      ),
    );
    if (ok != true) return;

    switch (picked) {
      case _SheetAction.toInProgress:
        await _setStatus(OrderStatus.draft);
        break;
      case _SheetAction.toDone:
        await _setStatus(OrderStatus.done);
        break;
      case _SheetAction.cancel:
        await _cancelOrder();
        break;
      case _SheetAction.restore:
        await _restoreOrder();
        break;
    }
  }

  Future<void> _setStatus(OrderStatus status) async {
    final o = _order;
    if (o == null) return;
    if (_busy || o.isDeleted) return;

    setState(() => _busy = true);
    try {
      final repo = context.read<OrderRepo>();
      await repo.updateOrderStatus(o.id, status);
      if (!mounted) return;

      setState(() => _order = o.copyWith(status: status));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태를 “${_statusLabel(status)}”로 변경했어요.')),
      );
      await _loadTimeline();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('상태 변경 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelOrder() async {
    final o = _order;
    if (o == null) return;
    if (_busy || o.isDeleted) return;

    setState(() => _busy = true);
    try {
      await context.read<OrderRepo>().softDeleteOrder(o.id);
      if (!mounted) return;

      setState(() => _order = o.copyWith(isDeleted: true, deletedAt: DateTime.now()));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문을 취소했어요.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('취소 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreOrder() async {
    final o = _order;
    if (o == null) return;
    if (_busy || !o.isDeleted) return;

    setState(() => _busy = true);
    try {
      await context.read<OrderRepo>().restoreOrder(o.id);
      if (!mounted) return;

      setState(() => _order = o.copyWith(isDeleted: false, deletedAt: null));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문을 복구했어요.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('복구 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

                Color color;
                if (isIn && t.status == TxnStatus.planned) {
                  color = Colors.grey;
                } else if (isIn) {
                  color = Colors.green;
                } else {
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
                  onPressed: () {},
                  child: const Text('더보기'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

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
        itemId: itemId,
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

        final show = [...list]..sort((a, b) => b.ts.compareTo(a.ts));
        final visibleCount = show.length > 5 ? 5 : show.length;

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
                child: TextButton(onPressed: () {}, child: const Text('더보기')),
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
    case OrderStatus.draft:
      return Colors.blue;
    case OrderStatus.planned:
      return Colors.amber;
  }
}

String _overallLabel(Order o) => o.isDeleted ? '취소됨' : _statusLabel(o.status);
MaterialColor _overallColor(Order o) => o.isDeleted ? Colors.red : _statusColor(o.status);
