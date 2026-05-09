import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/buyer_profile.dart';
import '../../models/quote.dart';
import '../../models/quote_line.dart';

class QuotePrintView extends StatelessWidget {
  final Quote quote;
  final List<QuoteLine> lines;

  const QuotePrintView({
    super.key,
    required this.quote,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final captureKey = GlobalKey();
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적서'),
        actions: [
          IconButton(
            tooltip: 'JPG 공유',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _shareQuoteJpg(
              context,
              captureKey: captureKey,
              quote: quote,
            ),
          ),
        ],
      ),
      body: ColoredBox(
        color: Colors.grey.shade200,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: RepaintBoundary(
              key: captureKey,
              child: _QuotePage(quote: quote, lines: lines),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuotePage extends StatelessWidget {
  final Quote quote;
  final List<QuoteLine> lines;

  const _QuotePage({
    required this.quote,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy.MM.dd');
    final totals = QuoteTotals.fromLines(quote: quote, lines: lines);
    final supplier = quote.supplierSnapshotProfile;

    return Container(
      width: 794,
      height: 1123,
      color: Colors.white,
      padding: const EdgeInsets.all(48),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '견 적 서',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 36),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoLine(
                          '수신',
                          quote.customerName.trim().isEmpty
                              ? '거래처 미지정'
                              : quote.customerName),
                      _infoLine('견적일', dateFmt.format(quote.quoteDate)),
                      if (quote.validUntil != null)
                        _infoLine('유효기간', dateFmt.format(quote.validUntil!)),
                    ],
                  ),
                ),
                Text(
                    'No. ${quote.id.substring(0, quote.id.length < 8 ? quote.id.length : 8)}'),
              ],
            ),
            const SizedBox(height: 20),
            Text('[공급자] ${supplier.companyName}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _profileInfoTable(supplier),
            const SizedBox(height: 24),
            const Text('아래와 같이 견적합니다.'),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FixedColumnWidth(58),
                2: FixedColumnWidth(58),
                3: FixedColumnWidth(82),
                4: FixedColumnWidth(96),
                5: FixedColumnWidth(78),
              },
              border: TableBorder.all(color: Colors.black87),
              children: [
                _row(
                  const ['품목', '수량', '단위', '단가', '공급금액', '세액'],
                  header: true,
                ),
                for (final line in lines)
                  _row([
                    line.memo == null || line.memo!.trim().isEmpty
                        ? line.name
                        : '${line.name}\n${line.memo}',
                    _num(line.qty),
                    line.unit,
                    _money(_quoteLineUnitSupplyPrice(line)),
                    _money(line.supplyAmount),
                    _money(line.vatAmount),
                  ]),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 310,
                child: Table(
                  border: TableBorder.all(color: Colors.black87),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1),
                  },
                  children: [
                    _totalRow('공급금액', totals.subtotal),
                    if (totals.discount > 0) _totalRow('할인', -totals.discount),
                    if (totals.shipping > 0)
                      _totalRow('배송/기타', totals.shipping),
                    _totalRow('부가세', totals.vat),
                    _totalRow('총 금액', totals.total, bold: true),
                  ],
                ),
              ),
            ),
            if ((quote.memo ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('비고', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(quote.memo!.trim()),
            ],
            const Spacer(),
            const Text(
              '상기 견적은 유효기간 및 품목 조건에 따라 변동될 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class QuotePrintViewMobile extends StatelessWidget {
  final Quote quote;
  final List<QuoteLine> lines;

  const QuotePrintViewMobile({
    super.key,
    required this.quote,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final captureKey = GlobalKey();
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적서(모바일용)'),
        actions: [
          IconButton(
            tooltip: 'JPG 공유',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _shareQuoteJpg(
              context,
              captureKey: captureKey,
              quote: quote,
            ),
          ),
        ],
      ),
      body: ColoredBox(
        color: Colors.grey.shade200,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: RepaintBoundary(
              key: captureKey,
              child: _QuoteMobilePage(quote: quote, lines: lines),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteMobilePage extends StatelessWidget {
  final Quote quote;
  final List<QuoteLine> lines;

  const _QuoteMobilePage({
    required this.quote,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy.MM.dd');
    final totals = QuoteTotals.fromLines(quote: quote, lines: lines);
    final customer =
        quote.customerName.trim().isEmpty ? '거래처 미지정' : quote.customerName;
    final supplier = quote.supplierSnapshotProfile;

    return Container(
      width: 390,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '견 적 서',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _mobileInfoLine('수신', customer),
            _mobileInfoLine('견적일', dateFmt.format(quote.quoteDate)),
            if (quote.validUntil != null)
              _mobileInfoLine('유효기간', dateFmt.format(quote.validUntil!)),
            _mobileInfoLine(
              '견적번호',
              quote.id.substring(0, quote.id.length < 8 ? quote.id.length : 8),
            ),
            const SizedBox(height: 12),
            const Text('공급자', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _mobileInfoLine('상호', supplier.companyName),
            _mobileInfoLine('대표', supplier.representative),
            _mobileInfoLine('사업자번호', supplier.businessNumber),
            if (supplier.address.trim().isNotEmpty)
              _mobileInfoLine('주소', supplier.address),
            if (supplier.phoneFax.trim().isNotEmpty)
              _mobileInfoLine('연락처', supplier.phoneFax),
            const SizedBox(height: 18),
            const Text('아래와 같이 견적합니다.'),
            const SizedBox(height: 12),
            for (final line in lines) _mobileLineCard(line),
            if (lines.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                ),
                child: const Text('견적 품목이 없습니다.', textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87),
              ),
              child: Column(
                children: [
                  _mobileTotalLine('공급금액', totals.subtotal),
                  if (totals.discount > 0)
                    _mobileTotalLine('할인', -totals.discount),
                  if (totals.shipping > 0)
                    _mobileTotalLine('배송/기타', totals.shipping),
                  _mobileTotalLine('부가세', totals.vat),
                  _mobileTotalLine('총 금액', totals.total, bold: true),
                ],
              ),
            ),
            if ((quote.memo ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('비고', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(quote.memo!.trim()),
            ],
            const SizedBox(height: 28),
            const Text(
              '상기 견적은 유효기간 및 품목 조건에 따라 변동될 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _infoLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Widget _profileInfoTable(BuyerProfile profile) {
  final business = [
    profile.businessType.trim(),
    profile.businessItem.trim(),
  ].where((value) => value.isNotEmpty).join(' / ');

  return Table(
    border: TableBorder.all(color: Colors.black87),
    columnWidths: const {
      0: FixedColumnWidth(92),
      1: FlexColumnWidth(1),
      2: FixedColumnWidth(92),
      3: FlexColumnWidth(1),
    },
    children: [
      _profileRow('사업자번호', profile.businessNumber, '상호', profile.companyName),
      _profileRow('대표자', profile.representative, '업태/종목', business),
      TableRow(
        children: [
          _profileCell('주소', bold: true),
          _profileCell(profile.address),
          _profileCell('연락처', bold: true),
          _profileCell(profile.phoneFax),
        ],
      ),
    ],
  );
}

TableRow _profileRow(
  String label1,
  String value1,
  String label2,
  String value2,
) {
  return TableRow(
    children: [
      _profileCell(label1, bold: true),
      _profileCell(value1),
      _profileCell(label2, bold: true),
      _profileCell(value2),
    ],
  );
}

Widget _profileCell(String text, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.all(7),
    child: Text(
      text.trim().isEmpty ? '-' : text.trim(),
      style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
    ),
  );
}

Widget _mobileInfoLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Widget _mobileLineCard(QuoteLine line) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black38),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          line.name,
          textAlign: TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if ((line.memo ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            line.memo!.trim(),
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        _mobileAmountRow(
          '${_num(line.qty)} ${line.unit}',
          '단가 ${_money(_quoteLineUnitSupplyPrice(line))}',
        ),
        _mobileAmountRow('공급금액', _money(line.supplyAmount)),
        _mobileAmountRow('세액', _money(line.vatAmount)),
        _mobileAmountRow('금액', _money(line.totalAmount), bold: true),
      ],
    ),
  );
}

Widget _mobileAmountRow(String label, String value, {bool bold = false}) {
  final style =
      TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, textAlign: TextAlign.left, style: style)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: style)),
      ],
    ),
  );
}

Widget _mobileTotalLine(String label, double value, {bool bold = false}) {
  final style =
      TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.black26)),
    ),
    child: Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(_money(value), style: style),
      ],
    ),
  );
}

