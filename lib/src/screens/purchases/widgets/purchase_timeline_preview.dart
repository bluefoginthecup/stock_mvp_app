import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../repos/repo_interfaces.dart';
import '../../../models/purchase_order.dart';
import '../../../services/inventory_service.dart';
import '../../../models/types.dart';

class PurchaseTimelinePreview extends StatelessWidget {
  final String purchaseId;
  final VoidCallback? onTap; // ✅ 추가


  const PurchaseTimelinePreview({
    super.key,
    required this.purchaseId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PurchaseOrderRepo>();

    return StreamBuilder(stream: repo.watchPurchaseOrderById(purchaseId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final p = snap.data!;
        final inv = context.read<InventoryService>();


        /// 상태 계산
        final isOrdered =
            p.status == PurchaseOrderStatus.ordered ||
                p.status == PurchaseOrderStatus.received;

        final isReceived =
            p.status == PurchaseOrderStatus.received;



        final isPaid =
            p.paymentStatusEnum == PaymentStatus.paid;

        final isVat =
            p.vatInvoiceStatusEnum == VatInvoiceStatus.issued;

        /// 상태별 날짜
        final orderedDate = p.createdAt;
        final receivedDate = isReceived ? p.receivedAt : p.eta;
        final paidDate = isPaid ? p.paidAt : p.paymentDueAt;
        final vatDate = isVat ? p.vatInvoiceIssuedAt : p.vatInvoiceDueAt;

        return InkWell(
            onTap: onTap,
          child:
          Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔥 타임라인
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _step(
                    label: '발주완료',
                    date: p.createdAt,
                    done: true,
                  ),
                  _step(
                    label: isReceived ? '입고완료' : '입고예정',
                    date: isReceived ? p.receivedAt : p.eta,
                    done: isReceived,
                  ),
                  _step(
                    label: isPaid ? '결제완료' : '결제예정',
                    date: isPaid ? p.paidAt : p.paymentDueAt,
                    done: isPaid,
                  ),
                  _step(
                    label: isVat ? '부가세 발행완료' : '부가세 발행예정',
                    date: isVat ? p.vatInvoiceIssuedAt : p.vatInvoiceDueAt,
                    done: isVat,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// 🔥 상태 텍스트
              Text(
                _statusText(p),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 12),

              /// 🔥 액션 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isReceived)
                    FilledButton(
                      onPressed: () async {
                        try {
                          await inv.receivePurchase(p.id);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('입고 완료')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('실패: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('입고완료'),
                    ),

                  if (!isReceived) const SizedBox(width: 8),

                  if (isReceived && !isPaid)
                    FilledButton.tonal(
                      onPressed: () async {
                        try {
                          await repo.updatePurchaseOrder(
                            p.copyWith(
                              paidAt: DateTime.now(),
                              paymentStatus: 'paid', // 🔥 이거 중요
                            ),
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('결제 완료')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('실패: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('결제완료'),
                    ),
                ],

              ),
              /// 🔥 세금 버튼 (여기 추가)
              if (isPaid && !isVat)
                FilledButton.tonal(
                  onPressed: () async {
                    await repo.updatePurchaseOrder(
                      p.copyWith(
                        vatInvoiceIssuedAt: DateTime.now(),
                        vatInvoiceStatus: 'issued',
                      ),
                    );
                  },
                  child: const Text('세금발행'),
                ),
            ],
          ),
        ),
        );
      },
    );
  }



  /// 🔹 상태 텍스트
  String _statusText(PurchaseOrder p) {
    final status = p.status.name;

    switch (status) {
      case 'draft':
        return '임시저장 상태';
      case 'ordered':
        return '발주 완료 (입고 대기)';
      case 'received':
          if (p.paymentStatusEnum == PaymentStatus.paid) {
          return '입고 및 결제 완료';
        }
        return '입고 완료 (결제 대기)';
      case 'canceled':
        return '취소됨';
      default:
        return status;
    }
  }
}Widget _step({
  required String label,
  required DateTime? date,
  required bool done,
}) {
  String fmt(DateTime? d) {
    if (d == null) return '-';
    return '${d.month}/${d.day}';
  }

  return Expanded(
    child: Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: done ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: done ? FontWeight.bold : FontWeight.normal,
            color: done ? Colors.black : Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          fmt(date),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}