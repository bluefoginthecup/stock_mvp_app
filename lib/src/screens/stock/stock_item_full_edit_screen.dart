import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/path_picker.dart';
import '../../utils/item_registration.dart';

const _systemAttrKeys = {
  'temporary',
  'status',
  'source',
  'createdFromPurchaseOrderId',
  'createdAt',
};

const _protectedAttrKeys = {
  'color_no',
  'nominalSize',
};

const _defaultAttrTemplates = [
  _AttrTemplate(key: 'design', label: '디자인'),
  _AttrTemplate(key: 'color_name', label: '색상명'),
  _AttrTemplate(
    key: 'color_no',
    label: '색상번호',
    protectedReason: '발주 색상번호에 사용됩니다.',
  ),
  _AttrTemplate(key: 'form', label: '형태'),
  _AttrTemplate(
    key: 'nominalSize',
    label: '표기 사이즈',
    protectedReason: '발주서 스펙 출력에 사용됩니다.',
  ),
  _AttrTemplate(key: 'cutSize', label: '재단 사이즈'),
];

class _AttrTemplate {
  final String key;
  final String label;
  final String? protectedReason;

  const _AttrTemplate({
    required this.key,
    required this.label,
    this.protectedReason,
  });
}

class _AttrEditorRow {
  final TextEditingController keyC;
  final TextEditingController valueC;
  final String? label;
  final String? protectedReason;

  _AttrEditorRow({
    required String key,
    required String value,
    this.label,
    this.protectedReason,
  })  : keyC = TextEditingController(text: key),
        valueC = TextEditingController(text: value);

  bool get isProtected =>
      protectedReason != null || _protectedAttrKeys.contains(keyC.text.trim());

  void dispose() {
    keyC.dispose();
    valueC.dispose();
  }
}

class StockItemFullEditScreen extends StatefulWidget {
  final String itemId;
  const StockItemFullEditScreen({super.key, required this.itemId});

  @override
  State<StockItemFullEditScreen> createState() =>
      _StockItemFullEditScreenState();
}

