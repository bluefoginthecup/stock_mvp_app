import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import 'work_detail_screen.dart';
import '../../services/inventory_service.dart'; // ✅ 추가
import 'widgets/work_row.dart';
import '../../repos/inmem_repo.dart';

//다국어 앱 셋팅
import '../../ui/common/ui.dart';


class WorkListScreen extends StatelessWidget {
  const WorkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
    final inmem = context.read<InMemoryRepo>();
    print('[WorkListScreen] using InMemoryRepo instance = ${identityHashCode(inmem)}'); // ✅ 추가
    final inv = context.read<InventoryService>();             // ✅ 재고/전이 오케스트레이션

    return Scaffold(
      appBar: AppBar(title: Text(context.t.work_list_title)),
      body: StreamBuilder<List<Work>>(
        stream: workRepo.watchAllWorks(),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return Center(child: Text(context.t.work_list_empty));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final w = list[i];
              final done = w.status == WorkStatus.done;

              return WorkRow(
                w: w,
                // ✅ planned → inProgress : planned Txn 생성 + 상태 전환
                onStart:   (w.status == WorkStatus.planned)
                    ? () => inv.startWork(w.id)
                    : null,
                // ✅ inProgress → done : actual Txn 생성 + 완료 처리
                onDone:    (w.status == WorkStatus.inProgress)
                    ? () => inv.completeWork(w.id)
                    : null,
                onTap: () {
                  print('📦 tapped work: ${w.id} (${w.itemId})');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WorkDetailScreen(work: w)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
class _WorkStatusButton extends StatelessWidget {
    final Work work;
    final Future<void> Function() onStart;    // planned → inProgress
    final Future<void> Function() onComplete; // inProgress → done
    const _WorkStatusButton({
      required this.work,
      required this.onStart,
      required this.onComplete,
    });

    @override
    Widget build(BuildContext context) {
      switch (work.status) {
        case WorkStatus.planned:
          return ElevatedButton(onPressed: onStart, child: Text(context.t.work_action_start));
        case WorkStatus.inProgress:
          return ElevatedButton(onPressed: onComplete, child: Text(context.t.work_action_done));
        case WorkStatus.done:
          return const Icon(Icons.check, color: Colors.green);
        case WorkStatus.canceled: // ✅ enum에 있으니 누락 금지
          return const Icon(Icons.block, color: Colors.grey);
      }
    }
  }
