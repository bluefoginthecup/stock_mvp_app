
import 'package:provider/provider.dart';

import '../../models/work.dart';
import '../../models/types.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/inventory_service.dart';
import '../../utils/item_presentation.dart';
import '../../ui/common/ui.dart';
import '../works/work_detail_screen.dart';
import '../works/work_edit_sheet.dart';

class WorkActionView extends StatelessWidget {
  final String workId;
  final bool embedded; // 주문상세 끼워넣기용
  const WorkActionView(
      {super.key, required this.workId, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
    final inv = context.read<InventoryService>();

    return StreamBuilder<Work?>(
      stream: workRepo.watchWorkById(workId),
      builder: (context, snap) {
        final w = snap.data;
        if (w == null) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text('작업 로딩 중…')),
          );
        }

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

                // ✅ 하위 작업(자식 작업) 표시
                const SizedBox(height: 12),
                _ChildWorksSection(parent: w),


                if (!embedded) ...[
                  const SizedBox(height: 12),
                  Text('workId: ${shortId(w.id)}', style: Theme
                      .of(context)
                      .textTheme
                      .bodySmall),
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
      builder: (ctx) =>
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('작업 상세'),
                  onTap: () {
                    Navigator.pop(ctx); // bottom sheet 닫기
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorkDetailScreen(work: w),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('작업 편집'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => WorkEditSheet(workId: w.id),
                    );
                  },


                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                      '작업 삭제', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);

                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          AlertDialog(
                            title: const Text('작업 삭제'),
                            content: const Text(
                                '이 작업을 삭제할까요?\n(완료/부분완료 수량이 있는 경우 재고 롤백은 다음 단계에서 처리합니다)'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(_, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(_, true),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                    );

                    if (ok != true) return;

                    await context.read<WorkRepo>().softDeleteWork(w.id);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('작업이 삭제되었습니다')),
                      );
                    }
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
      builder: (dialogCtx) =>
          AlertDialog(
            title: const Text('확인'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('확인'),
              ),
            ],
          ),
    );
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

class _WorkProgressLine extends StatelessWidget {
  final Work w;
  const _WorkProgressLine({required this.w});

  @override
  Widget build(BuildContext context) {
    final planned = w.qty;
    final done = w.doneQty;
    final remaining = (planned - done) > 0 ? (planned - done) : 0;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: planned > 0
          ? () async {
        final controller = TextEditingController(text: '$done');

        final result = await showDialog<int>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('완료 수량 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('계획 수량: $planned'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '완료 수량',
                    hintText: '0 ~ 계획 수량',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  final v = int.tryParse(controller.text);
                  if (v == null) return;
                  Navigator.pop(c, v);
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );

        if (result == null) return;

        final clamped = result.clamp(0, planned);
        if (clamped == done) return;

        await context.read<InventoryService>().setWorkDoneQty(
          workId: w.id,
          targetDoneQty: clamped,
        );
      }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '진행: $done / $planned (남은 $remaining)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (planned > 0)
              Text(
                '${((done / planned) * 100).clamp(0, 999).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );

  }
}

class _ChildWorksSection extends StatelessWidget {
  final Work parent;
  const _ChildWorksSection({required this.parent});

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();

    return StreamBuilder<List<Work>>(
      stream: workRepo.watchChildWorks(parent.id),
      builder: (context, snap) {
        final children = snap.data ?? const <Work>[];
        if (children.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('하위 작업', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...children.map((c) => Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: WorkActionView(
                workId: c.id,
                embedded: true, // ✅ 자식은 간단 모드
              ),
            )),
          ],
        );
      },
    );
  }
}