class _StockItemFullEditScreenState extends State<StockItemFullEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  late TextEditingController nameC;
  late TextEditingController displayNameC;
  late TextEditingController skuC;

  late TextEditingController unitC;
  late TextEditingController folderC;
  late TextEditingController subfolderC;
  late TextEditingController subsubfolderC;

  late TextEditingController minQtyC;
  late TextEditingController qtyC;

  late TextEditingController kindC;
  final List<_AttrEditorRow> _attrRows = [];
  Map<String, dynamic> _hiddenSystemAttrs = const {};

  late TextEditingController unitInC;
  late TextEditingController unitOutC;
  late TextEditingController conversionRateC;
  String conversionMode = 'fixed'; // fixed | lot
  late TextEditingController supplierC;
  late TextEditingController purchasePriceC;
  late TextEditingController salePriceC;

  late Future<Item?> _itemFuture;
  late Future<List<String>> _registrationMissingFuture;
  Item? _loaded; // 로드된 원본 아이템 보관(저장 시 기반)

  @override
  void initState() {
    super.initState();
    // 1) 컨트롤러는 빈 값으로 먼저 생성(디스포즈 안전)
    nameC = TextEditingController();
    displayNameC = TextEditingController();
    skuC = TextEditingController();
    unitC = TextEditingController();
    folderC = TextEditingController();
    subfolderC = TextEditingController();
    subsubfolderC = TextEditingController();
    minQtyC = TextEditingController();
    qtyC = TextEditingController();
    kindC = TextEditingController();
    unitInC = TextEditingController();
    unitOutC = TextEditingController();
    conversionRateC = TextEditingController();
    supplierC = TextEditingController();
    purchasePriceC = TextEditingController();
    salePriceC = TextEditingController();

    // 2) 아이템은 비동기로 로드
    final repo = context.read<ItemRepo>();
    _itemFuture = repo.getItemById(widget.itemId);
    _registrationMissingFuture = repo.registrationMissingFields(widget.itemId);
  }

  @override
  void dispose() {
    nameC.dispose();
    displayNameC.dispose();
    skuC.dispose();
    unitC.dispose();
    folderC.dispose();
    subfolderC.dispose();
    subsubfolderC.dispose();
    minQtyC.dispose();
    qtyC.dispose();
    kindC.dispose();
    for (final row in _attrRows) {
      row.dispose();
    }
    unitInC.dispose();
    unitOutC.dispose();
    conversionRateC.dispose();
    supplierC.dispose();
    purchasePriceC.dispose();
    salePriceC.dispose();
    super.dispose();
  }

  void _resetAttrEditors(Map<String, dynamic>? attrs) {
    for (final row in _attrRows) {
      row.dispose();
    }
    _attrRows.clear();

    final source = Map<String, dynamic>.from(attrs ?? const {});
    _hiddenSystemAttrs = {
      for (final entry in source.entries)
        if (_systemAttrKeys.contains(entry.key)) entry.key: entry.value,
    };

    final usedKeys = <String>{..._systemAttrKeys};
    for (final template in _defaultAttrTemplates) {
      final value = source[template.key];
      _attrRows.add(
        _AttrEditorRow(
          key: template.key,
          value: _attrValueToText(value),
          label: template.label,
          protectedReason: template.protectedReason,
        ),
      );
      usedKeys.add(template.key);
    }

    final extraKeys =
        source.keys.where((key) => !usedKeys.contains(key)).toList()..sort();
    for (final key in extraKeys) {
      _attrRows.add(
        _AttrEditorRow(
          key: key,
          value: _attrValueToText(source[key]),
        ),
      );
    }
  }

  String _attrValueToText(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  Map<String, dynamic>? _buildAttrsFromRows() {
    final attrs = <String, dynamic>{..._hiddenSystemAttrs};
    for (final row in _attrRows) {
      final key = row.keyC.text.trim();
      final value = row.valueC.text.trim();
      if (key.isEmpty || value.isEmpty) continue;
      attrs[key] = value;
    }
    return attrs.isEmpty ? null : attrs;
  }

  Map<String, int> _attrKeyCounts() {
    final counts = <String, int>{};
    for (final row in _attrRows) {
      final key = row.keyC.text.trim();
      final value = row.valueC.text.trim();
      if (key.isEmpty && value.isEmpty) continue;
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  void _addAttrRow() {
    setState(() {
      _attrRows.add(_AttrEditorRow(key: '', value: ''));
    });
  }

  void _removeAttrRow(_AttrEditorRow row) {
    if (row.isProtected) return;
    setState(() {
      _attrRows.remove(row);
      row.dispose();
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = context.read<ItemRepo>();
    final i = _loaded!;
    final parsedAttrs = _buildAttrsFromRows();

    // 수치 파싱
    final minQty = int.tryParse(minQtyC.text.trim());
    final convRate = double.tryParse(conversionRateC.text.trim());

    final purchasePrice = double.tryParse(purchasePriceC.text.trim());
    final salePrice = double.tryParse(salePriceC.text.trim());

    // ✅ Item 전체를 만들어 updateItemMeta에 전달
    final updated = Item(
      id: i.id,
      name: i.name,
      displayName: displayNameC.text.trim().isEmpty
          ? i.displayName
          : displayNameC.text.trim(),
      sku: i.sku,
      unit: unitC.text.trim().isEmpty ? i.unit : unitC.text.trim(),
      folder: i.folder,
      subfolder: i.subfolder,
      subsubfolder: i.subsubfolder,
      minQty: minQty ?? i.minQty,
      qty: i.qty, // 여기선 건드리지 않음 (Adjust 권장)
      kind: kindC.text.trim().isEmpty ? i.kind : kindC.text.trim(),
      attrs: parsedAttrs,
      unitIn: unitInC.text.trim().isEmpty ? i.unitIn : unitInC.text.trim(),
      unitOut: unitOutC.text.trim().isEmpty ? i.unitOut : unitOutC.text.trim(),
      conversionRate: convRate ?? i.conversionRate,
      conversionMode: conversionMode,
      stockHints: i.stockHints,
      supplierName: supplierC.text.trim().isEmpty
          ? i.supplierName
          : supplierC.text.trim(),
      defaultSupplierId: i.defaultSupplierId,
      defaultPrice: i.defaultPrice,
      isFavorite: i.isFavorite,
      defaultPurchasePrice: purchasePrice ?? i.defaultPurchasePrice,
      defaultSalePrice: salePrice ?? i.defaultSalePrice,
    );

    await repo.updateItemMeta(updated);
    final finalized = await repo.tryFinalizeRegistration(i.id);

    if (!mounted) return;
    if (finalized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정식등록 완료')),
      );
    }
    Navigator.pop(context, true);
  }

  Future<void> _moveThisItem() async {
    final item = _loaded;
    if (item == null) return;

    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();
    final dest = await showPathPicker(
      context,
      childrenProvider: (String? parentId) async {
        final folders = await folderRepo.listFolderChildren(parentId);
        return folders.map((f) => PathNode(f.id, f.name)).toList();
      },
      title: '아이템 이동',
      maxDepth: 3,
    );
    if (dest == null || dest.isEmpty) return;

    try {
      final moved = await folderRepo.moveItemsToPath(
        itemIds: [item.id],
        pathIds: dest,
      );
      final finalized = await itemRepo.tryFinalizeRegistration(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(finalized ? '정식등록 완료' : '아이템 $moved개 이동')),
      );
      setState(() {
        _loaded = null;
        _itemFuture = itemRepo.getItemById(widget.itemId);
        _registrationMissingFuture =
            itemRepo.registrationMissingFields(widget.itemId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이동 실패: $e')),
      );
    }
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  Widget _buildRegistrationNotice(List<String> missing) {
    final items = missing.isEmpty ? const ['필수값 확인 필요'] : missing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_late_outlined,
                  size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '정식등록 필요 아이템입니다. 필수값을 입력해주세요.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (text) => Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text('- $text'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrsEditor(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _attrKeyCounts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('품목 속성', style: theme.textTheme.titleSmall),
            ),
            TextButton.icon(
              onPressed: _addAttrRow,
              icon: const Icon(Icons.add),
              label: const Text('속성 추가'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '속성명과 값을 자유롭게 편집할 수 있습니다. '
          '색상번호와 표기 사이즈는 발주 기능에서 사용되어 속성명 변경/삭제가 제한됩니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
        if (_hiddenSystemAttrs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '시스템 속성 ${_hiddenSystemAttrs.length}개는 숨긴 상태로 보존됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ..._attrRows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildAttrRow(context, row, counts),
          ),
        ),
      ],
    );
  }

  Widget _buildAttrRow(
    BuildContext context,
    _AttrEditorRow row,
    Map<String, int> counts,
  ) {
    final protectedReason = row.protectedReason;
    final isProtected = row.isProtected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: TextFormField(
            controller: row.keyC,
            readOnly: isProtected,
            decoration: InputDecoration(
              labelText: row.label == null ? '속성명' : '${row.label} 속성명',
              helperText: protectedReason,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              final key = value?.trim() ?? '';
              final attrValue = row.valueC.text.trim();
              if (key.isEmpty && attrValue.isEmpty) return null;
              if (key.isEmpty) return '속성명 필요';
              if (_systemAttrKeys.contains(key)) return '시스템 속성명은 사용할 수 없습니다';
              if ((counts[key] ?? 0) > 1) return '중복 속성명';
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: TextFormField(
            controller: row.valueC,
            decoration: InputDecoration(
              labelText: row.label ?? '값',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: isProtected ? '보호된 속성은 삭제할 수 없습니다' : '속성 삭제',
          onPressed: isProtected ? null : () => _removeAttrRow(row),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FutureBuilder<Item?>(
      future: _itemFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final item = snap.data;
        if (item == null) {
          // 없는 아이템이면 뒤로
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return const SizedBox.shrink();
        }
        // 최초 로드시에만 컨트롤러 텍스트 채우기 (사용자가 수정한 값 덮어쓰기 방지)
        if (_loaded == null) {
          _loaded = item;
          nameC.text = item.name;
          displayNameC.text = item.displayName ?? '';
          skuC.text = item.sku;
          unitC.text = item.unit;
          folderC.text = item.folder;
          subfolderC.text = item.subfolder ?? '';
          subsubfolderC.text = item.subsubfolder ?? '';
          minQtyC.text = item.minQty.toString();
          qtyC.text = item.qty.toString();
          kindC.text = item.kind ?? '';
          _resetAttrEditors(item.attrs);
          unitInC.text = item.unitIn;
          unitOutC.text = item.unitOut;
          conversionRateC.text = item.conversionRate.toString();
          conversionMode = item.conversionMode;
          supplierC.text = item.supplierName ?? '';
          purchasePriceC.text = (item.defaultPurchasePrice ?? 0).toString();
          salePriceC.text = (item.defaultSalePrice ?? 0).toString();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('모든 필드 편집'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _save,
                tooltip: '저장',
              ),
            ],
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isNeedsRegistrationItem(item))
                    FutureBuilder<List<String>>(
                      future: _registrationMissingFuture,
                      builder: (context, missingSnap) {
                        final missing = missingSnap.data ?? const <String>[];
                        return _buildRegistrationNotice(missing);
                      },
                    ),
                  if (isNeedsRegistrationItem(item)) const SizedBox(height: 16),
                  Text('식별/표시', style: text.titleSmall),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: nameC,
                      decoration: _dec('name'),
                      readOnly: true),
                  FutureBuilder<List<String>>(
                    future: _registrationMissingFuture,
                    builder: (context, missingSnap) {
                      final missing = missingSnap.data ?? const <String>[];
                      return TextFormField(
                        controller: displayNameC,
                        decoration: _dec('displayName').copyWith(
                          helperText: missing.contains('아이템명 필요')
                              ? '필수값을 입력해주세요'
                              : null,
                        ),
                      );
                    },
                  ),
                  TextFormField(
                      controller: skuC,
                      decoration: _dec('sku'),
                      readOnly: true),

                  const SizedBox(height: 16),
                  Text('단위/경로', style: text.titleSmall),
                  const SizedBox(height: 8),
                  FutureBuilder<List<String>>(
                    future: _registrationMissingFuture,
                    builder: (context, missingSnap) {
                      final missing = missingSnap.data ?? const <String>[];
                      return TextFormField(
                        controller: unitC,
                        decoration: _dec('unit (EA/SET/ROLL...)').copyWith(
                          helperText:
                              missing.contains('단위 필요') ? '필수값을 입력해주세요' : null,
                        ),
                      );
                    },
                  ),
                  FutureBuilder<List<String>>(
                    future: context.read<ItemRepo>().itemPathNames(item.id),
                    builder: (context, pathSnap) {
                      final pathNames = pathSnap.data ?? const <String>[];
                      final pathText =
                          pathNames.isEmpty ? '경로 없음' : pathNames.join(' / ');
                      return FutureBuilder<List<String>>(
                        future: _registrationMissingFuture,
                        builder: (context, missingSnap) {
                          final missing = missingSnap.data ?? const <String>[];
                          return TextFormField(
                            key: ValueKey(pathText),
                            initialValue: pathText,
                            readOnly: true,
                            decoration: _dec(
                              'folder path',
                              hint: '폴더 이동 버튼으로 변경',
                            ).copyWith(
                              helperText: missing.contains('폴더 경로 필요')
                                  ? '폴더 이동 버튼으로 실제 폴더를 선택해주세요'
                                  : null,
                              suffixIcon: IconButton(
                                tooltip: '폴더 이동',
                                icon: const Icon(Icons.drive_file_move),
                                onPressed: _moveThisItem,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  TextFormField(
                    controller: folderC,
                    readOnly: true,
                    decoration: _dec('folder (동기화 표시)'),
                  ),
                  TextFormField(
                    controller: subfolderC,
                    readOnly: true,
                    decoration: _dec('subfolder (동기화 표시)'),
                  ),
                  TextFormField(
                    controller: subsubfolderC,
                    readOnly: true,
                    decoration: _dec('subsubfolder (동기화 표시)'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.drive_file_move),
                      label: const Text('폴더 이동'),
                      onPressed: _moveThisItem,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text('재고/임계치', style: text.titleSmall),
                  const SizedBox(height: 16),
                  Text('가격', style: text.titleSmall),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: purchasePriceC,
                          decoration: _dec('기본 입고가'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: salePriceC,
                          decoration: _dec('기본 출고가'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: minQtyC,
                    decoration: _dec('minQty'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v);
                      if (n == null || n < 0) return '0 이상의 정수';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: qtyC,
                    readOnly: true, // 운영권장: Adjust 플로우 사용
                    decoration:
                        _dec('qty (권장: Adjust 사용)', hint: '롱프레스 or 하단 버튼 사용'),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 16),
                  Text('분류/속성', style: text.titleSmall),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: kindC,
                      decoration:
                          _dec('kind (Finished / SemiFinished / Sub ...)')),
                  // 아이템 편집 화면
                  // build 안
                  TextFormField(
                    controller: supplierC,
                    decoration: const InputDecoration(labelText: '공급처(상호)'),
                  ),
                  const SizedBox(height: 12),
                  _buildAttrsEditor(context),

                  const SizedBox(height: 16),
                  Text('환산/모드', style: text.titleSmall),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: unitInC, decoration: _dec('unit_in')),
                  TextFormField(
                      controller: unitOutC, decoration: _dec('unit_out')),
                  TextFormField(
                    controller: conversionRateC,
                    decoration: _dec('conversion_rate'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final d = double.tryParse(v);
                      if (d == null || d <= 0) return '0보다 큰 숫자';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('conversion_mode:'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: conversionMode,
                        items: const [
                          DropdownMenuItem(
                              value: 'fixed', child: Text('fixed')),
                          DropdownMenuItem(value: 'lot', child: Text('lot')),
                        ],
                        onChanged: (v) =>
                            setState(() => conversionMode = v ?? 'fixed'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('저장'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
