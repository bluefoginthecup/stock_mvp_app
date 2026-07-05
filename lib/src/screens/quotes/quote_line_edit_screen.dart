import 'dart:async';

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
import '../../ui/common/suggestion_panel.dart';
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
  TextEditingController? _specC;
  TextEditingController get _specController =>
      _specC ??= TextEditingController();
  late final TextEditingController _qtyC;
  late final TextEditingController _priceC;
  late final TextEditingController _supplyAmountC;
  late final TextEditingController _vatAmountC;
  late final TextEditingController _totalAmountC;
  late final TextEditingController _memoC;
  late final String _lineId;
  Timer? _itemSearchDebounce;
  bool _itemSearching = false;
  bool _suppressItemSearch = false;
  List<Item> _itemResults = <Item>[];
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
    _itemSearchDebounce?.cancel();
    _itemIdC.dispose();
    _nameC.dispose();
    _unitC.dispose();
    _specC?.dispose();
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
    _suppressItemSearch = true;
    setState(() {
      _itemIdC.text = item.id;
      _nameC.text = item.displayName ?? item.name;
      _unitC.text = item.unitOut.isNotEmpty ? item.unitOut : item.unit;
      _itemResults = [];
      _itemSearching = false;
      final spec = item.attrs?['nominalSize']?.toString().trim();
      if (spec != null && spec.isNotEmpty) {
        _specController.text = spec;
      }
      final price = item.defaultSalePrice ?? item.defaultPrice;
      if (price != null && price > 0) {
        _priceC.text = price.toString();
      }
    });
    _suppressItemSearch = false;
    _recalculateAmountsIfNeeded();
  }

  void _onItemNameChanged(String value) {
    if (_suppressItemSearch) return;

    _itemIdC.clear();
    _itemSearchDebounce?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _itemResults = [];
        _itemSearching = false;
      });
      return;
    }

    setState(() => _itemSearching = true);
    _itemSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      final itemRepo = context.read<ItemRepo>();
      final results = await itemRepo.searchItemsGlobal(query);
      if (!mounted || _nameC.text.trim() != query) return;
      setState(() {
        _itemResults = results;
        _itemSearching = false;
      });
    });
  }

  Future<Item?> _createTemporaryItemFromLine() async {
    final itemName = _nameC.text.trim();
    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이템명을 입력하세요')),
      );
      return null;
    }

    final itemRepo = context.read<ItemRepo>();
    final unit = _unitC.text.trim().isEmpty ? 'EA' : _unitC.text.trim();
    final spec = _specController.text.trim();
    final memo = _memoC.text.trim();
    final price = double.tryParse(_priceC.text.trim());
    final now = DateTime.now().toIso8601String();

    final item = Item(
      id: const Uuid().v4(),
      name: itemName,
      displayName: null,
      sku: '',
      unit: unit,
      folder: 'uncategorized',
      subfolder: null,
      subsubfolder: null,
      minQty: 0,
      qty: 0,
      defaultSalePrice: price != null && price > 0 ? price : null,
      attrs: {
        'temporary': true,
        'status': 'needsReview',
        'source': 'quoteLine',
        'createdFromQuoteId': widget.quoteId,
        'createdAt': now,
        if (spec.isNotEmpty) 'nominalSize': spec,
        if (memo.isNotEmpty) 'quoteMemo': memo,
      },
    );

    final uncategorizedRootId = await _findUncategorizedRootId();
    final dyn = itemRepo as dynamic;
    if (uncategorizedRootId != null && dyn.upsertItemWithPath is Function) {
      await dyn.upsertItemWithPath(item, uncategorizedRootId, null, null);
    } else {
      await itemRepo.upsertItem(item);
    }
    if (!mounted) return null;
    _applyItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('정식등록 필요 아이템으로 추가했어요')),
    );
    return item;
  }

  Future<String?> _findUncategorizedRootId() async {
    final folderRepo = context.read<FolderTreeRepo>();
    final roots = await folderRepo.listFolderChildren(null);
    for (final root in roots) {
      final id = root.id.trim().toLowerCase();
      final name = root.name.trim().toLowerCase();
      if (id == 'uncategorized' || name == 'uncategorized') {
        return root.id;
      }
    }
    return null;
  }

  Widget _buildInlineItemResults() {
    final query = _nameC.text.trim();
    if (_itemSearching) return const LinearProgressIndicator();

    if (_itemResults.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SuggestionPanel<Item>(
          items: _itemResults,
          rowHeight: 56,
          maxRows: 5,
          itemBuilder: (_, item) => ListTile(
            title: Text(item.displayName ?? item.name),
            subtitle: item.sku.isNotEmpty ? Text(item.sku) : null,
            onTap: () => _applyItem(item),
          ),
        ),
      );
    }

    if (query.isEmpty || _itemIdC.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('새 아이템으로 추가할까요?'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _createTemporaryItemFromLine,
                icon: const Icon(Icons.add),
                label: const Text('+ 새 아이템 추가'),
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    var createdTemporaryItem = false;
    if (_itemIdC.text.trim().isEmpty) {
      final created = await _createTemporaryItemFromLine();
      createdTemporaryItem = created != null;
      if (!mounted || _itemIdC.text.trim().isEmpty) return;
    }
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
    if (!createdTemporaryItem) {
      await _maybeSaveLineDefaultsToItem();
      if (!mounted) return;
    }
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

  Future<void> _maybeSaveLineDefaultsToItem() async {
    final itemId = _itemIdC.text.trim();
    if (itemId.isEmpty) return;

    final itemRepo = context.read<ItemRepo>();
    final item = await itemRepo.getItem(itemId);
    if (!mounted || item == null) return;

    final attrs = Map<String, dynamic>.from(item.attrs ?? const {});
    final spec = _specController.text.trim();
    final currentSpec = attrs['nominalSize']?.toString().trim() ?? '';
    final canSaveSpec = spec.isNotEmpty && currentSpec.isEmpty;
    if (!canSaveSpec) return;

    final lines = <String>[
      if (canSaveSpec) '규격: $spec',
    ];
    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('이 정보를 아이템 기본값으로 저장할까요?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('빈 값만 저장합니다.\n기존 값은 덮어쓰지 않습니다.'),
                const SizedBox(height: 12),
                ...lines.map((line) => Text('- $line')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('저장 안함'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('빈 값이면 저장'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !shouldSave) return;

    if (canSaveSpec) attrs['nominalSize'] = spec;
    await itemRepo.upsertItem(
      item.copyWith(
        attrs: attrs,
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
                hintText: '입력하면 기존 아이템을 검색합니다',
                suffixIcon: IconButton(
                  tooltip: '품목 검색',
                  icon: const Icon(Icons.search),
                  onPressed: _pickItem,
                ),
              ),
              onChanged: _onItemNameChanged,
              validator: (v) => (v ?? '').trim().isEmpty ? '품목명을 입력하세요' : null,
            ),
            _buildInlineItemResults(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitC,
              decoration: const InputDecoration(labelText: '단위'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specController,
              decoration: const InputDecoration(labelText: '규격'),
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
