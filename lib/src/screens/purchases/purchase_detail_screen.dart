// lib/src/screens/purchases/purchase_detail_screen.dart
import 'package:flutter/material.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase_order.dart';
import '../../ui/common/ui.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final PurchaseOrderRepo repo;
  final PurchaseOrder order;

  const PurchaseDetailScreen({
    super.key,
    required this.repo,
    required this.order,
  });

  PurchaseOrderStatus _next(PurchaseOrderStatus s) {
    switch (s) {
      case PurchaseOrderStatus.draft:
        return PurchaseOrderStatus.ordered;
      case PurchaseOrderStatus.ordered:
        return PurchaseOrderStatus.received;
      case PurchaseOrderStatus.received:
      case PurchaseOrderStatus.canceled:
        return s;
    }
  }

  String _statusLabel(BuildContext ctx, PurchaseOrderStatus s) {
    // 필요하면 L10n으로 치환하세요.
    switch (s) {
      case PurchaseOrderStatus.draft:    return '임시';
      case PurchaseOrderStatus.ordered:  return '발주됨';
      case PurchaseOrderStatus.received: return '입고완료';
      case PurchaseOrderStatus.canceled: return '취소됨';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = order;
    final canNext = p.status != PurchaseOrderStatus.received &&
        p.status != PurchaseOrderStatus.canceled;
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
                // 기본 정보
                Text(
                  p.supplierName?.isNotEmpty == true
                      ? '공급처: ${p.supplierName}'
                      : '공급처: (미지정)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('발주 ID: ${p.id}'),
                if (p.eta != null) Text('ETA: ${p.eta}'),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(context.t.field_status_label),
                    const SizedBox(width: 6),
                    Chip(label: Text(_statusLabel(context, p.status))),
                  ],
                ),

                const Spacer(),

                // 액션 버튼들
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canNext
                            ? () => repo.updatePurchaseOrderStatus(p.id, next)
                            : null,
                        child: Text(
                          switch (p.status) {
                            PurchaseOrderStatus.draft   => context.t.purchase_action_order,
                            PurchaseOrderStatus.draft => context.t.purchase_action_order,
                            PurchaseOrderStatus.ordered => context.t.purchase_action_receive,
                            _                           => context.t.purchase_already_received,
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: p.status == PurchaseOrderStatus.received
                            ? null
                            : () => repo.updatePurchaseOrderStatus(
                            p.id, PurchaseOrderStatus.canceled),
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
