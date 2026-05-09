import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../repos/repo_interfaces.dart'; // ✅ 인터페이스로 전환
import '../../../models/purchase_order.dart';
import '../../../models/purchase_line.dart';
import '../purchase_order_print_view.dart'
    show PurchaseOrderPrintView, PurchaseOrderPrintViewMobile, PrintLine;

/// 발주서 인쇄/미리보기 액션 (모바일/A4)
class PurchasePrintAction extends StatelessWidget {
  final String poId;
  const PurchasePrintAction({super.key, required this.poId});

  @override
  Widget build(BuildContext context) {
    final poRepo =
        context.read<PurchaseOrderRepo>(); // ✅ InMemoryRepo → PurchaseOrderRepo
    final itemRepo = context.read<ItemRepo>(); // ✅ 아이템명/스펙/색상 보강용

    Future<(PurchaseOrder?, List<PurchaseLine>, List<PrintLine>)> load() async {
      final po = await poRepo.getPurchaseOrderById(poId);
      final lines = await poRepo.getLines(poId);

      // 필요 시 여기서 아이템 정보를 불러와 출력용 라인에 보강
      final printLines = <PrintLine>[];
      for (final l in lines) {
        // 아이템 조회
        final it = await itemRepo.getItem(l.itemId);

        final name = (l.name.trim().isNotEmpty)
            ? l.name.trim()
            : ((it?.displayName ?? it?.name) ?? l.itemId);

        printLines.add(
          PrintLine(
            itemName: name,
            spec: '',
            unit: l.unit,
            qty: l.qty,
            unitPrice: l.unitPrice,
            supplyAmount: l.supplyAmount,
            vatAmount: l.vatAmount,
            totalAmount: l.totalAmount,
            memo: '',
            colorNo: '',
            printAttrs: l.printAttrs,
          ),
        );
      }

      return (po, lines, printLines);
    }

    return FutureBuilder<(PurchaseOrder?, List<PurchaseLine>, List<PrintLine>)>(
      future: load(),
      builder: (ctx, snap) {
        final ready = snap.connectionState == ConnectionState.done &&
            snap.hasData &&
            snap.data!.$1 != null;

        return PopupMenuButton<String>(
          tooltip: '발주서 보기',
          enabled: ready,
          onSelected: (v) {
            final (po, _, printLines) = snap.data!;
            final buyerProfile = po!.buyerSnapshotProfile;
            final screen = (v == 'a4')
                ? PurchaseOrderPrintView(
                    order: po,
                    lines: printLines,
                    buyerProfile: buyerProfile,
                  )
                : PurchaseOrderPrintViewMobile(
                    order: po,
                    lines: printLines,
                    buyerProfile: buyerProfile,
                  );
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
