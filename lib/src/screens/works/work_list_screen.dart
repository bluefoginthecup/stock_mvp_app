import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import 'work_detail_screen.dart';
import '../../services/inventory_service.dart'; // ✅ 추가
import 'widgets/work_row.dart';

//다국어 앱 셋팅
import '../../ui/common/ui.dart';

class WorkListScreen extends StatelessWidget {
  const WorkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
    //  final inmem = context.read<InMemoryRepo>();
    // print('[WorkListScreen] using InMemoryRepo instance = ${identityHashCode(inmem)}'); // ✅ 추가
    final inv = context.read<InventoryService>(); // ✅ 재고/전이 오케스트레이션

    return Scaffold(
      appBar: AppBar(title: Text(context.t.work_list_title)),
      body: StreamBuilder<List<Work>>(
        stream: workRepo.watchAllWorks(),
        builder: (context, snap) {
          final list = (snap.data ?? const <Work>[])
              .where((w) => w.status != WorkStatus.canceled)
              .toList();
          if (list.isEmpty) {
            return Center(child: Text(context.t.work_list_empty));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final w = list[i];

              return WorkRow(
                w: w,
                // ✅ planned → inProgress : planned Txn 생성 + 상태 전환
                onStart: (w.status == WorkStatus.planned)
                    ? () => inv.startWork(w.id)
                    : null,
                // ✅ inProgress → done : actual Txn 생성 + 완료 처리
                onDone: (w.status == WorkStatus.inProgress)
                    ? () => inv.completeWork(w.id)
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => WorkDetailScreen(work: w)),
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
