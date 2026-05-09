import 'dart:async';

import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import '../../models/item.dart';
import '../../models/purchase_line.dart';
import '../../models/purchase_order.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/item_picker_sheet.dart';
import '../../ui/common/suggestion_panel.dart';
import '../../ui/common/ui.dart';
import '../../utils/line_amount_calculator.dart';

const _knownPrintAttrLabels = {
  'design': '디자인',
  'color_name': '색상명',
  'color_no': '색상번호',
  'form': '형태',
  'nominalSize': '규격',
  'cutSize': '재단 사이즈',
  'memo': '메모',
};

const _systemPrintAttrKeys = {
  'temporary',
  'status',
  'source',
  'createdFromPurchaseOrderId',
  'createdAt',
};

class _PrintAttrEditorRow {
  final TextEditingController keyC;
  final TextEditingController labelC;
  final TextEditingController valueC;
  bool selected;
  bool removable;

  _PrintAttrEditorRow({
    required String key,
    required String label,
    required String value,
    this.selected = false,
    this.removable = false,
  })  : keyC = TextEditingController(text: key),
        labelC = TextEditingController(text: label),
        valueC = TextEditingController(text: value);

  void dispose() {
    keyC.dispose();
    labelC.dispose();
    valueC.dispose();
  }
}

class _PrintAttrCandidate {
  final String key;
  final String label;
  final String value;

  const _PrintAttrCandidate({
    required this.key,
    required this.label,
    required this.value,
  });
}

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
  State<PurchaseLineFullEditScreen> createState() =>
      _PurchaseLineFullEditScreenState();
}

