import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase.dart';
import '../../models/types.dart';

class PurchaseListScreen extends StatelessWidget {
  const PurchaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PurchaseRepo>();
    return Scaffold(
      appBar: AppBar(title: const Text('발주 계획')),
      body: StreamBuilder<List<Purchase>>(
        stream: repo.watchAllPurchases(),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(child: Text('발주 계획이 없습니다.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              final done = p.status == PurchaseStatus.received;
              return ListTile(
                title: Text('${p.itemId}  x${p.qty}'),
                subtitle: Text('${p.status.name} • ${p.note ?? ''}'),
                trailing: done
                    ? const Icon(Icons.inventory_2, color: Colors.blueGrey)
                    : ElevatedButton(
                  onPressed: () => repo.completePurchase(p.id),
                  child: const Text('입고완료'),

                ),
              );
            },
          );
        },
      ),
    );
  }
}
