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

    // 표시이름 보강
    final fallbackName = (l.name.trim().isNotEmpty)
        ? l.name.trim()
        : (it?.displayName ?? it?.name ?? l.itemId);

    // 스펙(선택): 필요 없으면 빈문자 유지
    final spec = (it?.attrs?['nominalSize'] ?? '').toString().trim();

    // ✅ color_no 우선순위: PurchaseLine.colorNo → Item.attrs['color_no']
    //  - PurchaseLine.colorNo가 non-nullable이면 아래 첫 줄을 `final ln = l.colorNo.trim();`로 쓰세요.
    final ln = (l is dynamic && (l.colorNo is String)) ? (l.colorNo as String).trim() : '';
    final colorNo = ln.isNotEmpty
        ? ln
        : ((it?.attrs?['color_no'] ?? '').toString().trim());

    // 단가/메모(현재 미사용이면 0/빈문자)
    final amount = 0.0;
    final memo = '';

    return PrintLine(
      itemName: fallbackName,
      spec: spec,
      unit: l.unit,
      qty: l.qty,
      amount: amount,
      memo: memo,
      colorNo: colorNo, // ✅ 이제 실제 값이 들어감
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
