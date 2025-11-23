import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../ui/common/ui.dart';
import '../../repos/repo_interfaces.dart'; // ItemRepo, FolderTreeRepo

class StockNewItemSheet extends StatefulWidget {
  const StockNewItemSheet({super.key, required this.pathIds});

  final List<String> pathIds; // [l1Id, l2Id, l3Id]

  @override
  State<StockNewItemSheet> createState() => _StockNewItemSheetState();
}

class _StockNewItemSheetState extends State<StockNewItemSheet> {
  final _nameC = TextEditingController();
  final _skuC = TextEditingController();
  final _unitC = TextEditingController(text: 'EA');
  final _minC = TextEditingController(text: '5');
  final _qtyC = TextEditingController(text: '0');
  final _uuid = const Uuid();

  @override
  void dispose() {
    _nameC.dispose();
    _skuC.dispose();
    _unitC.dispose();
    _minC.dispose();
    _qtyC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이름은 필수입니다.')));
      return;
    }

    // pathIds -> folder/subfolder 이름 변환 (FolderTreeRepo 사용, 비동기)
    final folders = context.read<FolderTreeRepo>();

    String? l1Name;
    String? l2Name;
    String? l3Name;

    if (widget.pathIds.isNotEmpty) {
      final l1 = await folders.folderById(widget.pathIds[0]);
      l1Name = l1?.name;
    }
    if (widget.pathIds.length >= 2) {
      final l2 = await folders.folderById(widget.pathIds[1]);
      l2Name = l2?.name;
    }
    if (widget.pathIds.length >= 3) {
      final l3 = await folders.folderById(widget.pathIds[2]);
      l3Name = l3?.name;
    }

    // 필요하면 소문자 정규화
    String? normalize(String? s) => s?.toLowerCase();

    final item = Item(
      id: _uuid.v4(),
      name: _nameC.text.trim(),
      displayName: null, // 필요시 name과 동일하게 세팅 가능
      sku: _skuC.text.trim(),
      unit: _unitC.text.trim().isEmpty ? 'EA' : _unitC.text.trim(),
      qty: int.tryParse(_qtyC.text) ?? 0,
      minQty: int.tryParse(_minC.text) ?? 0,

      // 경로 필드
      folder: normalize(l1Name) ?? 'uncategorized',
      subfolder: normalize(l2Name),
      subsubfolder: normalize(l3Name),

      // 그 외 선택 필드들은 기본값 유지
      kind: null,
      attrs: null,
      unitIn: null,
      unitOut: null,
      conversionRate: null,
      conversionMode: 'fixed',
      stockHints: null,
      supplierName: null,
      isFavorite: false,
    );

    if (!mounted) return;
    Navigator.pop<Item>(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('새 아이템', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: _nameC, decoration: const InputDecoration(labelText: '이름')),
            const SizedBox(height: 8),
            TextField(controller: _skuC, decoration: const InputDecoration(labelText: 'SKU(코드)')),
            const SizedBox(height: 8),
            TextField(controller: _unitC, decoration: const InputDecoration(labelText: '단위(EA/M 등)')),
            const SizedBox(height: 8),
            TextField(controller: _qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '초기 재고 수량')),
            const SizedBox(height: 8),
            TextField(controller: _minC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '임계치(재주문 최소)')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
