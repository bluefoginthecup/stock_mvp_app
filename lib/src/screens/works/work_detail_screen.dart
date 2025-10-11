import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';

class WorkDetailScreen extends StatelessWidget {
  final Work work;
  const WorkDetailScreen({super.key, required this.work});

  WorkStatus _next(WorkStatus s) {
    switch (s) {
      case WorkStatus.planned:    return WorkStatus.inProgress;
      case WorkStatus.inProgress: return WorkStatus.done;
      case WorkStatus.done:       return WorkStatus.done;
      case WorkStatus.canceled:   return WorkStatus.canceled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<WorkRepo>();
    final w = work;
    final canAdvance = w.status != WorkStatus.done && w.status != WorkStatus.canceled; // ✅ 취소시 비활성화

    final next = _next(w.status);

    return Scaffold(
      appBar: AppBar(title: const Text('작업 상세')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${w.itemId} x${w.qty}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('ID: ${w.id}'),
                if (w.orderId != null) Text('Order: ${w.orderId}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Status: '),
                    Chip(label: Text(w.status.name)),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !canAdvance
                            ? null
                            : () async {
                          if (w.status == WorkStatus.inProgress) {
                            // inProgress → done 은 재고 반영 포함한 완료 처리
                            await repo.completeWork(w.id);
                          } else {
                            // planned → inProgress 은 상태만 변경
                            await repo.updateWorkStatus(w.id, next);
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          switch (w.status) {
                            WorkStatus.planned    => 'Start (inProgress)',
                            WorkStatus.inProgress => 'Complete (done)',
                            WorkStatus.done       => '완료됨',
                            WorkStatus.canceled   => '취소됨',

                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
