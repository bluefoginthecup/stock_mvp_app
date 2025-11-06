import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/inmem_repo.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_line.dart';
import 'purchase_order_print_view.dart' show PurchaseOrderPrintView, PrintLine;

class PurchaseOrderDetailScreen extends StatelessWidget {
  final String poId;
  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<InMemoryRepo>();

    Future<(PurchaseOrder?, List<PurchaseLine>)> _load() async {
      final po = await repo.getPurchaseOrder(poId);
      final lines = await repo.listPurchaseLines(poId);
      return (po, lines);
    }

    String _statusLabel(PurchaseOrderStatus s) {
      switch (s) {
        case PurchaseOrderStatus.draft: return '임시저장';
        case PurchaseOrderStatus.ordered: return '발주완료';
        case PurchaseOrderStatus.received: return '입고완료';
        case PurchaseOrderStatus.canceled: return '취소';
      }
    }

    String _fmtDate(DateTime? d) {
      if (d == null) return '-';
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }

    // ⬇️ PurchaseLine → PrintLine 변환 (현재 모델에 맞춰 안전하게)
    PrintLine _toPrintLine(InMemoryRepo repo, PurchaseLine l) {
      final it = repo.getItemById(l.itemId);               // 동기 캐시
      final name = l.displayNameWith(it);                  // 네가 쓰는 헬퍼 그대로 재사용
      final spec = '';                                     // 필요 시 it의 속성으로 채워도 됨
      final amount = 0.0;                                  // 단가*수량 계산 로직 있으면 반영
      final memo = '';                                     // 라인에 메모가 있으면 연결
      return PrintLine(
        itemName: name,
        spec: spec,
        unit: l.unit,
        qty: l.qty,
        amount: amount,
        memo: memo,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('발주서 상세'),
        actions: [
          // ⬇️ 발주서 보기 버튼 추가
          FutureBuilder<(PurchaseOrder?, List<PurchaseLine>)>(
            future: _load(),
            builder: (ctx, snap) {
              final enabled = snap.connectionState == ConnectionState.done && snap.hasData && snap.data!.$1 != null;
              return IconButton(
                tooltip: '발주서 보기',
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: !enabled ? null : () {
                  final (po, rawLines) = snap.data!;
                  final printLines = rawLines.map((e) => _toPrintLine(repo, e)).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchaseOrderPrintView(order: po!, lines: printLines),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<(PurchaseOrder?, List<PurchaseLine>)>(
        future: _load(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('불러오기 실패: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const SizedBox.shrink();
          }

          final (po, lines) = snap.data!;
          if (po == null) {
            return const Center(child: Text('해당 발주를 찾을 수 없습니다.'));
          }

          final totalLines = lines.length;
          final supplier = (po.supplierName?.trim().isEmpty ?? true)
              ? '(공급처 미지정)'
              : po.supplierName!.trim();

          return ListView(
            children: [
              // 헤더 카드
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodyMedium!,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('공급처', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(supplier, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _InfoTile(label: '상태', value: _statusLabel(po.status), icon: Icons.flag)),
                            Expanded(child: _InfoTile(label: 'ETA(입고예정)', value: _fmtDate(po.eta), icon: Icons.event)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _InfoTile(label: '발주ID', value: po.id, icon: Icons.tag)),
                            Expanded(child: _InfoTile(label: '품목수', value: '$totalLines', icon: Icons.list_alt)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 라인 목록
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text('발주 품목', style: Theme.of(context).textTheme.titleMedium),
              ),
              ...lines.map((ln) {
                final it = repo.getItemById(ln.itemId);
                return ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(ln.displayNameWith(it)),
                  subtitle: Text('수량: ${ln.qty.toStringAsFixed(0)} ${ln.unit}'),
                );
              }),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
