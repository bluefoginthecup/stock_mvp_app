// lib/src/screens/purchases/purchase_order_print_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_order.dart';

class PrintLine {
  final String itemName;
  final String spec;
  final String unit;
  final double qty;
  final double amount; // 단가*수량 등 계산값 (지금은 0도 무방)
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
                      _supplierAndIssuer(order),
                      const SizedBox(height: 16),
                      _itemTable(lines),
                      const SizedBox(height: 8),
                      const Text('====== 이하 여백 ======', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('위와 같이 발주합니다.', style: TextStyle(fontSize: 16)),
                      ),
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

  Widget _header(String dateStr) {
    return Column(
      children: [
        const Text('발　주　서',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Align(
          alignment: Alignment.centerRight,
          child: Text(dateStr, style: const TextStyle(fontSize: 14)),
        ),
        const Divider(thickness: 2),
      ],
    );
  }

  Widget _supplierAndIssuer(PurchaseOrder p) {
    final supplier = (p.supplierName?.trim().isEmpty ?? true)
        ? '(공급처 미지정)'
        : p.supplierName!.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좌측: 수신
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              // 상단 굵은 글씨는 아래 Table과 간격상 생략하고 표준화 유지해도 좋음
              // 필요하면 Text('$supplier 귀하', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('공급금액: 0원'),
              Text('부가세: 0원'),
              Text('합계금액: 0원'),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // 우측: 발주자 정보 표
        Expanded(
          child: Table(
            border: TableBorder.all(),
            columnWidths: const {
              0: FixedColumnWidth(100),
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
          ),
        ),
      ],
    );
  }

  Widget _itemTable(List<PrintLine> lines) {
    return Table(
      border: TableBorder.all(),
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(2),
        6: FlexColumnWidth(2),
      },
      children: [
        _headerRow(),
        for (int i = 0; i < lines.length; i++) _dataRow(i + 1, lines[i]),
      ],
    );
  }

  TableRow _headerRow() => TableRow(
    decoration: const BoxDecoration(color: Color(0xfff3f3f3)),
    children: const [
      _Th('No.'),
      _Th('품명'),
      _Th('규격'),
      _Th('단위'),
      _Th('수량'),
      _Th('금액'),
      _Th('적요'),
    ],
  );

  TableRow _dataRow(int idx, PrintLine l) => TableRow(
    children: [
      _Td('$idx'),
      _Td(l.itemName),
      _Td(l.spec),
      _Td(l.unit),
      _Td(_fmtNum(l.qty)),
      _Td(_fmtNum(l.amount)),
      _Td(l.memo),
    ],
  );

  static String _fmtNum(num n) {
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }
}

class _Th extends StatelessWidget {
  final String s;
  const _Th(this.s);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: Center(
      child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: Text(s, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
  );
}
