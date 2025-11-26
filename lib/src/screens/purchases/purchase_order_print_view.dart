import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_order.dart';

/// ① 출력용 라인 모델
class PrintLine {
  final String itemName;
  final String spec;
  final String colorNo;
  final String unit;
  final double qty;
  final double amount;
  final String memo;
  const PrintLine({
    required this.itemName,
    required this.spec,
    required this.colorNo,
    required this.unit,
    required this.qty,
    required this.amount,
    required this.memo,
  });
}

/// ② 메인 위젯: A4 고정, 핀치줌 지원
class PurchaseOrderPrintView extends StatelessWidget {
  final PurchaseOrder order;
  final List<PrintLine> lines;
  const PurchaseOrderPrintView({super.key, required this.order, required this.lines});

  // ────────────────────────────────────────────────────────────
  // Scaffold + A4 캔버스
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const double _a4W = 794;
    const double _a4H = 1123;
    final dateStr = DateFormat('yyyy.MM.dd(E)', 'ko_KR')
        .format(order.createdAt ?? DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('발주서')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaleW = constraints.maxWidth / _a4W;
            final scaleH = constraints.maxHeight / _a4H;
            final scale = scaleW < scaleH ? scaleW : scaleH;

            return Center(
              child: InteractiveViewer(
                minScale: scale,
                maxScale: 4.0,
                constrained: false,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                    child: Container(
                      width: _a4W,
                      height: _a4H,
                      color: Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: _buildA4Page(dateStr),
                    ),
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
  // ③ 실제 A4 페이지 내용
  // ────────────────────────────────────────────────────────────
  Widget _buildA4Page(String dateStr) {
    const hTitle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
    const hSection = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    const body = TextStyle(fontSize: 12);

    final supplier = (order.supplierName.trim().isEmpty ?? true)
        ? '(공급처 미지정)'
        : order.supplierName.trim();

    final sumAmount = lines.fold<double>(0, (p, e) => p + e.amount);
    final supply = sumAmount;
    final vat = (supply * 0.1).roundToDouble();
    final total = (supply + vat);

    return DefaultTextStyle.merge(
      style: body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('발   주   서', style: hTitle, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: Text(dateStr)),
          const Divider(thickness: 2),

          const SizedBox(height: 8),
          Text('[공급자] $supplier 귀하', style: hSection),
          const SizedBox(height: 12),

          const Text('[공급받는자] 자장노래', style: hSection),
          const SizedBox(height: 6),
          _buyerInfoTableSmall(),
          const SizedBox(height: 12),

          const Align(
            alignment: Alignment.centerRight,
            child: Text('아래와 같이 발주합니다.'),
          ),
          const SizedBox(height: 8),

          _itemsTableCompact(lines),
          _itemsTotalRow(lines),

          const Spacer(),

          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              children: [
                Text('공급금액: ${_fmtMoney(supply)}원'),
                Text('부가세: ${_fmtMoney(vat)}원'),
                Text(
                  '합계금액: ${_fmtMoney(total)}원',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _itemsTableCompact(List<PrintLine> lines) {
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    const cell = TextStyle(fontSize: 11);

    final header = TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF3F3F3)),
      children: const [
        _Th('No.', style: head),
        _Th('품명', style: head),
        _Th('색상코드', style: head),
        _Th('규격', style: head),
        _Th('단위', style: head),
        _Th('수량', style: head),
        _Th('금액', style: head),
        _Th('적요', style: head),
      ],
    );

    return Table(
      border: TableBorder.all(),
      columnWidths: const {
        0: FixedColumnWidth(32),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1.4), // 색상코드
        3: FlexColumnWidth(2),
        4: FixedColumnWidth(44),
        5: FixedColumnWidth(56),
        6: FlexColumnWidth(2),
        7: FlexColumnWidth(2),
      },
      children: [
        header,
        for (int i = 0; i < lines.length; i++)
          TableRow(
            children: [
              _Td('${i + 1}', style: cell),
              _Td(lines[i].itemName, style: cell),
              _Td(lines[i].colorNo, style: cell),
              _Td(lines[i].spec, style: cell),
              _Td(lines[i].unit, style: cell),
              _Td(_fmtNum(lines[i].qty), style: cell),
              _Td(_fmtMoney(lines[i].amount), style: cell),
              _Td(lines[i].memo, style: cell),
            ],
          ),
      ],
    );
  }
}

/// ④ 보조 위젯/유틸들
class _Th extends StatelessWidget {
  final String s;
  final TextStyle? style;
  const _Th(this.s, {this.style});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(4), child: Center(child: Text(s, style: style)));
}

class _Td extends StatelessWidget {
  final String s;
  final TextStyle? style;
  const _Td(this.s, {this.style});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(4), child: Text(s, textAlign: TextAlign.center, style: style));
}

class _Cell extends StatelessWidget {
  final String s;
  final bool bold;
  const _Cell(this.s, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: Text(s,
        style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
  );
}

String _fmtNum(num n) => n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);

String _fmtMoney(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && (idx - 1) % 3 == 0) buf.write(',');
  }
  return buf.toString();
}

