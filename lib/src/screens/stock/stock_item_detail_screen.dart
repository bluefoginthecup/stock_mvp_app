// lib/src/screens/stock/stock_item_detail_screen.dart
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../models/lot.dart';                // 🔧 Lot 모델 (Practical-MIN)
import '../../repos/inmem_repo.dart';          // 🔧 InMemoryRepo(FIFO/lot upsert)
import '../../repos/repo_interfaces.dart';

import '../../ui/common/ui.dart';
import '../../utils/item_presentation.dart';   // ItemLabel

import '../bom/finished_bom_edit_screen.dart';
import '../bom/semi_bom_edit_screen.dart';

import '../txns/adjust_form.dart';
import '../../ui/common/qty_control.dart';
import '../../models/txn.dart' show Txn;
import '../txns/widgets/txn_row.dart';         // ← 프로젝트 실제 경로로 맞춰주세요
import 'stock_in_dialog.dart';

import '../../dev/bom_debug.dart';             // 콘솔 덤프 유틸

class StockItemDetailScreen extends StatefulWidget {
  final String itemId;
  const StockItemDetailScreen({super.key, required this.itemId});

  @override
  State<StockItemDetailScreen> createState() => _StockItemDetailScreenState();
}

class _StockItemDetailScreenState extends State<StockItemDetailScreen> {
  Item? _item;
  String? _name;              // 사람 읽는 이름 (repo.nameOf)
  bool? _isFinished;          // finished/semi 추정
  bool _isLot = false;        // 🔧 Practical-MIN: 롤 관리 모드 여부

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final itemRepo = context.read<ItemRepo>();
    final item = await itemRepo.getItem(widget.itemId);
    final name = await itemRepo.nameOf(widget.itemId);

    bool? finishedGuess;
    if (item != null) {
      // 레거시 폴더 체계로 finished/semi 추정 (없으면 null)
      final segs = <String>[
        item.folder,
        if (item.subfolder != null) item.subfolder!,
        if (item.subsubfolder != null) item.subsubfolder!,
      ].map((e) => e.toLowerCase());
      final joined = segs.join('/');
      if (joined.contains('finished') || joined.contains('완제품')) {
        finishedGuess = true;
      } else if (joined.contains('semi') || joined.contains('반제품') || joined.contains('세미')) {
        finishedGuess = false;
      }
    }

    // 🔧 Practical-MIN: conversionMode 로 롤 모드 판정
    bool isLot = false;
    if (item != null) {
      final mode = (item.conversionMode).toLowerCase();
      isLot = (mode == 'lot');
    }

