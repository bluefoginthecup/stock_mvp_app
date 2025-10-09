import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';


class WorkListScreen extends StatelessWidget {
  const WorkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
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
                    : ElevatedButton(
                  onPressed: () => workRepo.completeWork(w.id),
                  child: const Text('완료'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