// ────────────────────────────────────────────────────────────
// 공유: 공급받는자 표 (모든 화면에서 공용 사용)
// ────────────────────────────────────────────────────────────
Widget _buyerInfoTableSmall() {
  return Table(
    border: TableBorder.all(),
    columnWidths: const { 0: FixedColumnWidth(100), 1: FlexColumnWidth() },
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
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
// ─────────────────────────────────────────────
// 단위별 합계 + 총 금액 (예: 20 EA + 5 ROLL)
// ─────────────────────────────────────────────
Widget _itemsTotalRow(List<PrintLine> lines) {
  // 단위별 수량 합산
  final byUnit = <String, double>{};
  double totalAmount = 0;

  for (final l in lines) {
    byUnit[l.unit] = (byUnit[l.unit] ?? 0) + l.qty;
    totalAmount += l.amount;
  }

  // 예: "20 EA + 5 ROLL + 10 M"
  final qtyStr = byUnit.entries
      .map((e) => '${_fmtNum(e.value)} ${e.key}')
      .join(' + ');

  return Container(
    decoration: const BoxDecoration(
      border: Border(
        left: BorderSide(color: Colors.black87),
        right: BorderSide(color: Colors.black87),
        bottom: BorderSide(color: Colors.black87),
      ),
      color: Color(0xFFF9F9F9),
    ),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: Text(
      '(합계) 총 수량: $qtyStr  ',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      textAlign: TextAlign.right,
    ),
  );
}

// ────────────────────────────────────────────────────────────
// 모바일 친화 버전: 세로 전용 + 가로 스크롤 테이블
// ────────────────────────────────────────────────────────────
class PurchaseOrderPrintViewMobile extends StatelessWidget {
  final PurchaseOrder order;
  final List<PrintLine> lines;
  const PurchaseOrderPrintViewMobile({
    super.key,
    required this.order,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd(E)', 'ko_KR')
        .format(order.createdAt ?? DateTime.now());
    final supplier = (order.supplierName.trim().isEmpty ?? true)
        ? '(공급처 미지정)' : order.supplierName.trim();

    final sumAmount = lines.fold<double>(0, (p, e) => p + e.amount);
    final supply = sumAmount;
    final vat = (supply * 0.1).roundToDouble();
    final total = supply + vat;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('발주서(모바일용)')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  const Text('발   주   서',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerRight, child: Text(dateStr)),
                  const Divider(thickness: 2),

                  const SizedBox(height: 8),
                  Text('[공급자] $supplier 귀하',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  const Text('[공급받는자] 자장노래',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _buyerInfoTableSmall(),

                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('아래와 같이 발주합니다.'),
                  ),
                  const SizedBox(height: 8),

                  _itemsListTwoLine(lines),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      children: [
                        Text('공급금액: ${_fmtMoney(supply)}원'),
                        Text('부가세: ${_fmtMoney(vat)}원'),
                        Text('합계금액: ${_fmtMoney(total)}원',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
// 서류형 2줄 행: 1행(No/품명/수량·단위), 2행(규격·금액·적요)
// ────────────────────────────────────────────────────────────
  Widget _itemsListTwoLine(List<PrintLine> lines) {
    const head = TextStyle(fontSize: 13, fontWeight: FontWeight.bold);
    const cell = TextStyle(fontSize: 12);

    return Column(
      children: [
        // 헤더
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            border: Border.all(color: Colors.black87),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              SizedBox(width: 36, child: Center(child: Text('No', style: head))),
              const SizedBox(width: 8),
              Expanded(child: Text('품명', style: head)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('수량/단위', style: head),
                ),
              ),
            ],
          ),
        ),

        // 본문 행들
        ...List.generate(lines.length, (i) {
          final l = lines[i];
          return Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.black87),
                right: BorderSide(color: Colors.black87),
                bottom: BorderSide(color: Colors.black87),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ───── 1행: No | 품명(2줄) | 수량/단위 ─────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 36, child: Center(child: Text('${i + 1}', style: cell))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.itemName,
                        style: cell,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Text('${_fmtNum(l.qty)} ${l.unit}', style: cell),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ───── 2행: 규격·금액·적요 라벨 텍스트 ─────
                Wrap(
                  spacing: 16,
                  runSpacing: 2,
                  children: [
                    if (l.spec.isNotEmpty)
                      Text('규격: ${l.spec}', style: const TextStyle(fontSize: 11)),
                    if (l.colorNo.isNotEmpty)
                      Text('색상번호: ${l.colorNo}', style: const TextStyle(fontSize: 11)),

                    // Text('금액: ${_fmtMoney(l.amount)}원',
                    //     style: const TextStyle(fontSize: 11)),
                    if (l.memo.isNotEmpty)
                      Text('적요: ${l.memo}', style: const TextStyle(fontSize: 11)),
                  ],
                ),


              ],
            ),
          );
        }),
        _itemsTotalRow(lines), // ← 이 한 줄 추가

      ],
    );
  }



  Widget _pill(String k, String v, {int? max}) {
    final vv = (max != null && v.length > max) ? '${v.substring(0, max)}…' : v;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Text('$k: $vv', style: const TextStyle(fontSize: 11)),
    );
  }

}
