import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../models/quote_line.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/item_picker_sheet.dart';

class QuoteLineEditScreen extends StatefulWidget {
  final String quoteId;
  final QuoteLine? initial;

  const QuoteLineEditScreen({
    super.key,
    required this.quoteId,
    this.initial,
  });

  @override
  State<QuoteLineEditScreen> createState() => _QuoteLineEditScreenState();
}

class _QuoteLineEditScreenState extends State<QuoteLineEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemIdC;
  late final TextEditingController _nameC;
  late final TextEditingController _unitC;
  late final TextEditingController _qtyC;
  late final TextEditingController _priceC;
  late final TextEditingController _memoC;
  late final String _lineId;

  @override
  void initState() {
    super.initState();
    final line = widget.initial;
    _lineId = line?.id ?? const Uuid().v4();
    _itemIdC = TextEditingController(text: line?.itemId ?? '');
    _nameC = TextEditingController(text: line?.name ?? '');
    _unitC = TextEditingController(text: line?.unit ?? 'EA');
    _qtyC = TextEditingController(text: (line?.qty ?? 1).toString());
    _priceC = TextEditingController(text: (line?.unitPrice ?? 0).toString());
    _memoC = TextEditingController(text: line?.memo ?? '');
  }

  @override
  void dispose() {
    _itemIdC.dispose();
    _nameC.dispose();
    _unitC.dispose();
    _qtyC.dispose();
    _priceC.dispose();
    _memoC.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final itemRepo = context.read<ItemRepo>();
    final pickedId = await showItemPickerSheet(
      context,
      initialItemId: _itemIdC.text.trim().isEmpty ? null : _itemIdC.text.trim(),
      title: '견적 품목 검색',
    );
    if (pickedId == null || pickedId.isEmpty) return;
    final item = await itemRepo.getItem(pickedId);
    if (!mounted) return;
    if (item == null) {
      setState(() => _itemIdC.text = pickedId);
      return;
    }
    _applyItem(item);
  }

  void _applyItem(Item item) {
    setState(() {
      _itemIdC.text = item.id;
      _nameC.text = item.displayName ?? item.name;
      _unitC.text = item.unitOut.isNotEmpty ? item.unitOut : item.unit;
      final price = item.defaultSalePrice ?? item.defaultPrice;
      if (price != null && price > 0) {
        _priceC.text = price.toString();
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final qty = double.tryParse(_qtyC.text.trim()) ?? 0;
    final price = double.tryParse(_priceC.text.trim()) ?? 0;
    Navigator.pop(
      context,
      QuoteLine(
        id: _lineId,
        quoteId: widget.quoteId,
        itemId: _itemIdC.text.trim(),
        name: _nameC.text.trim(),
        unit: _unitC.text.trim().isEmpty ? 'EA' : _unitC.text.trim(),
        qty: qty,
        unitPrice: price,
        memo: _memoC.text.trim().isEmpty ? null : _memoC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? '견적 품목 추가' : '견적 품목 수정'),
        actions: [
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameC,
              decoration: InputDecoration(
                labelText: '품목명',
                suffixIcon: IconButton(
                  tooltip: '품목 검색',
                  icon: const Icon(Icons.search),
                  onPressed: _pickItem,
                ),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '품목명을 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitC,
              decoration: const InputDecoration(labelText: '단위'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '수량'),
              validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0
                  ? '수량을 입력하세요'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '단가'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoC,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '품목 메모'),
            ),
          ],
        ),
      ),
    );
  }
}
