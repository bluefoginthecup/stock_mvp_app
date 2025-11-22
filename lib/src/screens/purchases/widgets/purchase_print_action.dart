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

  PrintLine _toPrintLine(ItemRepo itemRepo, PurchaseLine l) {
    // 아이템 조회(표시명/스펙/색상번호 보강)
    // ItemRepo.getItem은 비동기지만, 이미 목록을 만들 때 한 번에 await 하거나
    // 여기서는 동기 값만 쓰고 싶다면 상위에서 미리 캐시해 넘겨도 됩니다.
    // 간단히 하기 위해선 이 함수는 동기 시그니처 유지하고,
    // 호출부에서 미리 이름/스펙/컬러를 계산해 넘기는 방법도 있어요.

    // 이 컴팩트 버전은 아이템 정보를 요청하지 않고,
    // PurchaseLine에 값이 없을 때만 "fallback 표시명"만 보강합니다.
    // 더 정확히 하려면 build에서 ItemRepo로 미리 보강하세요(아래 build 참고).

    final fallbackName = (l.name.trim().isNotEmpty) ? l.name.trim() : l.itemId;
    final spec = ''; // 필요 시 상위에서 보강
    final colorNo = (l.colorNo ?? '').trim();

    return PrintLine(
      itemName: fallbackName,
      spec: spec,
      unit: l.unit,
      qty: l.qty,
      amount: 0.0,
      memo: '',
      colorNo: colorNo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final poRepo = context.read<PurchaseOrderRepo>(); // ✅ InMemoryRepo → PurchaseOrderRepo
    final itemRepo = context.read<ItemRepo>();        // ✅ 아이템명/스펙/색상 보강용

    Future<(PurchaseOrder?, List<PurchaseLine>, List<PrintLine>)> _load() async {
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

        final spec = (it?.attrs?['nominalSize'] ?? '').toString().trim();
        final colorNo = ((l.colorNo ?? '').trim().isNotEmpty)
            ? (l.colorNo ?? '').trim()
            : ((it?.attrs?['color_no'] ?? '').toString().trim());

        printLines.add(
          PrintLine(
            itemName: name,
            spec: spec,
            unit: l.unit,
            qty: l.qty,
            amount: 0.0,
            memo: '',
            colorNo: colorNo,
          ),
        );
      }

      return (po, lines, printLines);
    }

    return FutureBuilder<(PurchaseOrder?, List<PurchaseLine>, List<PrintLine>)>(
      future: _load(),
      builder: (ctx, snap) {
        final ready = snap.connectionState == ConnectionState.done && snap.hasData && snap.data!.$1 != null;

        return PopupMenuButton<String>(
          tooltip: '발주서 보기',
          enabled: ready,
          onSelected: (v) {
            final (po, _raw, printLines) = snap.data!;
            final screen = (v == 'a4')
                ? PurchaseOrderPrintView(order: po!, lines: printLines)
                : PurchaseOrderPrintViewMobile(order: po!, lines: printLines);
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
