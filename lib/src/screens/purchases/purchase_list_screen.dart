// lib/src/screens/purchases/purchase_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase_order.dart';// ✅ 변경됨
import '../../models/types.dart';
import '../../services/inventory_service.dart';
import '../../ui/common/ui.dart';
import '../purchases/purchase_detail_screen.dart'; // 경로는 프로젝트 구조에 맞게
import '../../repos/inmem_repo.dart';


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
              final repo = context.read<InMemoryRepo>();

              // 간단 ETA 포맷터 (intl 없이)
              String fmtDate(DateTime? d) {
                if (d == null) return '-';
                final m = d.month.toString().padLeft(2, '0');
                final day = d.day.toString().padLeft(2, '0');
                return '${d.year}-$m-$day';
              }

              // (원하면 한국어 라벨로 변환)
              String statusLabel() {
                final n = p.status.name; // draft/ordered/received/canceled …
                switch (n) {
                  case 'draft': return '임시저장';
                  case 'ordered': return '발주완료';
                  case 'received': return '입고완료';
                  case 'canceled': return '취소';
                  default: return n;
                }
              }


    return Card(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: ListTile(
    title: Text('발주: ${p.supplierName?.trim().isEmpty == true ? '(미지정)' : p.supplierName!}'),
    subtitle: Text('상태: ${statusLabel()} • ETA: ${fmtDate(p.eta)}'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseDetailScreen(
            repo: context.read<PurchaseOrderRepo>(),
            orderId: p.id, // ✅ 최신 방식
          ),
        ),
      );
    },
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    ).copyWithButtonBar(context, p, repo); // 👇 아래 확장 메서드 참고
    },
    );

        },
      ),
    );
  }
}

extension on Card {
  Widget copyWithButtonBar(BuildContext context, PurchaseOrder p, InMemoryRepo repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        this, // 원래 카드 내용
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (p.status == PurchaseOrderStatus.draft)
                FilledButton.tonal(
                  onPressed: () async {
                    await repo.updatePurchaseOrderStatus(p.id, PurchaseOrderStatus.ordered);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('상태: 발주완료로 변경됨')),
                      );
                    }
                  },
                  child: const Text('발주완료'),
                ),
              if (p.status == PurchaseOrderStatus.ordered)
                FilledButton(
                  onPressed: () async {
                    await repo.updatePurchaseOrderStatus(p.id, PurchaseOrderStatus.received);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('상태: 입고완료로 변경됨')),
                      );
                    }
                  },
                  child: const Text('입고완료'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
