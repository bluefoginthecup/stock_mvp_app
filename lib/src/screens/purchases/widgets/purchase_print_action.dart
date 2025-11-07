import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../repos/inmem_repo.dart';
import '../../../models/purchase_order.dart';
import '../../../models/purchase_line.dart';
import '../purchase_order_print_view.dart'
    show PurchaseOrderPrintView, PurchaseOrderPrintViewMobile, PrintLine;

/// 발주서 인쇄/미리보기 액션 (모바일/A4)
class PurchasePrintAction extends StatelessWidget {
  final String poId;
  const PurchasePrintAction({super.key, required this.poId});

  PrintLine _toPrintLine(InMemoryRepo repo, PurchaseLine l) {
    final it = repo.getItemById(l.itemId);
    final fallbackName = (l.name.trim().isNotEmpty)
        ? l.name
        : (it?.displayName ?? it?.name ?? l.itemId);
    final spec = '';    // 필요시 it.attrs 등 활용
    final amount = 0.0; // 단가*수량 계산 로직 있으면 반영
    final memo = '';    // 라인 메모 쓰면 연결
    return PrintLine(
      itemName: fallbackName,
      spec: spec,
      unit: l.unit,
      qty: l.qty,
      amount: amount,
      memo: memo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<InMemoryRepo>();

    Future<(PurchaseOrder?, List<PurchaseLine>)> _load() async {
      final po = await repo.getPurchaseOrder(poId);
      final lines = await repo.listPurchaseLines(poId);
      return (po, lines);
    }

    return FutureBuilder<(PurchaseOrder?, List<PurchaseLine>)>(
      future: _load(),
      builder: (ctx, snap) {
        final enabled = snap.connectionState == ConnectionState.done &&
            snap.hasData &&
            snap.data!.$1 != null;
        return PopupMenuButton<String>(
          tooltip: '발주서 보기',
          enabled: enabled,
          onSelected: (v) {
            final (po, rawLines) = snap.data!;
            final printLines =
            rawLines.map((e) => _toPrintLine(repo, e)).toList();
            final Widget screen = (v == 'a4')
                ? PurchaseOrderPrintView(order: po!, lines: printLines)
                : PurchaseOrderPrintViewMobile(order: po!, lines: printLines);
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => screen));
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'a4', child: Text('A4 발주서 보기')),
            PopupMenuItem(value: 'mobile', child: Text('모바일용 발주서 보기')),
          ],
          icon: const Icon(Icons.visibility),
        );
      },
    );
  }
}
