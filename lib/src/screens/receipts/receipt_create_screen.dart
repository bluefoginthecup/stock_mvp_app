import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../utils/invoice_parser.dart';

class ReceiptCreateScreen extends StatefulWidget {
  const ReceiptCreateScreen({super.key});
  @override
  State<ReceiptCreateScreen> createState() => _ReceiptCreateScreenState();
}

class _ReceiptCreateScreenState extends State<ReceiptCreateScreen> {
  final _picker = ImagePicker();
  late final TextRecognizer _recognizer;
  File? _image;
  List<String> _ocrLines = [];
  List<ParsedInvoiceLine> _items = [];
  String? _supplierGuess;
  final _supplierC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recognizer = TextRecognizer(script: TextRecognitionScript.korean);
  }

  @override
  void dispose() {
    _recognizer.close();
    _supplierC.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    final picked = await _picker.pickImage(source: src, imageQuality: 95);
    if (picked == null) return;
    setState(() => _image = File(picked.path));
    await _runOcr();
  }

  Future<void> _runOcr() async {
    if (_image == null) return;
    final input = InputImage.fromFile(_image!);
    final result = await _recognizer.processImage(input);

    final lines = <String>[];
    for (final b in result.blocks) {
      for (final l in b.lines) {
        final t = l.text.trim();
        if (t.isNotEmpty) lines.add(t);
      }
    }

    final items = <ParsedInvoiceLine>[];
    for (final t in lines) {
      final p = parseInvoiceTextLine(t);
      if (p != null) items.add(p);
    }

    final supplier = _guessSupplierName(lines);
    setState(() {
      _ocrLines = lines;
      _items = items;
      _supplierGuess = supplier;
      _supplierC.text = supplier ?? '';
    });

    // 콘솔 확인
    // ignore: avoid_print
    print('🔹 OCR 원문:'); for (final l in lines) { print(l); }
    // ignore: avoid_print
    print('🔸 파싱 결과:'); for (final p in items) { print(p); }
    // ignore: avoid_print
    print('🧾 공급처 후보: ${supplier ?? "(없음)"}');
  }

  String? _guessSupplierName(List<String> lines) {
    // 후보 키워드 우선 탐색
    final keys = ['거래처','공급자','공급처','상호','상호명','판매자','Supplier','Seller'];
    for (final l in lines) {
      for (final k in keys) {
        final idx = l.indexOf(k);
        if (idx >= 0) {
          // "거래처:(주)대원섬유" / "상호  자장노래홈데코" 등 패턴 분해
          final tail = l.substring(idx + k.length).replaceAll(':', '').trim();
          if (tail.isNotEmpty && !_looksLikeAddress(tail)) return _cleanName(tail);
        }
      }
    }
    // 키워드가 없을 때 상단쪽 회사명 형태 추정: (주), 주식회사, Co., Ltd, 상호 등
    for (int i = 0; i < lines.length && i < 8; i++) {
      final t = lines[i];
      if (RegExp(r'(\(주\)|주식회사|Co\.?,?\s*Ltd|상호|회사명)').hasMatch(t)) {
        return _cleanName(t);
      }
    }
    return null;
  }

  bool _looksLikeAddress(String s) =>
      RegExp(r'(시|구|동|로\s*\d|번지|\d{3}-\d{3})').hasMatch(s);

  String _cleanName(String s) {
    return s
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'[|·•▶▷\-–—]'), ' ')
        .trim();
  }

  Future<void> _save() async {
    // TODO: 실제 저장 로직
    // - 이미지 경로, OCR 원문, supplierName(수정 가능), 파싱된 아이템 라인들
    // - 필요시 ItemRepo upsert / SupplierRepo 매칭
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('임시 저장 완료 (저장 로직 연결 필요)')),
    );
    Navigator.of(context).pop(); // 저장 후 목록으로
  }

  void _showPickSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('갤러리에서 선택'),
            onTap: () { Navigator.pop(context); _pick(ImageSource.gallery); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('카메라로 촬영'),
            onTap: () { Navigator.pop(context); _pick(ImageSource.camera); },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _image != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래명세서 등록'),
        actions: [
          TextButton(
            onPressed: (_items.isNotEmpty || hasImage) ? _save : null,
            child: const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPickSheet,
        child: const Icon(Icons.add_a_photo),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_image!, height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _supplierC,
            decoration: InputDecoration(
              labelText: '거래처(추출 결과 수정 가능)',
              hintText: '예: (주)대원섬유',
              prefixIcon: const Icon(Icons.store),
              suffixIcon: (_supplierGuess != null)
                  ? const Icon(Icons.auto_awesome, size: 18)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            const Text('파싱된 아이템이 없습니다. + 버튼으로 사진을 업로드하세요.')
          else
            _ParsedItemsTable(items: _items),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 파싱 결과 테이블
class _ParsedItemsTable extends StatelessWidget {
  final List<ParsedInvoiceLine> items;
  const _ParsedItemsTable({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('품명/설명')),
          DataColumn(label: Text('규격')),
          DataColumn(label: Text('색상')),
          DataColumn(label: Text('수량')),
          DataColumn(label: Text('단가')),
        ],
        rows: items.map((e) {
          return DataRow(cells: [
            DataCell(Text(e.nameRaw)),
            DataCell(Text(e.spec ?? '')),
            DataCell(Text(e.color ?? '')),
            DataCell(Text(e.qty?.toString() ?? '')),
            DataCell(Text(e.unitPrice?.toString() ?? '')),
          ]);
        }).toList(),
      ),
    );
  }
}
