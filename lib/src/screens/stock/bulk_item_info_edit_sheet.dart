import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/path_picker.dart';
import '../../ui/common/supplier_picker_sheet.dart';

Future<bool?> showBulkItemInfoEditSheet(
  BuildContext context, {
  required List<String> itemIds,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BulkItemInfoEditSheet(itemIds: itemIds),
  );
}

class _BulkItemInfoEditSheet extends StatefulWidget {
  final List<String> itemIds;

  const _BulkItemInfoEditSheet({required this.itemIds});

  @override
  State<_BulkItemInfoEditSheet> createState() => _BulkItemInfoEditSheetState();
}

class _BulkItemInfoEditSheetState extends State<_BulkItemInfoEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameFindC = TextEditingController();
  final _nameReplaceC = TextEditingController();
  final _minQtyC = TextEditingController();
  final _purchasePriceC = TextEditingController();
  final _salePriceC = TextEditingController();
  final _unitC = TextEditingController();
  final _unitInC = TextEditingController();
  final _unitOutC = TextEditingController();
  final _conversionRateC = TextEditingController();
  final _attrRows = <_BulkAttrRow>[];

  bool _nameEnabled = false;
  bool _pathEnabled = false;
  bool _supplierEnabled = false;
  bool _minQtyEnabled = false;
  bool _purchasePriceEnabled = false;
  bool _salePriceEnabled = false;
  bool _attrsEnabled = false;
  bool _unitEnabled = false;
  bool _conversionEnabled = false;
  String _conversionMode = 'fixed';

  List<String>? _pathIds;
  String? _pathLabel;
  Supplier? _supplier;
  List<Item> _items = const [];
  bool _itemsLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _attrRows.add(_BulkAttrRow());
    _loadItems();
  }

  @override
  void dispose() {
    _nameFindC.dispose();
    _nameReplaceC.dispose();
    _minQtyC.dispose();
    _purchasePriceC.dispose();
    _salePriceC.dispose();
    _unitC.dispose();
    _unitInC.dispose();
    _unitOutC.dispose();
    _conversionRateC.dispose();
    for (final row in _attrRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    final repo = context.read<ItemRepo>();
    final items = <Item>[];
    for (final itemId in widget.itemIds) {
      final item = await repo.getItem(itemId);
      if (item != null) items.add(item);
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _itemsLoading = false;
    });
  }

  ChildrenProvider _childrenProvider(FolderTreeRepo repo) {
    return (parentId) async {
      final folders = await repo.listFolderChildren(parentId);
      return folders.map((folder) => PathNode(folder.id, folder.name)).toList();
    };
  }

  Future<String> _pathNameFor(List<String> pathIds) async {
    final repo = context.read<FolderTreeRepo>();
    final names = <String>[];
    for (final id in pathIds) {
      final folder = await repo.folderById(id);
      if (folder != null) names.add(folder.name);
    }
    return names.isEmpty ? '선택된 경로 없음' : names.join(' > ');
  }

  Future<void> _pickPath() async {
    final repo = context.read<FolderTreeRepo>();
    final path = await showPathPicker(
      context,
      childrenProvider: _childrenProvider(repo),
      title: '일괄 이동할 경로 선택',
      maxDepth: 3,
    );
    if (path == null || path.isEmpty) return;
    final label = await _pathNameFor(path);
    if (!mounted) return;
    setState(() {
      _pathIds = path;
      _pathLabel = label;
      _pathEnabled = true;
    });
  }

  Future<void> _pickSupplier() async {
    final supplier = await showSupplierPickerSheet(
      context,
      title: '일괄 지정할 거래처 선택',
    );
    if (supplier == null) return;
    setState(() {
      _supplier = supplier;
      _supplierEnabled = true;
    });
  }

  void _addAttrRow() {
    setState(() => _attrRows.add(_BulkAttrRow()));
  }

  void _removeAttrRow(_BulkAttrRow row) {
    if (_attrRows.length == 1) {
      row.keyC.clear();
      row.valueC.clear();
      return;
    }
    setState(() {
      _attrRows.remove(row);
      row.dispose();
    });
  }

  Map<String, dynamic> _attrPatch() {
    final patch = <String, dynamic>{};
    if (!_attrsEnabled) return patch;
    for (final row in _attrRows) {
      final key = row.keyC.text.trim();
      if (key.isEmpty) continue;
      patch[key] = row.valueC.text.trim();
    }
    return patch;
  }

  List<String> _summaryLines() {
    final lines = <String>[];
    if (_nameEnabled) {
      lines.add(
        '이름 치환: "${_nameFindC.text.trim()}" → "${_nameReplaceC.text.trim()}"',
      );
    }
    if (_pathEnabled && _pathLabel != null) lines.add('경로: $_pathLabel');
    if (_supplierEnabled && _supplier != null) {
      lines.add('거래처: ${_supplier!.name}');
    }
    if (_minQtyEnabled) lines.add('최소재고: ${_minQtyC.text.trim()}');
    if (_purchasePriceEnabled) {
      lines.add('입고가: ${_purchasePriceC.text.trim()}');
    }
    if (_salePriceEnabled) lines.add('출고가: ${_salePriceC.text.trim()}');
    final attrs = _attrPatch();
    if (attrs.isNotEmpty) {
      lines.add(
          '속성: ${attrs.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    }
    if (_unitEnabled && _unitC.text.trim().isNotEmpty) {
      lines.add('기본 단위: ${_unitC.text.trim()}');
    }
    if (_conversionEnabled) {
      if (_unitInC.text.trim().isNotEmpty) {
        lines.add('입고 단위: ${_unitInC.text.trim()}');
      }
      if (_unitOutC.text.trim().isNotEmpty) {
        lines.add('출고 단위: ${_unitOutC.text.trim()}');
      }
      if (_conversionRateC.text.trim().isNotEmpty) {
        lines.add('환산율: ${_conversionRateC.text.trim()}');
      }
      lines.add('환산 방식: $_conversionMode');
    }
    return lines;
  }

  bool _hasChanges() => _summaryLines().isNotEmpty;

  Future<void> _apply() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_pathEnabled && (_pathIds == null || _pathIds!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이동할 경로를 선택해주세요.')),
      );
      return;
    }
    if (_supplierEnabled && _supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거래처를 선택해주세요.')),
      );
      return;
    }
    if (_nameEnabled && !_hasAnyNameMatch()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 아이템 이름에 바꿀 부분이 없습니다.')),
      );
      return;
    }
    if (!_hasChanges()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정할 항목을 선택해주세요.')),
      );
      return;
    }

    final itemRepo = context.read<ItemRepo>();
    final folderRepo = context.read<FolderTreeRepo>();
    final summary = _summaryLines();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('정보 일괄 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('선택한 ${widget.itemIds.length}개 아이템에 적용합니다.'),
              const SizedBox(height: 12),
              for (final line in summary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $line'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      if (_pathEnabled && _pathIds != null) {
        await folderRepo.moveItemsToPath(
          itemIds: widget.itemIds,
          pathIds: _pathIds!,
        );
      }

      for (final itemId in widget.itemIds) {
        final item = await itemRepo.getItem(itemId);
        if (item == null) continue;
        final updated = _updatedItem(item);
        await itemRepo.updateItemMeta(updated);
        await itemRepo.tryFinalizeRegistration(item.id);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일괄 수정 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Item _updatedItem(Item item) {
    final attrs = <String, dynamic>{...?item.attrs};
    attrs.addAll(_attrPatch());

    final minQty = int.tryParse(_minQtyC.text.trim());
    final purchasePrice = double.tryParse(_purchasePriceC.text.trim());
    final salePrice = double.tryParse(_salePriceC.text.trim());
    final conversionRate = double.tryParse(_conversionRateC.text.trim());
    final renamed = _renamedItemText(item);
    final unit = _unitC.text.trim();
    final unitIn = _unitInC.text.trim();
    final unitOut = _unitOutC.text.trim();

    return item.copyWith(
      name: renamed?.name,
      displayName: renamed?.displayName,
      minQty: _minQtyEnabled ? minQty : null,
      attrs: _attrsEnabled ? (attrs.isEmpty ? null : attrs) : null,
      supplierName: _supplierEnabled ? _supplier?.name : null,
      defaultSupplierId: _supplierEnabled ? _supplier?.id : null,
      defaultPurchasePrice: _purchasePriceEnabled ? purchasePrice : null,
      defaultSalePrice: _salePriceEnabled ? salePrice : null,
      unit: _unitEnabled && unit.isNotEmpty ? unit : null,
      unitIn: _conversionEnabled && unitIn.isNotEmpty ? unitIn : null,
      unitOut: _conversionEnabled && unitOut.isNotEmpty ? unitOut : null,
      conversionRate: _conversionEnabled ? conversionRate : null,
      conversionMode: _conversionEnabled ? _conversionMode : null,
    );
  }

  ({String name, String displayName})? _renamedItemText(Item item) {
    if (!_nameEnabled) return null;
    final find = _nameFindC.text.trim();
    if (find.isEmpty) return null;
    final replacement = _nameReplaceC.text.trim();
    final currentDisplayName = (item.displayName?.trim().isNotEmpty == true)
        ? item.displayName!
        : item.name;
    return (
      name: item.name.replaceAll(find, replacement),
      displayName: currentDisplayName.replaceAll(find, replacement),
    );
  }

  bool _hasAnyNameMatch() {
    final find = _nameFindC.text.trim();
    if (find.isEmpty) return false;
    return _items.any((item) {
      final displayName = item.displayName ?? '';
      return item.name.contains(find) || displayName.contains(find);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Text(
                '선택 ${widget.itemIds.length}개 정보 일괄 수정',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _sectionTitle('식별/표시'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _nameEnabled,
                title: const Text('이름/표시명 부분 바꾸기'),
                subtitle: const Text('선택한 아이템마다 포함된 문자열만 치환합니다'),
                onChanged: (value) => setState(() => _nameEnabled = value),
              ),
              if (_nameEnabled) ...[
                _NameReplacementPreview(items: _items, loading: _itemsLoading),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameFindC,
                  decoration: const InputDecoration(
                    labelText: '이름에서 바꿀 부분',
                    hintText: '예: 200*250',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (!_nameEnabled) return null;
                    if (value == null || value.trim().isEmpty) {
                      return '바꿀 부분을 입력하세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameReplaceC,
                  decoration: const InputDecoration(
                    labelText: '이름 새 문자열',
                    hintText: '예: 200*230',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (!_nameEnabled) return null;
                    if ((value ?? '').trim().length > 80) {
                      return '80자 이하로 입력하세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _NameReplacementResultPreview(
                  items: _items,
                  find: _nameFindC.text.trim(),
                  replacement: _nameReplaceC.text.trim(),
                ),
              ],
              const SizedBox(height: 16),
              _sectionTitle('분류'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pathEnabled,
                title: const Text('경로 변경'),
                subtitle: Text(_pathLabel ?? '이동할 경로를 선택하세요'),
                onChanged: (value) {
                  setState(() => _pathEnabled = value);
                  if (value && _pathIds == null) _pickPath();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.drive_file_move),
                label: const Text('경로 선택'),
                onPressed: _pickPath,
              ),
              const SizedBox(height: 16),
              _sectionTitle('거래/재고'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _supplierEnabled,
                title: const Text('거래처 지정'),
                subtitle: Text(_supplier?.name ?? '거래처를 선택하세요'),
                onChanged: (value) {
                  setState(() => _supplierEnabled = value);
                  if (value && _supplier == null) _pickSupplier();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.business),
                label: const Text('거래처 선택'),
                onPressed: _pickSupplier,
              ),
              _enabledNumberField(
                label: '최소재고',
                enabled: _minQtyEnabled,
                onEnabledChanged: (value) =>
                    setState(() => _minQtyEnabled = value),
                controller: _minQtyC,
                integerOnly: true,
              ),
              _enabledNumberField(
                label: '입고가',
                enabled: _purchasePriceEnabled,
                onEnabledChanged: (value) =>
                    setState(() => _purchasePriceEnabled = value),
                controller: _purchasePriceC,
              ),
              _enabledNumberField(
                label: '출고가',
                enabled: _salePriceEnabled,
                onEnabledChanged: (value) =>
                    setState(() => _salePriceEnabled = value),
                controller: _salePriceC,
              ),
              const SizedBox(height: 16),
              _sectionTitle('속성'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _attrsEnabled,
                title: const Text('아이템 속성 추가/수정'),
                subtitle: const Text('예: size, color, form, design'),
                onChanged: (value) => setState(() => _attrsEnabled = value),
              ),
              if (_attrsEnabled) ...[
                for (final row in _attrRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: row.keyC,
                            decoration: const InputDecoration(
                              labelText: '속성명',
                              hintText: 'size',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: row.valueC,
                            decoration: const InputDecoration(
                              labelText: '값',
                              hintText: '60x40',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '속성 삭제',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeAttrRow(row),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('속성 추가'),
                    onPressed: _addAttrRow,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _sectionTitle('단위/환산'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _unitEnabled,
                title: const Text('기본 단위 변경'),
                onChanged: (value) => setState(() => _unitEnabled = value),
              ),
              if (_unitEnabled)
                TextFormField(
                  controller: _unitC,
                  decoration: const InputDecoration(
                    labelText: '기본 단위',
                    hintText: 'EA / M / Roll',
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _conversionEnabled,
                title: const Text('입출고 단위/환산 변경'),
                subtitle: const Text('재고 계산에 영향을 줄 수 있습니다'),
                onChanged: (value) =>
                    setState(() => _conversionEnabled = value),
              ),
              if (_conversionEnabled) ...[
                TextFormField(
                  controller: _unitInC,
                  decoration: const InputDecoration(
                    labelText: '입고 단위',
                    hintText: 'Roll',
                  ),
                ),
                TextFormField(
                  controller: _unitOutC,
                  decoration: const InputDecoration(
                    labelText: '출고 단위',
                    hintText: 'M',
                  ),
                ),
                TextFormField(
                  controller: _conversionRateC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '환산율',
                    hintText: '1 입고단위 = ? 출고단위',
                  ),
                  validator: (value) {
                    if (!_conversionEnabled || value == null || value.isEmpty) {
                      return null;
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return '0보다 큰 숫자를 입력하세요';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _conversionMode,
                  decoration: const InputDecoration(labelText: '환산 방식'),
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('fixed')),
                    DropdownMenuItem(value: 'lot', child: Text('lot')),
                  ],
                  onChanged: (value) =>
                      setState(() => _conversionMode = value ?? 'fixed'),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done),
                label: Text(_saving ? '적용 중...' : '선택 아이템에 적용'),
                onPressed: _saving ? null : _apply,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }

  Widget _enabledNumberField({
    required String label,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required TextEditingController controller,
    bool integerOnly = false,
  }) {
    return Row(
      children: [
        Checkbox(
            value: enabled, onChanged: (v) => onEnabledChanged(v ?? false)),
        Expanded(
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
            validator: (value) {
              if (!enabled) return null;
              if (value == null || value.trim().isEmpty) return '값을 입력하세요';
              if (integerOnly) {
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed < 0) return '0 이상의 정수';
              } else {
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed < 0) return '0 이상의 숫자';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class _NameReplacementPreview extends StatelessWidget {
  const _NameReplacementPreview({
    required this.items,
    required this.loading,
  });

  final List<Item> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    return Column(
      children: [
        _NamePreviewBox(
          title: '기존 이름',
          lines: items.map((item) => item.name).toList(),
        ),
        const SizedBox(height: 8),
        _NamePreviewBox(
          title: '기존 표시명',
          lines: items
              .map((item) => item.displayName?.trim().isNotEmpty == true
                  ? item.displayName!
                  : item.name)
              .toList(),
        ),
      ],
    );
  }
}

class _NameReplacementResultPreview extends StatelessWidget {
  const _NameReplacementResultPreview({
    required this.items,
    required this.find,
    required this.replacement,
  });

  final List<Item> items;
  final String find;
  final String replacement;

  @override
  Widget build(BuildContext context) {
    if (find.isEmpty) {
      return const Text('바꿀 부분을 입력하면 변경 결과를 미리 볼 수 있습니다.');
    }
    final changed = items
        .where((item) =>
            item.name.contains(find) || (item.displayName ?? '').contains(find))
        .toList();
    if (changed.isEmpty) {
      return const Text('선택한 아이템 이름에 바꿀 부분이 없습니다.');
    }
    return _NamePreviewBox(
      title: '변경 후 미리보기',
      lines: changed.map((item) {
        final displayName = item.displayName?.trim().isNotEmpty == true
            ? item.displayName!
            : item.name;
        return displayName.replaceAll(find, replacement);
      }).toList(),
    );
  }
}

class _NamePreviewBox extends StatelessWidget {
  const _NamePreviewBox({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final shown = lines.take(8).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            const Text('선택한 아이템을 불러오지 못했습니다.')
          else
            for (final line in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(line),
              ),
          if (lines.length > shown.length)
            Text('외 ${lines.length - shown.length}개'),
        ],
      ),
    );
  }
}

class _BulkAttrRow {
  final keyC = TextEditingController();
  final valueC = TextEditingController();

  void dispose() {
    keyC.dispose();
    valueC.dispose();
  }
}
