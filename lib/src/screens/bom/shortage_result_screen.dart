// lib/src/screens/bom/shortage_result_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart';
import '../../services/shortage_service.dart';
import '../../services/bom_service.dart';
import '../../utils/item_presentation.dart'; // ✅ 추가


/// 주문 상세에서 호출하는 "부족분 결과" 모달
class ShortageResultScreen extends StatefulWidget {
  final String orderId;
  final String finishedItemId;
  final int orderQty;

  const ShortageResultScreen({
    required this.orderId,
    super.key,
    required this.finishedItemId,
    required this.orderQty,
  });

  static Future<String?> show(
      BuildContext context, {
        required String orderId,
        required String finishedItemId,
        required int orderQty,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ShortageResultScreen(
          orderId: orderId,
          finishedItemId: finishedItemId,
          orderQty: orderQty,
        ),
      ),
    );
  }

  @override
  State<ShortageResultScreen> createState() => _ShortageResultScreenState();
}

class _ShortageResultScreenState extends State<ShortageResultScreen> {
  late Future<_Vm> _future;
  bool _creating = false;



  Future<String?> _findExistingWorkId() async {
    final repo = context.read<WorkRepo>();
    final existing = await repo.findWorkForOrderLine(widget.orderId, widget.finishedItemId);
    return existing?.id;
  }


  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Vm> _load() async {

        final items = context.read<ItemRepo>(); // ItemRepo 하나면 충분
        // BomService는 ItemRepo를 요구 (stockOf  BOM 조회를 한 repo에서 처리)
        final bom = BomService(items);
    final shortage = ShortageService(repo: items, bom: bom)
        .compute(finishedId: widget.finishedItemId, orderQty: widget.orderQty);

    // 필요/부족 수량 표시는 올림(ceil)
    int _ceil(double v) => v == v.floorToDouble() ? v.toInt() : v.ceil();

        // ✅ 어떤 타입/널이 와도 안전하게 int로 변환
        int _toInt(Object? v, {int fallback = 0}) {
          if (v is int) return v;
          if (v is num) return v.toInt();
          return fallback; // v == null 이면 0
        }
    List<RowVm> toRows(Map<String, double> need, {Map<String, double>? short}) {
      return need.keys.map((id) {
        final n = need[id] ?? 0.0;
        final s = short != null ? (short[id] ?? 0.0) : 0.0;
        final stock = _toInt(items.stockOf(id)); // ✅ 널/타입 방어

        return RowVm(itemId: id, need: _ceil(n), shortage: _ceil(s), stock: stock, );
      }).where((r) => r.need > 0).toList()
        ..sort((a, b) => a.itemId.compareTo(b.itemId));
    }

    final semiRows = toRows(shortage.semiNeed, short: shortage.semiShortage);
    final rawRows  = toRows(shortage.rawNeed,  short: shortage.rawShortage);
    final subRows  = toRows(shortage.subNeed,  short: shortage.subShortage);

    // finished 현재고 (num → int 안전 변환)
    final finStockNum = items.stockOf(widget.finishedItemId);
       // ✅ 완제품 현 재고도 방어
        final finStock = _toInt(items.stockOf(widget.finishedItemId));

    return _Vm(
      orderId: widget.orderId,
      finishedItemId: widget.finishedItemId,
      orderQty: widget.orderQty,
      finishedStock: finStock,
      finishedShortage: shortage.finishedShortage,
      semi: semiRows,
      raw: rawRows,
      sub: subRows,
    );
  }