class _PurchaseLineFullEditScreenState
    extends State<PurchaseLineFullEditScreen> {
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
  late final TextEditingController supplyAmountC;
  late final TextEditingController vatAmountC;
  late final TextEditingController totalAmountC;
  final List<_PrintAttrEditorRow> _printAttrRows = [];

  late final bool isEdit;
  late final String lineId;
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
    isEdit = widget.initial != null;
    lineId = widget.initial?.id ?? const Uuid().v4();

    final i = widget.initial;
    itemIdC = TextEditingController(text: i?.itemId ?? '');
    nameC = TextEditingController(text: i?.name ?? '');
    unitC = TextEditingController(text: i?.unit ?? 'EA');
    qtyC = TextEditingController(text: (i?.qty ?? 1).toString());
    colorNoC = TextEditingController(text: i?.colorNo ?? '');
    noteC = TextEditingController(text: i?.note ?? '');
    memoC = TextEditingController(text: i?.memo ?? '');
    priceC = TextEditingController(
      text: (i?.unitPrice ?? 0).toString(),
    );
    _vatType = i?.vatType ?? VatType.exclusive;
    _amountEdited = i?.amountEdited ?? false;
    final initialAmount = i == null
        ? const LineAmountBreakdown(
            supplyAmount: 0,
            vatAmount: 0,
            totalAmount: 0,
          )
        : LineAmountBreakdown(
            supplyAmount: i.supplyAmount,
            vatAmount: i.vatAmount,
            totalAmount: i.totalAmount,
          );
    supplyAmountC = TextEditingController(
        text: initialAmount.supplyAmount.toStringAsFixed(0));
    vatAmountC =
        TextEditingController(text: initialAmount.vatAmount.toStringAsFixed(0));
    totalAmountC = TextEditingController(
        text: initialAmount.totalAmount.toStringAsFixed(0));
    _resetPrintAttrRows(i?.printAttrs ?? const []);
    final initialItemId = i?.itemId.trim();
    if (initialItemId != null && initialItemId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPrintAttrCandidates(initialItemId);
      });
    }
    _loadPurchaseOrderVatType();
    if (i == null) {
      _recalculateAmounts(force: true);
    }
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
    supplyAmountC.dispose();
    vatAmountC.dispose();
    totalAmountC.dispose();
    for (final row in _printAttrRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _resetPrintAttrRows(List<PurchaseLinePrintAttr> attrs) {
    for (final row in _printAttrRows) {
      row.dispose();
    }
    _printAttrRows.clear();
    for (final attr in attrs) {
      _printAttrRows.add(
        _PrintAttrEditorRow(
          key: attr.key,
          label: attr.label,
          value: attr.value,
          selected: true,
          removable: true,
        ),
      );
    }
  }

  Future<void> _loadPrintAttrCandidates(String itemId) async {
    final item = await context.read<ItemRepo>().getItem(itemId);
    if (!mounted) return;
    _mergePrintAttrCandidates(item);
  }

  void _mergePrintAttrCandidates(Item? item) {
    final existing = {
      for (final row in _printAttrRows) row.keyC.text.trim(): row,
    };
    final candidateKeys = <String>{};
    final candidates = <_PrintAttrCandidate>[];

    final attrs = item?.attrs ?? const <String, dynamic>{};
    final keys = attrs.keys
        .where((key) => !_systemPrintAttrKeys.contains(key))
        .toList()
      ..sort();
    for (final key in keys) {
      final value = attrs[key]?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      candidates.add(
        _PrintAttrCandidate(
          key: key,
          label: _knownPrintAttrLabels[key] ?? key,
          value: value,
        ),
      );
      candidateKeys.add(key);
    }

    final memo = memoC.text.trim();
    if (memo.isNotEmpty) {
      candidates.add(
        _PrintAttrCandidate(
          key: 'memo',
          label: _knownPrintAttrLabels['memo']!,
          value: memo,
        ),
      );
      candidateKeys.add('memo');
    }

    final nextRows = <_PrintAttrEditorRow>[];
    for (final candidate in candidates) {
      final row = existing.remove(candidate.key);
      if (row == null) {
        nextRows.add(
          _PrintAttrEditorRow(
            key: candidate.key,
            label: candidate.label,
            value: candidate.value,
          ),
        );
      } else {
        if (!row.selected || candidate.key == 'memo') {
          row.labelC.text = candidate.label;
          row.valueC.text = candidate.value;
        }
        row.removable = false;
        nextRows.add(row);
      }
    }

    for (final row in existing.values) {
      if (row.selected || row.removable) {
        row.removable = !candidateKeys.contains(row.keyC.text.trim());
        nextRows.add(row);
      } else {
        row.dispose();
      }
    }

    setState(() {
      _printAttrRows
        ..clear()
        ..addAll(nextRows);
    });
  }

  List<PurchaseLinePrintAttr> _buildPrintAttrs() {
    return _printAttrRows
        .where((row) => row.selected)
        .map(
          (row) => PurchaseLinePrintAttr(
            key: row.keyC.text.trim(),
            label: row.labelC.text.trim(),
            value: row.valueC.text.trim(),
          ),
        )
        .where((attr) => attr.label.isNotEmpty && attr.value.isNotEmpty)
        .toList(growable: false);
  }

  void _addCustomPrintAttr() {
    setState(() {
      _printAttrRows.add(
        _PrintAttrEditorRow(
          key: 'custom_${DateTime.now().microsecondsSinceEpoch}',
          label: '',
          value: '',
          selected: true,
          removable: true,
        ),
      );
    });
  }

  void _removePrintAttrRow(_PrintAttrEditorRow row) {
    setState(() {
      _printAttrRows.remove(row);
      row.dispose();
    });
  }

  Future<void> _loadPurchaseOrderVatType() async {
    final po = await widget.repo.getPurchaseOrderById(widget.orderId);
    if (!mounted || po == null) return;
    if (isEdit || _vatTypeTouched) {
      return;
    }
    setState(() {
      _vatType = po.vatType;
      _recalculateAmounts(force: true);
    });
  }

  double _parseMoney(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;

  void _recalculateAmountsIfNeeded() {
    if (!_amountEdited) {
      _recalculateAmounts();
    }
  }

  List<TextInputFormatter> get _numberInputFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ];

  void _recalculateAmounts({bool force = false}) {
    if (_amountEdited && !force) return;
    final qty = double.tryParse(qtyC.text.trim()) ?? 0;
    final price = double.tryParse(priceC.text.trim()) ?? 0;
    final amount = LineAmountCalculator.calculate(
      unitPrice: price,
      qty: qty,
      vatType: _vatType,
    );
    supplyAmountC.text = amount.supplyAmount.toStringAsFixed(0);
    vatAmountC.text = amount.vatAmount.toStringAsFixed(0);
    totalAmountC.text = amount.totalAmount.toStringAsFixed(0);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final qty = double.tryParse(qtyC.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('수량은 0보다 큰 숫자여야 합니다')));
      return;
    }
    double price = double.tryParse(priceC.text.trim()) ?? 0;

    if (price == 0) {
      final itemRepo = context.read<ItemRepo>();
      final item = await itemRepo.getItem(itemIdC.text.trim());
      price = item?.defaultPrice ?? 0;
    }
    final amount = _amountEdited
        ? LineAmountBreakdown(
            supplyAmount: _parseMoney(supplyAmountC),
            vatAmount: _parseMoney(vatAmountC),
            totalAmount: _parseMoney(totalAmountC),
          )
        : LineAmountCalculator.calculate(
            unitPrice: price,
            qty: qty,
            vatType: _vatType,
          );
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
      vatType: _vatType,
      supplyAmount: amount.supplyAmount,
      vatAmount: amount.vatAmount,
      totalAmount: amount.totalAmount,
      amountEdited: _amountEdited,
      printAttrs: _buildPrintAttrs(),
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
    final itemRepo = context.read<ItemRepo>();
    final pickedId = await showItemPickerSheet(
      context,
      initialItemId: currentItemId.isEmpty ? null : currentItemId,
      title: '발주 품목 검색',
    );
    if (pickedId == null || pickedId.isEmpty) return;

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
    _mergePrintAttrCandidates(item);
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

    final uncategorizedRootId = await _findUncategorizedRootId();
    final dyn = itemRepo as dynamic;
    if (uncategorizedRootId != null && dyn.upsertItemWithPath is Function) {
      await dyn.upsertItemWithPath(item, uncategorizedRootId, null, null);
    } else {
      await itemRepo.upsertItem(item);
    }
    if (!mounted) return;
    _applyItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('정식등록 필요 아이템으로 추가했어요')),
    );
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

  Future<void> _delete() async {
    if (!isEdit) return;
    final deleteLabel = context.t.common_delete;
    final cancelLabel = context.t.common_cancel;
    final targetName =
        nameC.text.trim().isNotEmpty ? nameC.text.trim() : itemIdC.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deleteLabel),
        content: Text('$targetName 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(deleteLabel)),
        ],
      ),
    );
    if (ok != true) return;

    debugPrint(
      '🧾 purchase line delete tapped orderId=${widget.orderId} lineId=$lineId isEdit=$isEdit',
    );
    final deleted =
        await widget.repo.deletePurchaseLine(widget.orderId, lineId);
    debugPrint('🧾 purchase line delete result deleted=$deleted');
    if (deleted == 0) {
      final lines = await widget.repo.getLines(widget.orderId);
      debugPrint(
        '🧾 purchase line delete screen fallback lines=${lines.length} ids=${lines.map((line) => line.id).join(',')}',
      );
      final next = lines.where((line) => line.id != lineId).toList();
      if (next.length != lines.length) {
        await widget.repo.upsertLines(widget.orderId, next);
      }
    }
    if (!mounted) return;
    Navigator.pop(context, deleted > 0);
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

  Widget _buildPrintAttrsEditor() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('발주서 표시 정보', style: theme.textTheme.titleSmall),
            ),
            TextButton.icon(
              onPressed: _addCustomPrintAttr,
              icon: const Icon(Icons.add),
              label: const Text('직접 추가'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '선택한 항목만 모바일/A4 발주서에 표시됩니다. '
          '품목 속성과 메모를 후보로 보여주며, 필요한 거래처 전달 정보만 골라주세요.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
        const SizedBox(height: 8),
        if (_printAttrRows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('선택 가능한 표시 정보가 없습니다. 직접 추가할 수 있습니다.'),
          )
        else
          ..._printAttrRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPrintAttrRow(row),
            ),
          ),
      ],
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
            ButtonSegment(
              value: VatType.exclusive,
              label: Text('별도'),
            ),
            ButtonSegment(
              value: VatType.inclusive,
              label: Text('포함'),
            ),
            ButtonSegment(
              value: VatType.exempt,
              label: Text('면세'),
            ),
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
        const SizedBox(height: 4),
        Text(
          '이 라인의 공급가액/부가세/합계 계산에 적용됩니다.',
          style: Theme.of(context).textTheme.bodySmall,
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
              if (!value) {
                _recalculateAmounts(force: true);
              }
            });
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: supplyAmountC,
                enabled: _amountEdited,
                decoration: _dec('공급가액'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: vatAmountC,
                enabled: _amountEdited,
                decoration: _dec('부가세'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: totalAmountC,
                enabled: _amountEdited,
                decoration: _dec('합계'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrintAttrRow(_PrintAttrEditorRow row) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: row.selected,
          onChanged: (value) {
            setState(() => row.selected = value ?? false);
          },
        ),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: row.labelC,
            enabled: row.selected,
            decoration: const InputDecoration(
              labelText: '표시명',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (value) {
              if (!row.selected) return null;
              if (value == null || value.trim().isEmpty) return '표시명 필요';
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: TextFormField(
            controller: row.valueC,
            enabled: row.selected,
            decoration: InputDecoration(
              labelText: row.keyC.text.trim().isEmpty
                  ? '값'
                  : '값 (${row.keyC.text.trim()})',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            validator: (value) {
              if (!row.selected) return null;
              if (value == null || value.trim().isEmpty) return '값 필요';
              return null;
            },
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: row.removable ? '표시 항목 삭제' : '후보 항목은 삭제하지 않고 선택만 해제합니다',
          onPressed: row.removable ? () => _removePrintAttrRow(row) : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
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
                      keyboardType: TextInputType.text,
                      inputFormatters: _numberInputFormatters,
                      onChanged: (_) => _recalculateAmountsIfNeeded(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '수량';
                        final d = double.tryParse(v);
                        if (d == null || d <= 0) return '0보다 큰 숫자';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: priceC,
                      decoration: _dec('단가'),
                      keyboardType: TextInputType.text,
                      inputFormatters: _numberInputFormatters,
                      onChanged: (_) => _recalculateAmountsIfNeeded(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildVatTypeSelector(),
              const SizedBox(height: 12),
              _buildAmountEditor(),
              const SizedBox(height: 16),
              Text('옵션', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                  controller: colorNoC, decoration: _dec('colorNo (선택)')),
              TextFormField(controller: noteC, decoration: _dec('note (선택)')),
              TextFormField(
                controller: memoC,
                decoration: _dec('memo (선택)'),
                maxLines: 3,
                onChanged: (_) {
                  _loadPrintAttrCandidates(itemIdC.text.trim());
                },
              ),
              const SizedBox(height: 16),
              _buildPrintAttrsEditor(),
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
