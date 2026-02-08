// lib/src/screens/works/work_detail_view.dart

import '../../models/work.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../repos/repo_interfaces.dart';
import '../../models/types.dart';
import '../../services/inventory_service.dart';
import '../../utils/item_presentation.dart';
import '../../ui/common/ui.dart';


// ⬇️ l10n
import '../../l10n/l10n.dart';

class WorkDetailView extends StatefulWidget {
  final String workId;
  final bool embedded;
  const WorkDetailView({
    super.key,
    required this.workId,
    this.embedded = false,
  });

  @override
  State<WorkDetailView> createState() => _WorkDetailViewState();
}

class _WorkDetailViewState extends State<WorkDetailView> {
  late final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<(String, String?)> _loadNames(BuildContext ctx, Work w) async {
    final itemRepo  = ctx.read<ItemRepo?>();
    final orderRepo = ctx.read<OrderRepo?>();

    String itemName = '';
    String? customer;

    if (itemRepo != null) {
      final n = await itemRepo.nameOf(w.itemId);
      final nt = n?.trim();
      if (nt != null && nt.isNotEmpty) itemName = nt;
    }

    if (w.orderId != null && orderRepo != null) {
      final r = await orderRepo.customerNameOf(w.orderId!);
      final rt = r?.trim();
      if (rt != null && rt.isNotEmpty) customer = rt;
    }

    if (itemName.isEmpty) {
      itemName = L10n.of(ctx)
          .work_row_item_fallback(w.itemId);

    }
    return (itemName, customer);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.read<InventoryService>();
    final workRepo = context.read<WorkRepo>();

    return StreamBuilder<List<Work>>(
      stream: workRepo.watchAllWorks(),
      builder: (context, snapWorks) {
        final list = snapWorks.data;

        if (list == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final wIndex = list.indexWhere((x) => x.id == widget.workId);
        if (wIndex < 0) {
          return const Center(child: Text('작업을 찾을 수 없습니다.'));
        }
        final w = list[wIndex];

        final canChange = w.status != WorkStatus.canceled;
        final remaining = math.max(0, w.qty - w.doneQty);

        return FutureBuilder<(String, String?)>(
          future: _loadNames(context, w),
          builder: (ctx, snap) {
            final customer = snap.data?.$2;

            final locale = Localizations.localeOf(context).toString();
            final createdAtText =
            DateFormat.yMMMd(locale).add_Hms().format(w.createdAt);

            return Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: ItemLabel(itemId: w.itemId, full: false)),
                            const SizedBox(width: 8),
                            Text('×${w.qty}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (customer != null) ...[
                          _kv('고객', customer),
                          const SizedBox(height: 6),
                        ],

                        _kv('진행', '${w.doneQty} / ${w.qty} (남은 $remaining)'),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: canChange
                                    ? () => _showPartialCompleteDialog(context, inv, w)
                                    : null,
                                child: const Text('부분 완료'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: (canChange && remaining > 0)
                                    ? () => inv.completeWork(w.id)
                                    : null,
                                child: const Text('전량 완료'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (!widget.embedded) ...[
                          _buildStatusButtons(context, inv, w, canChange),
                          const SizedBox(height: 12),
                          _kv('생성일', createdAtText),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusButtons(BuildContext context, InventoryService inv, Work w, bool canChange) {
    return Row(
      children: [
        Text(context.t.field_status_label),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusButton(
                context: context,
                label: '시작',
                color: Colors.green,
                active: w.status == WorkStatus.planned,
                enabled: canChange,
                onTapConfirm: () async {
                  if (w.status == WorkStatus.planned) return;
                  final ok = await _confirm(context);
                  if (ok != true) return;
                  await inv.setWorkStatus(w.id, WorkStatus.planned);
                },
              ),
              _statusButton(
                context: context,
                label: '진행중',
                color: Colors.blue,
                active: w.status == WorkStatus.inProgress,
                enabled: canChange,
                onTapConfirm: () async {
                  if (w.status == WorkStatus.inProgress) return;
                  final ok = await _confirm(context);
                  if (ok != true) return;
                  await inv.setWorkStatus(w.id, WorkStatus.inProgress);
                },
              ),
              _statusButton(
                context: context,
                label: '완료',
                color: Colors.red,
                active: w.status == WorkStatus.done,
                enabled: canChange,
                onTapConfirm: () async {
                  if (w.status == WorkStatus.done) return;
                  final ok = await _confirm(context);
                  if (ok != true) return;
                  await inv.setWorkStatus(w.id, WorkStatus.done);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => RichText(
    text: TextSpan(
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      children: [
        TextSpan(text: '$k: ',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: v),
      ],
    ),
  );

  Widget _statusButton({
    required BuildContext context,
    required String label,
    required Color color,
    required bool active,
    required bool enabled,
    required Future<void> Function() onTapConfirm,
  }) {
    final btn = active
        ? ElevatedButton(
      onPressed: enabled ? () {} : null,
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text(label),
    )
        : OutlinedButton(
      onPressed: enabled ? () async => onTapConfirm() : null,
      child: Text(label),
    );
    return SizedBox(height: 40, child: btn);
  }

  Future<bool?> _confirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('상태 변경'),
        content: const Text('상태를 변경하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _showPartialCompleteDialog(
      BuildContext context,
      InventoryService inv,
      Work w,
      ) async {
    final remaining = w.qty - w.doneQty;
    final controller = TextEditingController(
      text: (remaining > 0 ? remaining : 1).toString(),
    );

    final madeQty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('부분 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('완료 수량을 입력하세요. (남은 수량: ${remaining > 0 ? remaining : 0})'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '예: 15'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx, v);
            },
            child: const Text('완료 처리'),
          ),
        ],
      ),
    );

    if (madeQty == null || madeQty <= 0) return;
    await inv.completeWorkPartial(workId: w.id, madeQty: madeQty);
  }
}
