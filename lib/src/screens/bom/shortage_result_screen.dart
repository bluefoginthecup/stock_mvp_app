// lib/src/screens/bom/shortage_result_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart';
import '../../services/shortage_service.dart';
import '../../services/bom_service.dart';

/// 주문 상세에서 호출하는 "부족분 결과" 모달
class ShortageResultScreen extends StatefulWidget {
  final String finishedItemId;
  final int orderQty;

  const ShortageResultScreen({
    super.key,
    required this.finishedItemId,
    required this.orderQty,
  });

  static Future<void> show(
      BuildContext context, {
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

    List<RowVm> toRows(Map<String, double> need, {Map<String, double>? short}) {
      return need.keys.map((id) {
        final n = need[id] ?? 0.0;
        final s = short != null ? (short[id] ?? 0.0) : 0.0;
        return RowVm(itemId: id, need: _ceil(n), shortage: _ceil(s));
      }).where((r) => r.need > 0).toList()
        ..sort((a, b) => a.itemId.compareTo(b.itemId));
    }

    final semiRows = toRows(shortage.semiNeed, short: shortage.semiShortage);
    final rawRows  = toRows(shortage.rawNeed,  short: shortage.rawShortage);
    final subRows  = toRows(shortage.subNeed,  short: shortage.subShortage);

    // finished 현재고 (num → int 안전 변환)
    final finStockNum = items.stockOf(widget.finishedItemId);
    final finStock = (finStockNum is int) ? finStockNum : (finStockNum as num).toInt();

    return _Vm(
      finishedItemId: widget.finishedItemId,
      orderQty: widget.orderQty,
      finishedStock: finStock,
      finishedShortage: shortage.finishedShortage,
      semi: semiRows,
      raw: rawRows,
      sub: subRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_Vm>(
      future: _future,
      builder: (context, snap) {
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
                      child: Text(
                        vm.finishedItemId,
                        overflow: TextOverflow.ellipsis,
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
                    _Badge(
                      label: '부족(완제품)',
                      value: '${vm.finishedShortage}',
                      tone: vm.finishedShortage > 0 ? BadgeTone.danger : BadgeTone.ok,
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
    final danger = vm.shortage > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, size: 18.0),
          const SizedBox(width: 8.0),

          // ItemLabel 대체: 우선 ID 텍스트
          Expanded(
            child: Text(
              vm.itemId,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8.0),
          Text('필요 ${vm.need}'),
          const SizedBox(width: 10.0),
          _Badge(
            label: '부족',
            value: '${vm.shortage}',
            tone: danger ? BadgeTone.danger : BadgeTone.ok,
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
  const RowVm({required this.itemId, required this.need, required this.shortage});
}

class _Vm {
  final String finishedItemId;
  final int orderQty;
  final int finishedStock;
  final int finishedShortage;
  final List<RowVm> semi;
  final List<RowVm> raw;
  final List<RowVm> sub;

  const _Vm({
    required this.finishedItemId,
    required this.orderQty,
    required this.finishedStock,
    required this.finishedShortage,
    required this.semi,
    required this.raw,
    required this.sub,
  });
}