    if (!mounted) return;
    setState(() {
      _item = item;
      _name = name ?? item?.name ?? widget.itemId;
      _isFinished = finishedGuess;
      _isLot = isLot;
    });
  }

  Future<void> _showRecentTxns() async {
    try {
      final txnRepo = context.read<TxnRepo>();
      final all = await txnRepo.listTxns();
      final List<Txn> filtered = all
          .cast<Txn>()
          .where((t) => t.itemId == widget.itemId)
          .toList();
      DateTime _ts(Txn x) =>
          x.ts ?? (x as dynamic).createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      filtered.sort((a, b) => _ts(b).compareTo(_ts(a)));

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) {
          if (filtered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.t.txn_list_empty_hint),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => TxnRow(t: filtered[i]),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최근 입출고 내역을 불러올 수 없습니다: $e')),
      );
    }
  }

  // ✅ 입출고 폼 열기(일반 모드)
  void _openAdjust() {
    if (_item == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(context.t.adjust_set_quantity_title)),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              child: AdjustForm(item: _item!),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ 표준: ItemRepo.adjustQty(itemId, delta, refType?, refId?, note?)
  Future<void> _applyQtyChange({required int delta, required int newQty}) async {
    final itemRepo = context.read<ItemRepo>();
    await itemRepo.adjustQty(
      itemId: _item!.id,
      delta: delta,
      refType: 'MANUAL',
      note: 'Detail:setQty ${_item!.qty} → $newQty',
    );
  }

  // ✅ "재고" 롱프레스 → 절대 수량 변경 시트
  Future<void> _openQtyChangeSheet() async {
    if (_item == null) return;
    final currentQty = _item!.qty;
    int localQty = currentQty;

    final newQty = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ctx.t.adjust_set_quantity_title,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  QtyControl(
                    value: localQty,
                    onChanged: (v) => setSB(() => localQty = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: Text(ctx.t.common_cancel),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        onPressed: () => Navigator.pop(ctx, localQty),
                        label: Text(ctx.t.btn_apply),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );

    if (newQty == null || newQty == currentQty) return;

    try {
      final delta = newQty - currentQty;
      await _applyQtyChange(delta: delta, newQty: newQty);
      await _load(); // 리프레시
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.btn_save)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.t.common_error}: $e')),
      );
      // ignore: avoid_print
      print('${context.t.common_error}: $e');
    }
  }

  // 시드 힌트 보기
  void _openSeedHintsSheet(Item it) {
    final h = it.stockHints;
    if (h == null) return;

    String fmt(num? v) {
      if (v == null) return '-';
      final s = v.toStringAsFixed(2);
      return s
          .replaceFirst(RegExp(r'\.0+$'), '')
          .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'\1');
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final unitOut = h.unitOut ?? it.unit;
        final hasConv = (h.unitIn != null && h.unitOut != null && h.conversionRate != null);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tips_and_updates),
                        const SizedBox(width: 8),
                        Text('Seed 재고 힌트', style: Theme.of(ctx).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (h.usableQtyM != null)
                          Chip(label: Text('가용 ${fmt(h.usableQtyM)} m')),
                        if (h.qty != null)
                          Chip(label: Text('Seed ${fmt(h.qty)} $unitOut')),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                _kv(ctx, 'Seed 수량', h.qty == null ? '-' : '${fmt(h.qty)} $unitOut'),
                _kv(ctx, '사용가능(m)', fmt(h.usableQtyM)),
                _kv(ctx, '출고 단위', unitOut),
                _kv(ctx, '입고 단위', h.unitIn ?? '-'),
                _kv(ctx, '환산식', hasConv ? '1 ${h.unitIn} = ${fmt(h.conversionRate)} ${h.unitOut}' : '-'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // 작은 key-value 줄
  Widget _kv(BuildContext ctx, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108, child: Text(k, style: Theme.of(ctx).textTheme.bodyMedium)),
        const SizedBox(width: 8),
        Expanded(child: Text(v, style: Theme.of(ctx).textTheme.bodyMedium)),
      ],
    ),
  );

  bool _hasHints(Item it) {
    final h = it.stockHints;
    if (h == null) return false;
    return h.qty != null ||
        h.usableQtyM != null ||
        h.conversionRate != null ||
        h.unitIn != null ||
        h.unitOut != null;
  }

  String _fmtNum(num? v, {int frac = 2}) {
    if (v == null) return '-';
    final s = v.toStringAsFixed(frac);
    return s
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'\1');
  }

  Widget _seedHintsCard(Item it) {
    final h = it.stockHints!;
    final unitOut = (h.unitOut ?? it.unit);
    final hasConv = (h.unitIn != null && h.unitOut != null && h.conversionRate != null);

    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seed 재고 힌트', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            kv('Seed 수량', h.qty == null ? '-' : '${_fmtNum(h.qty)} $unitOut'),
            kv('사용가능(m)', _fmtNum(h.usableQtyM)),
            kv('출고 단위', unitOut),
            kv('입고 단위', h.unitIn ?? '-'),
            kv('환산식', hasConv ? '1 ${h.unitIn} = ${_fmtNum(h.conversionRate)} ${h.unitOut}' : '-'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    final totalUsableM = context.select<InMemoryRepo, double>(
          (r) => r.lotsByItem(item!.id).fold<double>(0.0, (s, l) => s + l.usableQtyM),
    );
    final lotCount = context.select<InMemoryRepo, int>(
          (r) => r.lotsByItem(item!.id).length,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.t.stock_item_detail_title)),
      body: item == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이템 라벨 (경로/이름 표시)
              Row(
                children: [
                  const Icon(Icons.inventory_2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ItemLabel(
                      itemId: widget.itemId,
                      full: true,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                      separator: ' / ',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 재고 수량 / 단위
              Row(
                children: [
                  // ✅ 재고 칩 롱프레스: 수량 변경 시트
                  Tooltip(
                    message: context.t.hint_longpress_to_edit_qty,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onLongPress: _openQtyChangeSheet,
                      child: Chip(
                        avatar: const Icon(Icons.numbers, size: 16),
                        label: Text(_isLot
                            ? 'EA 재고: ${item.qty}'
                            : '${context.t.common_stock}: ${item.qty}'),

                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.straighten, size: 16),
                    label: Text('${context.t.item_unit}: ${item.unit}'),
                  ),
          if (_isLot) ...[
                           const SizedBox(width: 8),
                       Chip(
                         avatar: const Icon(Icons.linear_scale, size: 16),
                         label: Text('가용합계: ${_fmtNum(totalUsableM)} m'),
                       ),
                       const SizedBox(width: 8),
                       Chip(
                         avatar: const Icon(Icons.inventory, size: 16),
                         label: Text('롤: $lotCount개'),
                       ),
                     ],
                ],
              ),

              // ----- 롤 모드 전용 UI -----
              if (_isLot && item != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.swap_horiz, size: 16),
                      label: Text('입고→출고: ${(item.unitIn ?? '-')} → ${(item.unitOut ?? item.unit)}'),

                    ),
                    Chip(
                      avatar: const Icon(Icons.calculate, size: 16),
    label: Text(
                           (item.conversionRate == null)
                             ? '환산율: 롤별 실측'
                             : '환산율: 1 ${item.unitIn} = ${_fmtNum(item.conversionRate)} ${(item.unitOut ?? item.unit)}',
                         ),
                    ),
                    const Chip(
                      avatar: Icon(Icons.rule, size: 16),
                      label: Text('모드: 롤별 FIFO'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('롤 입고'),
                      onPressed: () => _openLotReceive(context, item.id),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload),
                      label: const Text('M 출고(FIFO)'),
                      onPressed: () => _openLotIssue(context, item.id),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _LotListInline(itemId: item.id),
                const SizedBox(height: 12),
              ],

              // ▶▶ SeedHints 배지/버튼 (있을 때만)
              if (_hasHints(item)) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tips_and_updates),
                    label: const Text('Seed 재고 힌트'),
                    onPressed: () => _openSeedHintsSheet(item),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('입출고 기록'),
                onPressed: _showRecentTxns,
              ),

              // ✅ BOM 편집 버튼 (완제품/반제품)
              if (_isFinished == true) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('BOM 편집 (완제품)'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinishedBomEditScreen(finishedItemId: widget.itemId),
                    ),
                  ),
                ),
              ] else if (_isFinished == false) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('BOM 편집 (반제품)'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SemiBomEditScreen(semiItemId: widget.itemId),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => BomDebug.dumpItemBomsToConsole(context, widget.itemId),
                icon: const Icon(Icons.terminal),
                label: const Text('BOM 콘솔 출력'),
              ),
            ],
          ),
        ),
      ),


    // 🔧 롤 모드에서는 하단 고정바 숨김(전용 모달 사용)
    bottomNavigationBar: _isLot
    ? null
        : SafeArea(
    child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Row(
    children: [
    Expanded(
    child: OutlinedButton.icon(
    icon: const Icon(Icons.remove),
    label: const Text('출고'),
    onPressed: (_item == null) ? null : _openAdjust,
    ),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: FilledButton.icon(
    icon: const Icon(Icons.add),
    label: const Text('입고'),
    onPressed: (_item == null)
    ? null
        : () async {
    final result = await showDialog(
    context: context,
    builder: (_) => StockInDialog(item: _item!),
    );
    if (result == null) return;

    final entered = result['enteredQtyIn'] as double;
    final isBulk = result['isBulk'] as bool;
    final conv = result['conversionRate'] as double;
    final unitIn = result['unitIn'] as String;
    final unitOut = result['unitOut'] as String;

    final qtyOutUnit = isBulk ? entered * conv : entered;

    final repo = context.read<ItemRepo>();
    await repo.adjustQty(
    itemId: _item!.id,
    delta: qtyOutUnit.round(),
    note: '입고 ($unitIn → $unitOut)',
    );
    await _load();
    },
    ),
    ),
    ],
    ),
    ),
    ),
    );
  }

  // ===== Practical-MIN: 롤 입고 모달 =====
  void _openLotReceive(BuildContext ctx, String itemId) {
    final repo = context.read<InMemoryRepo>();
    final rows = <Map<String, TextEditingController>>[
      {'lot': TextEditingController(), 'len': TextEditingController()}
    ];

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSB) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('롤 입고 (실측 길이 m)', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: r['lot'],
                        decoration: const InputDecoration(labelText: 'Lot No'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: r['len'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '길이 (m)'),
                      ),
                    ),
                  ],
                ),
              )),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setSB(() => rows.add({
                      'lot': TextEditingController(),
                      'len': TextEditingController(),
                    })),
                    child: const Text('+ 행 추가'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('저장'),
                    onPressed: () {
                      final inputs = rows.map((c) => {
                        'lot_no': c['lot']!.text.trim().isEmpty
                            ? 'L${DateTime.now().millisecondsSinceEpoch}'
                            : c['lot']!.text.trim(),
                        'received_qty_roll': 1,
                        'measured_length_m': double.tryParse(c['len']!.text) ?? 0,
                        'usable_qty_m': double.tryParse(c['len']!.text) ?? 0,
                        'status': 'active',
                      }).where((m) => (m['measured_length_m'] as double) > 0).toList();

                      if (inputs.isNotEmpty) {
                        repo.receiveLots(itemId, inputs);
                        Navigator.pop(ctx);
                        _load(); // 새로고침
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Practical-MIN: M 출고(FIFO) 모달 =====
  void _openLotIssue(BuildContext ctx, String itemId) {
    final repo = context.read<InMemoryRepo>();
    final c = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('M 단위 출고 (FIFO)', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '출고량 (m)'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('출고'),
              onPressed: () {
                final m = double.tryParse(c.text) ?? 0;
                if (m > 0) {
                  repo.consumeLotsFifo(itemId, m);
                  Navigator.pop(ctx);
                  _load(); // 새로고침
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Practical-MIN: 인라인 Lot 목록 =====
class _LotListInline extends StatelessWidget {
  final String itemId;
  const _LotListInline({required this.itemId});

  @override
  Widget build(BuildContext context) {
    final lots = context.select<InMemoryRepo, List<Lot>>(
          (r) => r.lotsByItem(itemId),
    );
    if (lots.isEmpty) return const Text('등록된 롤 없음');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lot 목록', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...lots.map((l) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${l.lotNo} — ${l.usableQtyM.toStringAsFixed(2)} / ${l.measuredLengthM.toStringAsFixed(2)} m (${l.status})',
          ),
        )),
      ],
    );
  }
}
