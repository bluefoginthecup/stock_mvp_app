import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/item.dart';
import '../../ui/common/ui.dart';
import '../../repos/inmem_repo.dart'; // ← 추가
import 'package:provider/provider.dart'; // ← 추가



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


  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이름은 필수입니다.')));
      return;
    }

    // pathIds -> folder/subfolder 이름 변환
    final repo = context.read<InMemoryRepo>();
    String? l1Name;
    String? l2Name;
    String? l3Name;
    if (widget.pathIds.isNotEmpty) {
      final l1 = repo.folderById(widget.pathIds[0]);
      l1Name = l1?.name;
    }
    if (widget.pathIds.length >= 2) {
      final l2 = repo.folderById(widget.pathIds[1]);
      l2Name = l2?.name;
    }

        if (widget.pathIds.length >= 3) {
          final l3 = repo.folderById(widget.pathIds[2]);
          l3Name = l3?.name;
        }

    // 필요하면 소문자 정규화(기존 시드가 'finished', 'raw'처럼 소문자였음)
    String? normalize(String? s) => s?.toLowerCase();

    final item = Item(
      id: _uuid.v4(),
      name: _nameC.text.trim(),
      sku: _skuC.text.trim(),
      unit: _unitC.text.trim().isEmpty ? 'EA' : _unitC.text.trim(),
      qty: int.tryParse(_qtyC.text) ?? 0,
      minQty: int.tryParse(_minC.text) ?? 0,

      // ✅ 필수 필드 채우기
      folder: normalize(l1Name) ?? 'uncategorized',
      // 선택 필드(모델에 있으면): 중분류
      subfolder: normalize(l2Name),
        // ✅ 3뎁스도 같이 기록
              subsubfolder: normalize(l3Name),
          // ✅ path 필드가 있다면 함께 저장 (모델에 path가 존재할 때)

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