  Future<void> _confirmAndCreateWork({
      required int shortageQty,
    }) async {
    if (shortageQty <= 0 || _creating) return;

      // 🔎 이미 생성된 작업 있는지 먼저 확인
      final existingId = await _findExistingWorkId();
      if (existingId != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 이 주문에 대한 작업이 생성되었습니다.')),
        );
        // 원하면 기존 작업으로 바로 연결할 수 있게 반환
        Navigator.of(context).pop(existingId); // ← 주문상세가 받으면 타임라인 갱신 가능
        return;
      }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => _ConfirmSheet(
        title: '작업을 생성할까요?',
        body: '완제품 부족 $shortageQty개에 대해 작업을 생성합니다.',
        okText: '작업 생성',
      ),
    );
    if (ok != true) return;

    setState(() => _creating = true);
    try {
      final repo = context.read<WorkRepo>();
      final workId = await repo.createWorkForOrder(
        orderId: widget.orderId,
        itemId: widget.finishedItemId,
        qty: shortageQty,
      );
      if (!mounted) return;
      Navigator.of(context).pop(workId); // ← 호출자(OrderDetail)로 workId 반환
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('작업 생성 실패: $e')),
      );
      setState(() => _creating = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_Vm>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('오류: ${snap.error}', style: TextStyle(color: Colors.red)),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final vm = snap.data!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  children: [
                    const Icon(Icons.calculate),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text('부족분 계산', style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // 대상 완제품 (ItemLabel 대체: 우선 ID 출력)
                Row(
                  children: [
                    const Text('대상: '),
             Expanded(
                   child: ItemLabel(
                     itemId: vm.finishedItemId,
                     full: false,                 // 전체 경로 포함 (원하면 false)
                     maxLines: 2,                // 두 줄 허용
                     softWrap: true,
                     overflow: TextOverflow.ellipsis,
                     style: theme.textTheme.titleMedium,
                     autoNavigate: true,
                   ),
             ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // 요약 뱃지
                Wrap(
                  spacing: 12.0,
                  runSpacing: 8.0,
                  children: [
                    _Badge(label: '주문수량', value: '${vm.orderQty}'),
                    _Badge(label: '현재고', value: '${vm.finishedStock}'),
            GestureDetector(
                   onTap: vm.finishedShortage > 0
                       ? () => _confirmAndCreateWork(shortageQty: (vm.finishedShortage.ceil()))
               : null,
           child: _Badge(
             label: '부족(완제품)',
             value: '${vm.finishedShortage}',
             tone: vm.finishedShortage > 0 ? BadgeTone.danger : BadgeTone.ok,
           ),
         ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const Divider(),

                _Section(title: '세미 구성 필요/부족', rows: vm.semi, emptyLabel: '세미 필요 없음'),
                const SizedBox(height: 8.0),
                _Section(title: '원자재 필요/부족', rows: vm.raw,  emptyLabel: '원자재 필요 없음'),
                const SizedBox(height: 8.0),
                _Section(title: '부자재 필요/부족', rows: vm.sub,  emptyLabel: '부자재 필요 없음'),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<RowVm> rows;
  final String emptyLabel;

  const _Section({
    required this.title,
    required this.rows,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6.0),
        if (rows.isEmpty)
          Text(emptyLabel, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))
        else
          ...rows.map((r) => _NeedShortRow(vm: r)),
      ],
    );
  }
}

class _NeedShortRow extends StatelessWidget {
  final RowVm vm;
  const _NeedShortRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = vm.shortage > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1줄: 아이템 아이콘 + 이름
          Row(
            children: [
              const Icon(Icons.inventory_2, size: 18.0),
              const SizedBox(width: 8.0),
              Expanded(
                child: ItemLabel(
                  itemId: vm.itemId,
                  full: false,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  autoNavigate: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6.0),

          // 2줄: 수치 배지들 (여러 줄로 자동 개행)
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: [
              _Badge(label: '현재고', value: '${vm.stock}'),
              _Badge(label: '필요',   value: '${vm.need}'),
              _Badge(
                label: '부족',
                value: '${vm.shortage}',
                tone: danger ? BadgeTone.danger : BadgeTone.ok,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


enum BadgeTone { ok, danger }

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final BadgeTone tone;
  const _Badge({required this.label, required this.value, this.tone = BadgeTone.ok});

  @override
  Widget build(BuildContext context) {
    final bg = tone == BadgeTone.ok ? Colors.teal.withOpacity(0.15) : Colors.red.withOpacity(0.15);
    final fg = tone == BadgeTone.ok ? Colors.teal.shade800 : Colors.red.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: fg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6.0),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class RowVm {
  final String itemId;
  final int need;
  final int shortage;
  final int stock; // ✅ 추가
  const RowVm({required this.itemId, required this.need, required this.shortage, required this.stock, });
}

class _Vm {
  final String orderId;
  final String finishedItemId;
  final int orderQty;
  final int finishedStock;
  final double finishedShortage;
  final List<RowVm> semi;
  final List<RowVm> raw;
  final List<RowVm> sub;

  const _Vm({
    required this.orderId,
    required this.finishedItemId,
    required this.orderQty,
    required this.finishedStock,
    required this.finishedShortage,
    required this.semi,
    required this.raw,
    required this.sub,

  });
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.title, required this.body, required this.okText});
  final String title, body, okText;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 16),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(okText)),
          ]),
        ]),
      ),
    );
  }
}

