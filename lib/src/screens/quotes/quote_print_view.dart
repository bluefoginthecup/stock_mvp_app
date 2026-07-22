import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/buyer_profile.dart';
import '../../models/quote.dart';
import '../../models/quote_line.dart';
import '../../repos/repo_interfaces.dart';
import '../../db/app_database.dart';
import '../../services/business_document_service.dart';

enum QuoteDocumentType {
  quote(
    title: '견적서',
    pageTitle: '견 적 서',
    dateLabel: '견적일',
    statement: '아래와 같이 견적합니다.',
    showsValidity: true,
  ),
  delivery(
    title: '납품서',
    pageTitle: '납 품 서',
    dateLabel: '납품일',
    statement: '아래와 같이 납품합니다.',
    showsValidity: false,
  ),
  transactionStatement(
    title: '거래명세서',
    pageTitle: '거 래 명 세 서',
    dateLabel: '납품일',
    statement: '아래와 같이 계산합니다.',
    showsValidity: false,
  );

  const QuoteDocumentType({
    required this.title,
    required this.pageTitle,
    required this.dateLabel,
    required this.statement,
    required this.showsValidity,
  });

  final String title;
  final String pageTitle;
  final String dateLabel;
  final String statement;
  final bool showsValidity;
}

class QuotePrintView extends StatefulWidget {
  final Quote quote;
  final List<QuoteLine> lines;
  final QuoteDocumentType documentType;

  const QuotePrintView({
    super.key,
    required this.quote,
    required this.lines,
    this.documentType = QuoteDocumentType.quote,
  });

  @override
  State<QuotePrintView> createState() => _QuotePrintViewState();
}

class _QuotePrintViewState extends State<QuotePrintView> {
  final GlobalKey _captureKey = GlobalKey();
  late DateTime _documentDate;

  @override
  void initState() {
    super.initState();
    _documentDate = widget.quote.deliveryDate ?? widget.quote.quoteDate;
  }

