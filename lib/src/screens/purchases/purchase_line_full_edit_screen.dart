import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../models/purchase_line.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/item_picker_sheet.dart';
import '../../ui/common/suggestion_panel.dart';
import '../../ui/common/ui.dart';


class PurchaseLineFullEditScreen extends StatefulWidget {
  final PurchaseOrderRepo repo;
  final String orderId;
  final PurchaseLine? initial;

  const PurchaseLineFullEditScreen({
    super.key,
    required this.repo,
    required this.orderId,
    this.initial,
  });

  @override
  State<PurchaseLineFullEditScreen> createState() => _PurchaseLineFullEditScreenState();
}

class _PurchaseLineFullEditScreenState extends State<PurchaseLineFullEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  late final TextEditingController itemIdC;
  late final TextEditingController nameC;
  late final TextEditingController unitC;
  late final TextEditingController qtyC;
  late final TextEditingController colorNoC;
  late final TextEditingController noteC;
  late final TextEditingController memoC;
  late final TextEditingController priceC;

  late final bool isEdit;
  late final String lineId;
  Timer? _itemSearchDebounce;
  bool _itemSearching = false;
  bool _suppressItemSearch = false;
  List<Item> _itemResults = <Item>[];

  @override
  void initState() {
    super.initState();
    isEdit = widget.initial != null;
    lineId = widget.initial?.id ?? const Uuid().v4();

    final i = widget.initial;
    itemIdC  = TextEditingController(text: i?.itemId ?? '');
    nameC    = TextEditingController(text: i?.name ?? '');
    unitC    = TextEditingController(text: i?.unit ?? 'EA');
    qtyC     = TextEditingController(text: (i?.qty ?? 1).toString());
    colorNoC = TextEditingController(text: i?.colorNo ?? '');
    noteC    = TextEditingController(text: i?.note ?? '');
    memoC    = TextEditingController(text: i?.memo ?? '');
    priceC = TextEditingController(
      text: (i?.unitPrice ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _itemSearchDebounce?.cancel();
    itemIdC.dispose();
    nameC.dispose();
    unitC.dispose();
    qtyC.dispose();
    colorNoC.dispose();
    noteC.dispose();
    memoC.dispose();
    priceC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final qty = double.tryParse(qtyC.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수량은 0보다 큰 숫자여야 합니다')));
      return;
    }
    double price = double.tryParse(priceC.text.trim()) ?? 0;

    if (price == 0) {
      final itemRepo = context.read<ItemRepo>();
      final item = await itemRepo.getItem(itemIdC.text.trim());
      price = item?.defaultPrice ?? 0;
    }
    final newLine = PurchaseLine(
      id: lineId,
      orderId: widget.orderId,
      itemId: itemIdC.text.trim(),
      name: nameC.text.trim(),
      unit: (unitC.text.trim().isEmpty) ? 'EA' : unitC.text.trim(),
      qty: qty,
      colorNo: colorNoC.text.trim().isEmpty ? null : colorNoC.text.trim(),
      note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
      memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),
      unitPrice: price,
    );

    final lines = await widget.repo.getLines(widget.orderId);
    final idx = lines.indexWhere((e) => e.id == newLine.id);
    if (idx >= 0) {
      lines[idx] = newLine;
    } else {
      lines.add(newLine);
    }
    await widget.repo.upsertLines(widget.orderId, lines);
    if (!mounted) return;
    Navigator.pop(context, newLine);
  }

  Future<void> _pickItem() async {
    final currentItemId = itemIdC.text.trim();
    final pickedId = await showItemPickerSheet(
      context,
      initialItemId: currentItemId.isEmpty ? null : currentItemId,
      title: '발주 품목 검색',
    );
    if (pickedId == null || pickedId.isEmpty) return;

    final itemRepo = context.read<ItemRepo>();
    final item = await itemRepo.getItem(pickedId);

    if (!mounted) return;

    if (item != null) {
      _applyItem(item);
    } else {
      setState(() => itemIdC.text = pickedId);
    }
  }

  void _applyItem(Item item) {
    _suppressItemSearch = true;
    setState(() {
      itemIdC.text = item.id;
      nameC.text = item.displayName ?? item.name;
      unitC.text = item.unitIn.isNotEmpty ? item.unitIn : item.unit;
      _itemResults = [];
      _itemSearching = false;

      final purchasePrice = item.defaultPurchasePrice ?? item.defaultPrice;
      if (purchasePrice != null && purchasePrice > 0) {
        priceC.text = purchasePrice.toString();
      }
    });
    _suppressItemSearch = false;
  }

  void _onItemNameChanged(String value) {
    if (_suppressItemSearch) return;

    itemIdC.clear();
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
      if (!mounted || nameC.text.trim() != query) return;
      setState(() {
        _itemResults = results;
        _itemSearching = false;
      });
    });
  }

  Future<void> _createTemporaryItemFromLine() async {
    final itemName = nameC.text.trim();
    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이템명을 입력하세요')),
      );
      return;
    }

    final itemRepo = context.read<ItemRepo>();
    final po = await widget.repo.getPurchaseOrderById(widget.orderId);
    final unit = unitC.text.trim().isEmpty ? 'EA' : unitC.text.trim();
    final price = double.tryParse(priceC.text.trim());
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
      supplierName: po?.supplierName.trim().isNotEmpty == true
          ? po!.supplierName.trim()
          : null,
      defaultPurchasePrice: price != null && price > 0 ? price : null,
      attrs: {
        'temporary': true,
        'status': 'needsReview',
        'source': 'purchaseLine',
        'createdFromPurchaseOrderId': widget.orderId,
        'createdAt': now,
        if (po?.supplierId != null && po!.supplierId!.isNotEmpty)
          'supplierId': po.supplierId,
      },
    );

    await itemRepo.upsertItem(item);
    if (!mounted) return;
    _applyItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('정식등록 필요 아이템으로 추가했어요')),
    );
  }

  Future<void> _delete() async {
    if (!isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.t.common_delete),
        content: Text('${nameC.text.trim().isNotEmpty ? nameC.text.trim() : itemIdC.text.trim()} 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t.common_cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.t.common_delete)),
        ],
      ),
    );
    if (ok != true) return;

    final lines = await widget.repo.getLines(widget.orderId);
    final next = lines.where((e) => e.id != lineId).toList();
    await widget.repo.upsertLines(widget.orderId, next);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  Widget _buildInlineItemResults() {
    final query = nameC.text.trim();
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

    if (query.isEmpty || itemIdC.text.trim().isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '발주 라인 편집' : '발주 라인 추가'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: '저장',
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('필수', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameC,
                decoration: _dec('아이템명', hint: '입력하면 기존 아이템을 검색합니다').copyWith(
                  suffixIcon: IconButton(
                    tooltip: '아이템 검색',
                    icon: const Icon(Icons.search),
                    onPressed: _pickItem,
                  ),
                ),
                onChanged: _onItemNameChanged,
                validator: (_) => itemIdC.text.trim().isEmpty
                    ? '기존 아이템을 선택하거나 새 아이템으로 추가하세요'
                    : null,
              ),
              _buildInlineItemResults(),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: unitC,
                      decoration: _dec('unit', hint: 'EA/M/ROLL...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: qtyC,
                      decoration: _dec('qty'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '수량';
                        final d = double.tryParse(v);
                        if (d == null || d <= 0) return '0보다 큰 숫자';
                        return null;
                      },
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: priceC,
                      decoration: _dec('단가'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text('옵션', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(controller: colorNoC, decoration: _dec('colorNo (선택)')),
              TextFormField(controller: noteC, decoration: _dec('note (선택)')),
              TextFormField(
                controller: memoC,
                decoration: _dec('memo (선택)'),
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(context.t.btn_save),
              ),
              const SizedBox(height: 8),
              if (isEdit)
                OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete),
                  label: Text(context.t.common_delete),
                ),
              const SizedBox(height: 16),
              Text('Line ID: $lineId', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
