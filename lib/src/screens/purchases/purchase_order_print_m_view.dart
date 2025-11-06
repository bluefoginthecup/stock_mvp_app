// lib/src/screens/purchases/purchase_order_print_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_order.dart';

/// 출력용 라인 모델 (뷰 전용)
class PrintLine {
  final String itemName;
  final String spec;
  final String unit;
  final double qty;
  final double amount; // (단가*수량) 등 최종 금액
  final String memo;

  const PrintLine({
    required this.itemName,
    required this.spec,
    required this.unit,
    required this.qty,
    required this.amount,
    required this.memo,
  });
}

/// 실제 발주서(PDF/캡처)용 화면 (모바일 최적화: 모든 섹션 세로 배치)
class PurchaseOrderPrintView extends StatelessWidget {
  final PurchaseOrder order;
  final List<PrintLine> lines;

  const PurchaseOrderPrintView({
    super.key,
    required this.order,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd(E)', 'ko_KR')
        .format(order.createdAt ?? DateTime.now());

    final supplier = (order.supplierName?.trim().isEmpty ?? true)
        ? '(공급처 미지정)'
        : order.supplierName!.trim();

    final sumAmount = lines.fold<double>(0, (p, e) => p + (e.amount));
    final supply = sumAmount; // 필요시 공급가액/부가세 분리 계산 로직 연결
    final vat = (supply * 0.1).roundToDouble();
    final total = (supply + vat);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('발주서')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final pageW = screenW < 680 ? screenW : 640.0;

            return SingleChildScrollView(
              child: Center(
                child: Container(
                  width: pageW,
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(dateStr),
                      const SizedBox(height: 16),

                      // [공급자] 대우섬유 귀하  (세로 배치)
                      Text(
                        '[공급자] $supplier 귀하',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // [공급받는자] 표 (세로 배치)
                      const Text(
                        '[공급받는자] 자장노래',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buyerInfoTable(),

                      const SizedBox(height: 16),
                      const Text(
                        '위와 같이 발주합니다.',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      // 품목 테이블 (휴대폰에서 가로 스크롤 허용)
                      _itemsTableResponsive(lines),

                      const SizedBox(height: 12),
                      _totalsRow(supply: supply, vat: vat, total: total),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Sections
  // ────────────────────────────────────────────────────────────

  Widget _header(String dateStr) {
    return Column(
      children: [
        const Text(
          '발   주   서',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(dateStr, style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 2),
      ],
    );
  }

  Widget _buyerInfoTable() {
    return Table(
      border: TableBorder.all(),
      columnWidths: const {
        0: FixedColumnWidth(110),
        1: FlexColumnWidth(),
      },
      children: const [
        TableRow(children: [ _Cell('사업자등록번호', bold: true), _Cell('313-05-49582') ]),
        TableRow(children: [ _Cell('상호', bold: true), _Cell('자장노래') ]),
        TableRow(children: [ _Cell('대표자', bold: true), _Cell('장효정') ]),
        TableRow(children: [ _Cell('주소', bold: true), _Cell('충청남도 보령시 수산길 4, 1층 (대천동)') ]),
        TableRow(children: [ _Cell('업태/종목', bold: true), _Cell('제조업 / 침구류 기타') ]),
        TableRow(children: [ _Cell('전화/팩스', bold: true), _Cell('041-935-2855 / 0505-937-0558') ]),
      ],
    );
  }

  /// 모바일에서 가로폭이 좁으면 수평 스크롤이 생기도록 구성
  Widget _itemsTableResponsive(List<PrintLine> lines) {
    // 최소 표 폭(작아도 헤더가 깨지지 않게)
    const minTableWidth = 640.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: minTableWidth),
        child: Table(
          border: TableBorder.all(),
          columnWidths: const {
            0: FixedColumnWidth(44),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(2),
            3: FixedColumnWidth(56),
            4: FixedColumnWidth(72),
            5: FlexColumnWidth(2),
            6: FlexColumnWidth(2),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _itemsHeaderRow(),
            for (int i = 0; i < lines.length; i++) _itemRow(i + 1, lines[i]),
          ],
        ),
      ),
    );
  }

  TableRow _itemsHeaderRow() => const TableRow(
    decoration: BoxDecoration(color: Color(0xFFF3F3F3)),
    children: [
      _Th('No.'),
      _Th('품명'),
      _Th('규격'),
      _Th('단위'),
      _Th('수량'),
      _Th('금액'),
      _Th('적요'),
    ],
  );

  TableRow _itemRow(int idx, PrintLine l) => TableRow(
    children: [
      _Td('$idx'),
      _Td(l.itemName),
      _Td(l.spec),
      _Td(l.unit),
      _Td(_fmtNum(l.qty)),
      _Td(_fmtMoney(l.amount)),
      _Td(l.memo),
    ],
  );

  Widget _totalsRow({
    required double supply,
    required double vat,
    required double total,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('공급금액: ${_fmtMoney(supply)}원'),
          Text('부가세: ${_fmtMoney(vat)}원'),
          Text(
            '합계금액: ${_fmtMoney(total)}원',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Utils
  // ────────────────────────────────────────────────────────────

  static String _fmtNum(num n) {
    // 정수면 0자리, 소수 있으면 최대 2자리
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  static String _fmtMoney(num n) {
    // 천단위 콤마 (Intl NumberFormat을 써도 됨)
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && (idx - 1) % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }
}

// ────────────────────────────────────────────────────────────
// Small widgets
// ────────────────────────────────────────────────────────────

class _Th extends StatelessWidget {
  final String s;
  const _Th(this.s);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: Center(child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold))),
  );
}

class _Td extends StatelessWidget {
  final String s;
  const _Td(this.s);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(6), child: Text(s, textAlign: TextAlign.center));
}

class _Cell extends StatelessWidget {
  final String s;
  final bool bold;
  const _Cell(this.s, {this.bold = false});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(6), child: Text(s, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)));
}
