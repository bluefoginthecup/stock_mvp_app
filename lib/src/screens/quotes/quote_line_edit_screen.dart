import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../models/purchase_order.dart';
import '../../models/quote.dart';
import '../../models/quote_line.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/item_picker_sheet.dart';
import '../../utils/line_amount_calculator.dart';

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
  late final TextEditingController _supplyAmountC;
  late final TextEditingController _vatAmountC;
  late final TextEditingController _totalAmountC;
  late final TextEditingController _memoC;
  late final String _lineId;
  VatType _vatType = VatType.exclusive;
  bool _vatTypeTouched = false;
  bool _amountEdited = false;

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
    _vatType = line?.vatType ?? VatType.exclusive;
    _amountEdited = line?.amountEdited ?? false;
    final initialAmount = line == null
        ? const LineAmountBreakdown(
            supplyAmount: 0,
            vatAmount: 0,
            totalAmount: 0,
          )
        : LineAmountBreakdown(
            supplyAmount: line.supplyAmount,
            vatAmount: line.vatAmount,
            totalAmount: line.totalAmount,
          );
    _supplyAmountC = TextEditingController(
        text: initialAmount.supplyAmount.toStringAsFixed(0));
    _vatAmountC =
        TextEditingController(text: initialAmount.vatAmount.toStringAsFixed(0));
    _totalAmountC = TextEditingController(
        text: initialAmount.totalAmount.toStringAsFixed(0));
    _memoC = TextEditingController(text: line?.memo ?? '');
    _loadQuoteVatType();
    if (line == null) _recalculateAmounts(force: true);
  }

  @override
  void dispose() {
    _itemIdC.dispose();
    _nameC.dispose();
    _unitC.dispose();
    _qtyC.dispose();
    _priceC.dispose();
    _supplyAmountC.dispose();
    _vatAmountC.dispose();
    _totalAmountC.dispose();
    _memoC.dispose();
    super.dispose();
  }

  Future<void> _loadQuoteVatType() async {
    if (widget.initial != null || _vatTypeTouched) return;
    final quote = await context.read<QuoteRepo>().getQuoteById(widget.quoteId);
    if (!mounted || quote == null) return;
    setState(() {
      _vatType = switch (quote.vatType) {
        QuoteVatType.exclusive => VatType.exclusive,
        QuoteVatType.inclusive => VatType.inclusive,
        QuoteVatType.exempt => VatType.exempt,
      };
      _recalculateAmounts(force: true);
    });
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

  List<TextInputFormatter> get _numberInputFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ];

  double _parseMoney(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;

  void _recalculateAmountsIfNeeded() {
    if (!_amountEdited) _recalculateAmounts();
  }

  void _recalculateAmounts({bool force = false}) {
    if (_amountEdited && !force) return;
    final qty = double.tryParse(_qtyC.text.trim()) ?? 0;
    final price = double.tryParse(_priceC.text.trim()) ?? 0;
    final amount = LineAmountCalculator.calculate(
      unitPrice: price,
      qty: qty,
      vatType: _vatType,
    );
    _supplyAmountC.text = amount.supplyAmount.toStringAsFixed(0);
    _vatAmountC.text = amount.vatAmount.toStringAsFixed(0);
    _totalAmountC.text = amount.totalAmount.toStringAsFixed(0);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final qty = double.tryParse(_qtyC.text.trim()) ?? 0;
    final price = double.tryParse(_priceC.text.trim()) ?? 0;
    final amount = _amountEdited
        ? LineAmountBreakdown(
            supplyAmount: _parseMoney(_supplyAmountC),
            vatAmount: _parseMoney(_vatAmountC),
            totalAmount: _parseMoney(_totalAmountC),
          )
        : LineAmountCalculator.calculate(
            unitPrice: price,
            qty: qty,
            vatType: _vatType,
          );
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
        vatType: _vatType,
        supplyAmount: amount.supplyAmount,
        vatAmount: amount.vatAmount,
        totalAmount: amount.totalAmount,
        amountEdited: _amountEdited,
        memo: _memoC.text.trim().isEmpty ? null : _memoC.text.trim(),
      ),
    );
  }

  Widget _buildVatTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('단가 부가세 기준', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<VatType>(
          segments: const [
            ButtonSegment(value: VatType.exclusive, label: Text('별도')),
            ButtonSegment(value: VatType.inclusive, label: Text('포함')),
            ButtonSegment(value: VatType.exempt, label: Text('면세')),
          ],
          selected: {_vatType},
          onSelectionChanged: (values) {
            setState(() {
              _vatType = values.first;
              _vatTypeTouched = true;
              _recalculateAmountsIfNeeded();
            });
          },
        ),
      ],
    );
  }

  Widget _buildAmountEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('금액 직접 수정'),
          subtitle: const Text('1원 단위 조정이 필요할 때 켜세요.'),
          value: _amountEdited,
          onChanged: (value) {
            setState(() {
              _amountEdited = value;
              if (!value) _recalculateAmounts(force: true);
            });
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _supplyAmountC,
                enabled: _amountEdited,
                decoration: const InputDecoration(labelText: '공급가액'),
                keyboardType: TextInputType.text,
                inputFormatters: _numberInputFormatters,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _vatAmountC,
                enabled: _amountEdited,
                decoration: const InputDecoration(labelText: '부가세'),
                keyboardType: TextInputType.text,
                inputFormatters: _numberInputFormatters,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _totalAmountC,
                enabled: _amountEdited,
                decoration: const InputDecoration(labelText: '합계'),
                keyboardType: TextInputType.text,
                inputFormatters: _numberInputFormatters,
              ),
            ),
          ],
        ),
      ],
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
              keyboardType: TextInputType.text,
              inputFormatters: _numberInputFormatters,
              onChanged: (_) => _recalculateAmountsIfNeeded(),
              decoration: const InputDecoration(labelText: '수량'),
              validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0
                  ? '수량을 입력하세요'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceC,
              keyboardType: TextInputType.text,
              inputFormatters: _numberInputFormatters,
              onChanged: (_) => _recalculateAmountsIfNeeded(),
              decoration: const InputDecoration(labelText: '단가'),
            ),
            const SizedBox(height: 12),
            _buildVatTypeSelector(),
            const SizedBox(height: 12),
            _buildAmountEditor(),
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