TableRow _row(List<String> cells, {bool header = false}) {
  final style = TextStyle(
    fontWeight: header ? FontWeight.bold : FontWeight.normal,
    fontSize: 13,
  );
  return TableRow(
    decoration: header ? BoxDecoration(color: Colors.grey.shade200) : null,
    children: cells
        .map(
          (cell) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(cell,
                style: style,
                textAlign: cells.indexOf(cell) == 0
                    ? TextAlign.left
                    : TextAlign.right),
          ),
        )
        .toList(),
  );
}

TableRow _totalRow(String label, double value, {bool bold = false}) {
  final style =
      TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
  return TableRow(
    children: [
      Padding(
          padding: const EdgeInsets.all(8), child: Text(label, style: style)),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(_money(value), textAlign: TextAlign.right, style: style),
      ),
    ],
  );
}

String _num(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
String _money(double value) => NumberFormat('#,##0').format(value);
double _quoteLineUnitSupplyPrice(QuoteLine line) =>
    line.qty == 0 ? 0 : (line.supplyAmount / line.qty).roundToDouble();

Future<void> _shareQuoteJpg(
  BuildContext context, {
  required GlobalKey captureKey,
  required Quote quote,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    final boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('견적서 이미지를 만들 수 없습니다.');
    final captured = await boundary.toImage(pixelRatio: 2);
    final byteData = await captured.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List();
    if (pngBytes == null) throw StateError('견적서 이미지 변환에 실패했습니다.');
    final decoded = image_lib.decodePng(pngBytes);
    if (decoded == null) throw StateError('견적서 이미지 인코딩에 실패했습니다.');
    final jpgBytes = image_lib.encodeJpg(decoded, quality: 88);
    final tempDir = await getTemporaryDirectory();
    final subject =
        '견적서_${_safeFileName(quote.customerName)}_${DateFormat('yyyyMMdd').format(quote.quoteDate)}';
    final outFile = File('${tempDir.path}/$subject.jpg');
    await outFile.writeAsBytes(jpgBytes, flush: true);
    await Share.shareXFiles(
      [XFile(outFile.path, mimeType: 'image/jpeg', name: '$subject.jpg')],
      subject: subject,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('견적서 JPG 내보내기에 실패했습니다: $e')),
    );
  }
}

String _safeFileName(String value) {
  final trimmed = value.trim().isEmpty ? '거래처미지정' : value.trim();
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
