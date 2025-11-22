import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_line.dart';
import '../../ui/common/ui.dart';
import 'widgets/purchase_print_action.dart';
import '../../services/inventory_service.dart';
import 'purchase_order_full_edit_screen.dart';
import 'purchase_line_full_edit_screen.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseOrderRepo repo;
  final String orderId;

  const PurchaseDetailScreen({
    super.key,
    required this.repo,
    required this.orderId,
  });

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  PurchaseOrder? _po;
  List<PurchaseLine> _lines = const [];
  Map<String, String> _itemNameById = const {}; // ✅ 아이템명 캐시

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    // 헤더/라인 로드
    final po = await widget.repo.getPurchaseOrderById(widget.orderId);
    final lines = await widget.repo.getLines(widget.orderId);

    // 아이템명 보강 (ItemRepo는 비동기)
    final itemRepo = context.read<ItemRepo>();
    final nameMap = <String, String>{};
    await Future.wait(lines.map((ln) async {
      final it = await itemRepo.getItem(ln.itemId);
      if (it != null) {
        nameMap[ln.itemId] = (it.displayName ?? it.name);
      }
    }));

    if (!mounted) return;
    setState(() {
      _po = po;
      _lines = lines;
      _itemNameById = nameMap;
    });
  }

  String _statusLabel(PurchaseOrderStatus s) {
    switch (s) {
      case PurchaseOrderStatus.draft:
        return '임시저장';
      case PurchaseOrderStatus.ordered:
        return '발주완료';
      case PurchaseOrderStatus.received:
        return '입고완료';
      case PurchaseOrderStatus.canceled:
        return '발주취소';
    }
  }

  PurchaseOrderStatus _next(PurchaseOrderStatus s) {
    switch (s) {
      case PurchaseOrderStatus.draft:
        return PurchaseOrderStatus.ordered;
      case PurchaseOrderStatus.ordered:
        return PurchaseOrderStatus.received;
      case PurchaseOrderStatus.received:
      case PurchaseOrderStatus.canceled:
        return s;
    }
  }

  Future<void> _openHeaderFullEdit() async {
    if (_po == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발주서를 불러오는 중입니다')),
      );
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderFullEditScreen(
          repo: widget.repo,
          orderId: widget.orderId,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _addLineFull() async {
    if (_po == null) return;
    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: widget.orderId,
          initial: null,
        ),
      ),
    );
    if (saved != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추가되었습니다')));
      await _reload();
    }
  }

  Future<void> _openLineFull(PurchaseLine line) async {
    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: widget.orderId,
          initial: line,
        ),
      ),
    );
    if (saved != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다')));
      await _reload();
    }
  }

  String _titleForLine(PurchaseLine ln) {
    final baseName = (ln.name.trim().isNotEmpty)
        ? ln.name
        : (_itemNameById[ln.itemId] ?? ln.itemId);
    return '$baseName × ${ln.qty} ${ln.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final po = _po;
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.purchase_detail_title),
        actions: [
          IconButton(
            onPressed: _openHeaderFullEdit,
            icon: const Icon(Icons.edit_note),
            tooltip: '헤더 전체 편집',
          ),
          PurchasePrintAction(poId: widget.orderId), // ✅ PDF 보기
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLineFull,
        icon: const Icon(Icons.add),
        label: Text(t.btn_add),
      ),
      body: po == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 헤더 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('헤더',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(width: 8),
                        Chip(label: Text(_statusLabel(po.status))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('공급처: ${po.supplierName.trim().isEmpty ? '(미지정)' : po.supplierName}'),
                    Text('입고예정일: ${po.eta.toLocal()}'.split('.').first),
                    if ((po.memo ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('적요: ${po.memo}'),
                    ],
                    const SizedBox(height: 8),
                    Text('발주ID: ${po.id}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 라인 목록
            Expanded(
              child: _lines.isEmpty
                  ? const Center(child: Text('발주 품목이 없습니다.'))
                  : ListView.separated(
                itemCount: _lines.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (ctx, i) {
                  final ln = _lines[i];
                  final titleText = _titleForLine(ln);
                  final subtitle = (ln.colorNo ?? '').isEmpty
                      ? null
                      : '색상번호: ${ln.colorNo}';

                  return ListTile(
                    title: Text(titleText),
                    subtitle:
                    subtitle == null ? null : Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openLineFull(ln),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // 상태 전환/취소
            _ActionRow(
              status: po.status,
              onAdvance: () async {
                final next = _next(po.status);
                if (next == po.status) return;

                if (po.status == PurchaseOrderStatus.draft &&
                    next == PurchaseOrderStatus.ordered) {
                  await context.read<InventoryService>().orderPurchase(po.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('발주완료: 예정 입고 기록 생성됨')),
                  );
                  await _reload();
                } else if (po.status == PurchaseOrderStatus.ordered &&
                    next == PurchaseOrderStatus.received) {
                  await context.read<InventoryService>().receivePurchase(po.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('입고 완료: 입출고기록 생성 및 재고 반영됨')),
                  );
                  await _reload();
                }
              },
              onCancel: po.status == PurchaseOrderStatus.received
                  ? null
                  : () async {
                await context.read<InventoryService>().cancelPurchase(po.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('발주 취소: 예정 입고 기록이 정리되었습니다')),
                );
                await _reload();
              },
              labelForAdvance: switch (po.status) {
                PurchaseOrderStatus.draft => t.purchase_action_order,
                PurchaseOrderStatus.ordered => t.purchase_action_receive,
                _ => t.purchase_already_received,
              },
              cancelLabel: t.common_cancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final PurchaseOrderStatus status;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;
  final String labelForAdvance;
  final String cancelLabel;
  const _ActionRow({
    required this.status,
    required this.onAdvance,
    required this.onCancel,
    required this.labelForAdvance,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final canAdvance = status != PurchaseOrderStatus.received &&
        status != PurchaseOrderStatus.canceled;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: canAdvance ? onAdvance : null,
            child: Text(labelForAdvance),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ),
      ],
    );
  }
}
