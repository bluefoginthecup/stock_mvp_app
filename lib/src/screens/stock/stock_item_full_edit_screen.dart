import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';

class StockItemFullEditScreen extends StatefulWidget {
  final String itemId;
  const StockItemFullEditScreen({super.key, required this.itemId});

  @override
  State<StockItemFullEditScreen> createState() => _StockItemFullEditScreenState();
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
  late TextEditingController attrsC; // JSON 텍스트

  late TextEditingController unitInC;
  late TextEditingController unitOutC;
  late TextEditingController conversionRateC;
  String conversionMode = 'fixed'; // fixed | lot
  late TextEditingController supplierC;


    late Future<Item?> _itemFuture;
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
        attrsC = TextEditingController();
        unitInC = TextEditingController();
        unitOutC = TextEditingController();
        conversionRateC = TextEditingController();
        supplierC = TextEditingController();

        // 2) 아이템은 비동기로 로드
        final repo = context.read<ItemRepo>();
        _itemFuture = repo.getItemById(widget.itemId);
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
    attrsC.dispose();
    unitInC.dispose();
    unitOutC.dispose();
    conversionRateC.dispose();
    supplierC.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _parseAttrs(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final m = json.decode(s);
      if (m is Map<String, dynamic>) return m;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = context.read<ItemRepo>();
    final i = _loaded!;
    final parsedAttrs = _parseAttrs(attrsC.text);

    // 수치 파싱
    final minQty = int.tryParse(minQtyC.text.trim());
    final qty = int.tryParse(qtyC.text.trim()); // qty는 권장: 별도 Adjust 플로우 사용. 여기선 옵션.
    final convRate = double.tryParse(conversionRateC.text.trim());

    // 경고: qty를 여기서 바꾸면 Txn 없이 점프함(재무 이력 없음).
    // 운영정책에 따라 숨기거나 readOnly로 두는 게 안전.
    // 원한다면 아래 line 제거하고 Adjust 플로우만 쓰세요.
    final wantUpdateQtyHere = false;
    // ✅ Item 전체를 만들어 updateItemMeta에 전달
        final updated = Item(
          id: i.id,
          name: i.name,
          displayName: displayNameC.text.trim().isEmpty ? i.displayName : displayNameC.text.trim(),
          sku: i.sku,
          unit: unitC.text.trim().isEmpty ? i.unit : unitC.text.trim(),
          folder: folderC.text.trim().isEmpty ? i.folder : folderC.text.trim(),
          subfolder: subfolderC.text.trim().isEmpty ? i.subfolder : subfolderC.text.trim(),
          subsubfolder: subsubfolderC.text.trim().isEmpty ? i.subsubfolder : subsubfolderC.text.trim(),
          minQty: minQty ?? i.minQty,
          qty: i.qty, // 여기선 건드리지 않음 (Adjust 권장)
          kind: kindC.text.trim().isEmpty ? i.kind : kindC.text.trim(),
          attrs: parsedAttrs ?? i.attrs,
          unitIn: unitInC.text.trim().isEmpty ? i.unitIn : unitInC.text.trim(),
          unitOut: unitOutC.text.trim().isEmpty ? i.unitOut : unitOutC.text.trim(),
          conversionRate: convRate ?? i.conversionRate,
          conversionMode: conversionMode,
          stockHints: i.stockHints,
          supplierName: supplierC.text.trim().isEmpty ? i.supplierName : supplierC.text.trim(),
          isFavorite: i.isFavorite,
        );

        await repo.updateItemMeta(updated);


    Navigator.pop(context, true);
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
        return FutureBuilder<Item?>(
          future: _itemFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
              attrsC.text = (item.attrs == null || item.attrs!.isEmpty)
                  ? ''
                  : const JsonEncoder.withIndent('  ').convert(item.attrs);
              unitInC.text = item.unitIn ?? '';
              unitOutC.text = item.unitOut ?? '';
              conversionRateC.text = (item.conversionRate ?? 0).toString();
              conversionMode = item.conversionMode;
              supplierC.text = item.supplierName ?? '';
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
              Text('식별/표시', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(controller: nameC, decoration: _dec('name'), readOnly: true),
              TextFormField(controller: displayNameC, decoration: _dec('displayName')),
              TextFormField(controller: skuC, decoration: _dec('sku'), readOnly: true),

              const SizedBox(height: 16),
              Text('단위/경로', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(controller: unitC, decoration: _dec('unit (EA/SET/ROLL...)')),
              TextFormField(controller: folderC, decoration: _dec('folder')),
              TextFormField(controller: subfolderC, decoration: _dec('subfolder')),
              TextFormField(controller: subsubfolderC, decoration: _dec('subsubfolder')),

              const SizedBox(height: 16),
              Text('재고/임계치', style: text.titleSmall),
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
                decoration: _dec('qty (권장: Adjust 사용)', hint: '롱프레스 or 하단 버튼 사용'),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),
              Text('분류/속성', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(controller: kindC, decoration: _dec('kind (Finished / SemiFinished / Sub ...)')),
              // 아이템 편집 화면
              // build 안
              TextFormField(
                controller: supplierC,
                decoration: const InputDecoration(labelText: '공급처(상호)'),
              ),
              TextFormField(
                controller: attrsC,
                decoration: _dec('attrs (JSON)'),
                maxLines: 6,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  try {
                    final parsed = json.decode(v);
                    if (parsed is! Map) return 'JSON Map 형태여야 합니다';
                  } catch (e) {
                    return 'JSON 파싱 오류: $e';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),
              Text('환산/모드', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(controller: unitInC, decoration: _dec('unit_in')),
              TextFormField(controller: unitOutC, decoration: _dec('unit_out')),
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
                      DropdownMenuItem(value: 'fixed', child: Text('fixed')),
                      DropdownMenuItem(value: 'lot', child: Text('lot')),
                    ],
                    onChanged: (v) => setState(() => conversionMode = v ?? 'fixed'),
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
