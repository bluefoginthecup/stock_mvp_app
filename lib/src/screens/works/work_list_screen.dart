import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import 'work_detail_screen.dart';
import '../../services/inventory_service.dart'; // ✅ 추가



class WorkListScreen extends StatelessWidget {
  const WorkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
    final inv = context.read<InventoryService>();             // ✅ 재고/전이 오케스트레이션

    return Scaffold(
      appBar: AppBar(title: const Text('작업 계획')),
      body: StreamBuilder<List<Work>>(
        stream: workRepo.watchAllWorks(),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(child: Text('작업 계획이 없습니다.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final w = list[i];
              final done = w.status == WorkStatus.done;

return ListTile(
                title: Text('${w.itemId}  x${w.qty}'),
                subtitle: Text('${w.status.name} • order=${w.orderId}'),
                trailing: done
                    ? const Icon(Icons.check, color: Colors.green)
                    : _WorkStatusButton(
                        work: w,
                    // ✅ planned → inProgress : planned Txn 생성 + 상태 전환
                                     onStart:   () => inv.startWork(w.id),
                                      // ✅ inProgress → done : actual Txn 생성 + 완료 처리
                                      onComplete:() => inv.completeWork(w.id),
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WorkDetailScreen(work: w)),
                ),
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
          return ElevatedButton(onPressed: onStart, child: const Text('Start'));
        case WorkStatus.inProgress:
          return ElevatedButton(onPressed: onComplete, child: const Text('Done'));
        case WorkStatus.done:
          return const Icon(Icons.check, color: Colors.green);
        case WorkStatus.canceled: // ✅ enum에 있으니 누락 금지
          return const Icon(Icons.block, color: Colors.grey);
      }
    }
  }
