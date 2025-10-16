import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase.dart';
import '../../models/types.dart';

import '../../services/inventory_service.dart';
import '../../ui/common/ui.dart';

class PurchaseListScreen extends StatelessWidget {
  const PurchaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PurchaseRepo>();
    final inv  = context.read<InventoryService>();
    return Scaffold(
      appBar: AppBar(title: Text(context.t.dashboard_purchases)),
      body: StreamBuilder<List<Purchase>>(
        stream: repo.watchAllPurchases(),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return Center(child: Text(context.t.purchases_list_empty));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return ListTile(
                title: Text('${p.itemId}  x${p.qty}'),
                subtitle: Text('${p.status.name} • ${p.note ?? ''}'),

                                  trailing: switch (p.status) {
                                  // planned → ordered : 입고 예정(Planned Txn)  상태 전환
                                  PurchaseStatus.planned   =>
                                    ElevatedButton(
                                          onPressed: () => inv.orderPurchase(p.id),
                                    child: Text(context.t.purchase_action_order),
                                  ),
                                // ordered → received : Actual Txn 생성 + 입고 완료
                                PurchaseStatus.ordered   =>
                                  ElevatedButton(
                                    onPressed: () => inv.receivePurchase(p.id),
                                    child: Text(context.t.purchase_action_receive),
                                  ),
                                // 완료 상태
                                PurchaseStatus.received  =>
                                  const Icon(Icons.inventory_2, color: Colors.blueGrey),
                                // 취소 상태(누락 방지)
                                PurchaseStatus.canceled  =>
                                  const Icon(Icons.block, color: Colors.grey),
                              },
              );
            },
          );
        },
      ),
    );
  }
}
