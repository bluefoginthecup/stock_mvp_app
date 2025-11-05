// lib/src/screens/purchases/purchase_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase_order.dart';// ✅ 변경됨
import '../../models/types.dart';
import '../../services/inventory_service.dart';
import '../../ui/common/ui.dart';

class PurchaseListScreen extends StatelessWidget {
  const PurchaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PurchaseOrderRepo>();
    final inv  = context.read<InventoryService>();


    return Scaffold(
      appBar: AppBar(title: Text(context.t.dashboard_purchases)),
      body: StreamBuilder<List<PurchaseOrder>>( // ✅ 타입 변경
        stream: repo.watchAllPurchaseOrders(),
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
                title: Text('발주: ${p.supplierName ?? '(미지정)'}'),
                subtitle: Text('상태: ${p.status.name} • ETA: ${p.eta ?? '-'}'),

                trailing: switch (p.status) {
                // draft → ordered
                  PurchaseOrderStatus.draft =>
                      ElevatedButton(
                        onPressed: () => inv.orderPurchase(p.id),
                        child: Text(context.t.purchase_action_order),
                      ),
                // ordered → received
                  PurchaseOrderStatus.ordered =>
                      ElevatedButton(
                        onPressed: () => inv.receivePurchase(p.id),
                        child: Text(context.t.purchase_action_receive),
                      ),
                // 완료 상태
                  PurchaseOrderStatus.received =>
                  const Icon(Icons.inventory_2, color: Colors.blueGrey),
                // 취소 상태
                  PurchaseOrderStatus.canceled =>
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