  Future<void> _selectDocumentDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '납품일 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (selected == null || !mounted) return;
    await context.read<QuoteRepo>().updateQuote(
          widget.quote.copyWith(deliveryDate: selected),
        );
    if (!mounted) return;
    setState(() => _documentDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentType.title),
        actions: [
          if (widget.documentType != QuoteDocumentType.quote)
            IconButton(
              tooltip: '납품일 선택',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _selectDocumentDate,
            ),
          IconButton(
            tooltip: 'JPG 공유',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _shareQuoteJpg(
              context,
              captureKey: _captureKey,
              quote: widget.quote,
              pixelRatio: 2,
              documentType: widget.documentType,
              documentDate: _documentDate,
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
              key: _captureKey,
              child: _BusinessDocumentsLoadedPage(
                profileId: widget.quote.supplierProfileId ?? 1,
                builder: (documents) => _QuotePage(
                  quote: widget.quote,
                  lines: widget.lines,
                  stampBytes: documents[BusinessDocumentKind.stamp]?.bytes,
                  documentType: widget.documentType,
                  documentDate: _documentDate,
                ),
              ),
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
  final Uint8List? stampBytes;
  final QuoteDocumentType documentType;
  final DateTime documentDate;

  const _QuotePage({
    required this.quote,
    required this.lines,
    required this.stampBytes,
    required this.documentType,
    required this.documentDate,
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
            Text(
              documentType.pageTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
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
                      _infoLine(
                        documentType.dateLabel,
                        dateFmt.format(documentDate),
                      ),
                      if (documentType.showsValidity &&
                          quote.validUntil != null)
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
            _profileInfoTable(supplier, stampBytes: stampBytes),
            const SizedBox(height: 24),
            Text(documentType.statement),
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
            if (documentType.showsValidity)
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
              pixelRatio: 1,
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
              child: _BusinessDocumentsLoadedPage(
                profileId: quote.supplierProfileId ?? 1,
                builder: (documents) => _QuoteMobilePage(
                  quote: quote,
                  lines: lines,
                  stampBytes: documents[BusinessDocumentKind.stamp]?.bytes,
                ),
              ),
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
  final Uint8List? stampBytes;

  const _QuoteMobilePage({
    required this.quote,
    required this.lines,
    required this.stampBytes,
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
            _mobileRepresentativeLine(
              supplier.representative,
              stampBytes: stampBytes,
            ),
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

class _BusinessDocumentsLoadedPage extends StatelessWidget {
  final int profileId;
  final Widget Function(Map<BusinessDocumentKind, BusinessDocument> documents)
      builder;

  const _BusinessDocumentsLoadedPage({
    required this.profileId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<BusinessDocumentKind, BusinessDocument>>(
      future: BusinessDocumentService(context.read<AppDatabase>())
          .loadForProfile(profileId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 120,
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(snapshot.data ?? const {});
      },
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

Widget _mobileRepresentativeLine(
  String representative, {
  required Uint8List? stampBytes,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 72,
          child: Text('대표', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(representative)),
        if (stampBytes != null) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            height: 58,
            child: Image.memory(stampBytes, fit: BoxFit.contain),
          ),
        ],
      ],
    ),
  );
}

Widget _profileInfoTable(
  BuyerProfile profile, {
  required Uint8List? stampBytes,
}) {
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
      TableRow(
        children: [
          _profileCell('대표자', bold: true, height: 64),
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(profile.representative)),
                  if (stampBytes != null) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Image.memory(stampBytes, fit: BoxFit.contain),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _profileCell('업태/종목', bold: true, height: 64),
          _profileCell(business, height: 64),
        ],
      ),
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

Widget _profileCell(String text, {bool bold = false, double? height}) {
  return SizedBox(
    height: height,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Text(
          text.trim().isEmpty ? '-' : text.trim(),
          style:
              TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    ),
  );
}

Widget _mobileInfoLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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

List<image_lib.Image> _quoteImagesForMessageShare(image_lib.Image source) {
  const maxLongSide = 8192;
  const maxSliceHeight = 3200;
  final longSide = source.width > source.height ? source.width : source.height;
  final resized = longSide <= maxLongSide
      ? source
      : source.width >= source.height
          ? image_lib.copyResize(source, width: maxLongSide)
          : image_lib.copyResize(source, height: maxLongSide);

  if (resized.height <= maxSliceHeight) {
    return [resized];
  }

  final slices = <image_lib.Image>[];
  for (var y = 0; y < resized.height; y += maxSliceHeight) {
    final sliceHeight = (y + maxSliceHeight > resized.height)
        ? resized.height - y
        : maxSliceHeight;
    slices.add(image_lib.copyCrop(
      resized,
      x: 0,
      y: y,
      width: resized.width,
      height: sliceHeight,
    ));
  }
  return slices;
}

Future<void> _shareQuoteJpg(
  BuildContext context, {
  required GlobalKey captureKey,
  required Quote quote,
  required double pixelRatio,
  QuoteDocumentType documentType = QuoteDocumentType.quote,
  DateTime? documentDate,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    final documents = await BusinessDocumentService(context.read<AppDatabase>())
        .loadForProfile(quote.supplierProfileId ?? 1);
    if (!context.mounted) return;
    final selectedKinds = await _selectShareDocuments(context, documents);
    if (selectedKinds == null || !context.mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('${documentType.title} 이미지를 만들 수 없습니다.');
    }
    if (boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }
    final captured = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await captured.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List();
    if (pngBytes == null) {
      throw StateError('${documentType.title} 이미지 변환에 실패했습니다.');
    }
    final decoded = image_lib.decodePng(pngBytes);
    if (decoded == null) {
      throw StateError('${documentType.title} 이미지 인코딩에 실패했습니다.');
    }
    final quoteImages = _quoteImagesForMessageShare(decoded);
    final subject =
        '${documentType.title}_${_safeFileName(quote.customerName)}_${DateFormat('yyyyMMdd').format(documentDate ?? quote.quoteDate)}';
    final tempDir = await getTemporaryDirectory();
    final shareDir = await tempDir.createTemp('${_safeFileName(subject)}_');
    final shareFiles = <XFile>[];
    final fileNameOverrides = <String>[];
    for (var i = 0; i < quoteImages.length; i++) {
      final pageSuffix = quoteImages.length == 1 ? '' : '_${i + 1}';
      final fileName = _prefixedFileName(i + 1, '$subject$pageSuffix.jpg');
      final jpgBytes = image_lib.encodeJpg(quoteImages[i], quality: 82);
      final file = File('${shareDir.path}/$fileName');
      await file.writeAsBytes(jpgBytes, flush: true);
      shareFiles.add(XFile(file.path, mimeType: 'image/jpeg'));
      fileNameOverrides.add(fileName);
    }
    var attachmentIndex = quoteImages.length + 1;
    for (final kind in selectedKinds) {
      final document = documents[kind];
      if (document == null) continue;
      final fileName = _prefixedFileName(
        attachmentIndex++,
        _safeFileName(document.fileName),
      );
      shareFiles
          .add(XFile.fromData(document.bytes, mimeType: document.mimeType));
      fileNameOverrides.add(fileName);
    }
    await Share.shareXFiles(
      shareFiles,
      subject: subject,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      fileNameOverrides: fileNameOverrides,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${documentType.title} JPG 내보내기에 실패했습니다: $e')),
    );
  }
}

Future<Set<BusinessDocumentKind>?> _selectShareDocuments(
  BuildContext context,
  Map<BusinessDocumentKind, BusinessDocument> documents,
) async {
  final available = [
    BusinessDocumentKind.registration,
    BusinessDocumentKind.bankAccount,
  ].where(documents.containsKey).toList();
  if (available.isEmpty) return <BusinessDocumentKind>{};

  final selected = <BusinessDocumentKind>{};
  return showDialog<Set<BusinessDocumentKind>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('함께 보낼 파일'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('견적서와 함께 전송할 첨부 파일을 선택하세요.'),
            const SizedBox(height: 8),
            for (final kind in available)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(kind.label),
                subtitle: Text(documents[kind]!.fileName),
                value: selected.contains(kind),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      selected.add(kind);
                    } else {
                      selected.remove(kind);
                    }
                  });
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop({...selected}),
            child: const Text('공유'),
          ),
        ],
      ),
    ),
  );
}

String _safeFileName(String value) {
  final trimmed = value.trim().isEmpty ? '거래처미지정' : value.trim();
  return trimmed
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
}

String _prefixedFileName(int index, String fileName) {
  final safeName = _safeFileName(fileName);
  final padded = index.toString().padLeft(2, '0');
  return '${padded}_$safeName';
}
