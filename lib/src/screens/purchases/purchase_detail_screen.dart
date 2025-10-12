import 'package:flutter/material.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase.dart';
import '../../models/types.dart';
import '../../ui/common/ui.dart';
import '../../l10n/labels.dart';
import '../../l10n/l10n_x.dart';

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
                Text(context.t.purchase_detail_item(p.itemId), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
            Text(context.t.purchase_detail_id(p.id)),
                            Text(context.t.purchase_detail_qty(p.qty)),
                            if (p.vendorId != null)
                              Text(context.t.purchase_detail_vendor(p.vendorId!)),
                          if (p.note != null)
                            Text(context.t.purchase_detail_note(p.note!)),

      const SizedBox(height: 8),
                Row(
                  children: [
                    Text(context.t.field_status_label),
                            const SizedBox(width: 6),
                            Chip(
                                  label: Text(
                                    // enum → 라벨 (Labels 없으면 아래 코멘트 참고)
                                    Labels.purchaseStatus(context, p.status),
                              ),
                        ),
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
                                PurchaseStatus.planned  => context.t.purchase_action_order,
                                PurchaseStatus.ordered  => context.t.purchase_action_receive,
                                _                        => context.t.purchase_already_received,
                              },
                            )
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
                        child: Text(context.t.common_cancel),
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
