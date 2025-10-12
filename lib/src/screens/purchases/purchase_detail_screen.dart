import 'package:flutter/material.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase.dart';
import '../../models/types.dart';
import '../../ui/common/ui.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final PurchaseRepo repo;
  final Purchase purchase;
  const PurchaseDetailScreen({super.key, required this.repo, required this.purchase});

  PurchaseStatus _next(PurchaseStatus s) {
    switch (s) {
      case PurchaseStatus.planned: return PurchaseStatus.ordered;
      case PurchaseStatus.ordered: return PurchaseStatus.received;
      case PurchaseStatus.received:
      case PurchaseStatus.canceled: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = purchase;
    final canNext = p.status != PurchaseStatus.received && p.status != PurchaseStatus.canceled;
    final next = _next(p.status);
    return Scaffold(
      appBar: AppBar(title: Text(context.t.purchase_detail_title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('발주 품목: ${p.itemId}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('ID: ${p.id}'),
                Text('Qty: ${p.qty}'),
                if (p.vendorId != null) Text('Vendor: ${p.vendorId}'),
                if (p.note != null) Text('Note: ${p.note}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Status: '),
                    Chip(label: Text(p.status.name)),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canNext
                            ? () => repo.updatePurchase(
                          p.copyWith(status: next, updatedAt: DateTime.now()),
                        )
                            : null,
                        child: Text(
                          switch (p.status) {
                            PurchaseStatus.planned  => 'Order (ordered)',
                            PurchaseStatus.ordered  => 'Receive (received)',
                            _                        => '입고완료됨'
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: p.status == PurchaseStatus.received
                            ? null
                            : () => repo.updatePurchase(
                          p.copyWith(status: PurchaseStatus.canceled, updatedAt: DateTime.now()),
                        ),
                        child: Text('Cancel'),
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
