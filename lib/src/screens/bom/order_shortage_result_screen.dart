import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/bom_service.dart';
import '../../services/shortage_service.dart';

class OrderShortageResultScreen extends StatefulWidget {
  final Order order;
  const OrderShortageResultScreen({super.key, required this.order});

  @override
  State<OrderShortageResultScreen> createState() => _OrderShortageResultScreenState();
}

class _OrderShortageResultScreenState extends State<OrderShortageResultScreen> {
  late Future<_Vm> _future;
  final Set<int> _expanded = {}; // 펼쳐진 인덱스들
  bool _allExpanded = true;      // 모두 펼치기 / 접기 토글

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Vm> _load() async {
    final items = context.read<ItemRepo>();
    final bom = BomService(items); // BomService는 ItemRepo 기반

    int _ceil(double v) => v == v.floorToDouble() ? v.toInt() : v.ceil();

    List<_LineVm> lines = [];
    for (var i = 0; i < widget.order.lines.length; i++) {
      final ln = widget.order.lines[i];
      final finishedId = ln.itemId; // 프로젝트 구조상 필요한 필드명으로 조정(예: finishedItemId)
      final qty = ln.qty;

      final s = ShortageService(repo: items, bom: bom)
          .compute(finishedId: finishedId, orderQty: qty);

      List<_RowVm> toRows(Map<String, double> need, Map<String, double> short) {
        final out = <_RowVm>[];
        for (final id in need.keys) {
          final n = need[id] ?? 0.0;
          final sh = short[id] ?? 0.0;
          if (n > 0) out.add(_RowVm(itemId: id, need: _ceil(n), shortage: _ceil(sh)));
        }
        out.sort((a, b) => a.itemId.compareTo(b.itemId));
        return out;
      }

      final finStockNum = items.stockOf(finishedId);
      final finStock = (finStockNum is int) ? finStockNum : (finStockNum as num).toInt();

      lines.add(_LineVm(
        index: i,
        finishedItemId: finishedId,
        orderQty: qty,
        finishedStock: finStock,
        finishedShortage: s.finishedShortage,
        semi: toRows(s.semiNeed, s.semiShortage),
        raw:  toRows(s.rawNeed,  s.rawShortage),
        sub:  toRows(s.subNeed,  s.subShortage),
      ));
    }

    return _Vm(lines: lines);
  }

  void _toggleAll(bool expandAll, int count) {
    setState(() {
      _allExpanded = expandAll;
      _expanded.clear();
      if (expandAll) {
        for (int i = 0; i < count; i++) {
          _expanded.add(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('부족분 계산 결과'),
        actions: [
          IconButton(
            tooltip: _allExpanded ? '모두 접기' : '모두 펼치기',
            icon: Icon(_allExpanded ? Icons.unfold_less : Icons.unfold_more),
            onPressed: () async {
              final vm = await _future;
              _toggleAll(!_allExpanded, vm.lines.length);
            },
          ),
        ],
      ),
      body: FutureBuilder<_Vm>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final vm = snap.data!;
          if (vm.lines.isEmpty) {
            return const Center(child: Text('주문 품목이 없습니다.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 24.0),
            itemCount: vm.lines.length,
            itemBuilder: (context, i) {
              final ln = vm.lines[i];
              final expanded = _expanded.contains(i);
              final danger = ln.finishedShortage > 0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  initiallyExpanded: _allExpanded,
                  onExpansionChanged: (v) {
                    setState(() {
                      if (v) { _expanded.add(i); } else { _expanded.remove(i); }
                    });
                  },
                  title: Row(
                    children: [
                      const Icon(Icons.shopping_bag),
                      const SizedBox(width: 8.0),
                      Expanded(
                        // ItemLabel이 있다면 여기서 교체 가능
                        child: Text(ln.finishedItemId, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8.0),
                      _Badge(label: '주문', value: '${ln.orderQty}'),
                      const SizedBox(width: 8.0),
                      _Badge(label: '재고', value: '${ln.finishedStock}'),
                      const SizedBox(width: 8.0),
                      _Badge(
                        label: '부족',
                        value: '${ln.finishedShortage}',
                        tone: danger ? BadgeTone.danger : BadgeTone.ok,
                      ),
                    ],
                  ),
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Section(title: '세미 구성 필요/부족', rows: ln.semi, emptyLabel: '세미 필요 없음'),
                          const SizedBox(height: 10.0),
                          _Section(title: '원자재 필요/부족', rows: ln.raw,  emptyLabel: '원자재 필요 없음'),
                          const SizedBox(height: 10.0),
                          _Section(title: '부자재 필요/부족', rows: ln.sub,  emptyLabel: '부자재 필요 없음'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_RowVm> rows;
  final String emptyLabel;
  const _Section({required this.title, required this.rows, required this.emptyLabel});

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
  final _RowVm vm;
  const _NeedShortRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final danger = vm.shortage > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, size: 18.0),
          const SizedBox(width: 8.0),
          Expanded(child: Text(vm.itemId, overflow: TextOverflow.ellipsis)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8.0)),
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

class _RowVm {
  final String itemId;
  final int need;
  final int shortage;
  const _RowVm({required this.itemId, required this.need, required this.shortage});
}

class _LineVm {
  final int index;
  final String finishedItemId;
  final int orderQty;
  final int finishedStock;
  final double finishedShortage;
  final List<_RowVm> semi;
  final List<_RowVm> raw;
  final List<_RowVm> sub;

  const _LineVm({
    required this.index,
    required this.finishedItemId,
    required this.orderQty,
    required this.finishedStock,
    required this.finishedShortage,
    required this.semi,
    required this.raw,
    required this.sub,
  });
}

class _Vm {
  final List<_LineVm> lines;
  const _Vm({required this.lines});
}
