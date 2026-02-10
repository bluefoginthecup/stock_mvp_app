import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/work.dart';
import '../../models/types.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/inventory_service.dart';
import '../../utils/item_presentation.dart';
import '../../ui/common/ui.dart';

class WorkActionView extends StatelessWidget {
  final String workId;
  final bool embedded; // 주문상세 끼워넣기용
  const WorkActionView({super.key, required this.workId, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
    final inv = context.read<InventoryService>();

    return StreamBuilder<Work?>(
      stream: workRepo.watchWorkById(workId),
      builder: (context, snap) {
        final w = snap.data;
        if (w == null) return const SizedBox.shrink();

        final remaining = math.max(0, w.qty - w.doneQty);
        final over = math.max(0, w.doneQty - w.qty);
        final canChange = w.status != WorkStatus.canceled;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkHeaderRow(
                  work: w,
                  onMore: embedded
                      ? () => _showWorkMoreMenu(context, w)
                      : null,
                ),
                const SizedBox(height: 10),

                _WorkProgressLine(w: w),

                const SizedBox(height: 10),

                WorkStatusSelector(
                  work: w,
                  enabled: canChange,
                  onChange: (target) async {
                    final ok = await _confirm(context, '상태를 변경할까요?');
                    if (ok != true) return;
                    await inv.setWorkStatus(w.id, target);
                  },
                ),
                const SizedBox(height: 12),

                WorkActionButtons(
                  enabled: canChange,
                  remaining: remaining,
                  onPartial: () => _showPartialCompleteDialog(context, inv, w),
                  onAllDone: remaining > 0 ? () => inv.completeWork(w.id) : null,
                ),

                if (!embedded) ...[
                  const SizedBox(height: 12),
                  Text('workId: ${shortId(w.id)}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorkMoreMenu(BuildContext context, Work w) async {
    // 여기서: "작업 상세로 이동", "편집", "삭제" 등
    // 주문상세에서만 쓰면 embedded=true일 때만 호출
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('작업 상세'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: WorkDetailScreen으로 push (workId 기반)
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('작업 편집'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 편집 다이얼로그/화면
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('작업 삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 삭제 confirm
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('확인'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _showPartialCompleteDialog(
      BuildContext context,
      InventoryService inv,
      Work w,
      ) async {
    final remaining = math.max(0, w.qty - w.doneQty);
    final controller = TextEditingController(text: (remaining > 0 ? remaining : 1).toString());

    final madeQty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('부분 완료'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '예: 15'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('완료 처리'),
          ),
        ],
      ),
    );

    if (madeQty == null || madeQty <= 0) return;
    await inv.completeWorkPartial(workId: w.id, madeQty: madeQty); // 초과 생산도 허용
  }
}

//------------------------//
class WorkHeaderRow extends StatelessWidget {
  final Work work;
  final VoidCallback? onMore;
  const WorkHeaderRow({super.key, required this.work, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: ItemLabel(itemId: work.itemId, full: false)),
        const SizedBox(width: 8),
        Text('×${work.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (onMore != null) ...[
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: onMore),
        ],
      ],
    );
  }
}


//------------------------//
class WorkStatusSelector extends StatelessWidget {
  final Work work;
  final bool enabled;
  final Future<void> Function(WorkStatus target) onChange;
  const WorkStatusSelector({
    super.key,
    required this.work,
    required this.enabled,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, WorkStatus s, Color color) {
      final active = work.status == s;
      return SizedBox(
        height: 38,
        child: active
            ? FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(backgroundColor: color),
          child: Text(label),
        )
            : OutlinedButton(
          onPressed: enabled ? () => onChange(s) : null,
          child: Text(label),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        btn('계획', WorkStatus.planned, Colors.grey),
        btn('진행중', WorkStatus.inProgress, Colors.blue),
        btn('완료', WorkStatus.done, Colors.green),
      ],
    );
  }
}
//--------------------//
class WorkActionButtons extends StatelessWidget {
  final bool enabled;
  final int remaining;
  final VoidCallback onPartial;
  final VoidCallback? onAllDone;

  const WorkActionButtons({
    super.key,
    required this.enabled,
    required this.remaining,
    required this.onPartial,
    required this.onAllDone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: enabled ? onPartial : null,
            child: const Text('부분 완료'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: (enabled && onAllDone != null) ? onAllDone : null,
            child: const Text('전량 완료'),
          ),
        ),
      ],
    );
  }
}
class _WorkProgressLine extends StatelessWidget {
  final Work w;
  const _WorkProgressLine({required this.w});

  @override
  Widget build(BuildContext context) {
    final planned = w.qty;
    final done = w.doneQty;
    final remaining = (planned - done) > 0 ? (planned - done) : 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            '진행: $done / $planned (남은 $remaining)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (planned > 0)
          Text('${((done / planned) * 100).clamp(0, 999).toStringAsFixed(0)}%'),
      ],
    );
  }
}
