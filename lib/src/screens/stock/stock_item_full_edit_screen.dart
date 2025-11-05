import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item.dart';
import '../../repos/inmem_repo.dart';

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

  Item? it;

  @override
  void initState() {
    super.initState();
    final repo = context.read<InMemoryRepo>();
    it = repo.getItemById(widget.itemId);
    if (it == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      // 더미 초기화
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
      if (it != null) {
        supplierC = TextEditingController(text: it!.supplierName ?? '');
      } else {
        supplierC = TextEditingController();
      }
      return;
    }

    final i = it!;
    nameC = TextEditingController(text: i.name);
    displayNameC = TextEditingController(text: i.displayName ?? '');
    skuC = TextEditingController(text: i.sku);

    unitC = TextEditingController(text: i.unit);
    folderC = TextEditingController(text: i.folder);
    subfolderC = TextEditingController(text: i.subfolder ?? '');
    subsubfolderC = TextEditingController(text: i.subsubfolder ?? '');

    minQtyC = TextEditingController(text: i.minQty.toString());
    qtyC = TextEditingController(text: i.qty.toString());

    kindC = TextEditingController(text: i.kind ?? '');
    attrsC = TextEditingController(
      text: (i.attrs == null || i.attrs!.isEmpty)
          ? ''
          : const JsonEncoder.withIndent('  ').convert(i.attrs),
    );

    unitInC = TextEditingController(text: i.unitIn);
    unitOutC = TextEditingController(text: i.unitOut);
    conversionRateC = TextEditingController(text: i.conversionRate.toString());
    conversionMode = i.conversionMode;
    supplierC = TextEditingController(text: i.supplierName ?? '');
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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = context.read<InMemoryRepo>();
    final i = it!;
    final parsedAttrs = _parseAttrs(attrsC.text);

    // 수치 파싱
    final minQty = int.tryParse(minQtyC.text.trim());
    final qty = int.tryParse(qtyC.text.trim()); // qty는 권장: 별도 Adjust 플로우 사용. 여기선 옵션.
    final convRate = double.tryParse(conversionRateC.text.trim());

    // 경고: qty를 여기서 바꾸면 Txn 없이 점프함(재무 이력 없음).
    // 운영정책에 따라 숨기거나 readOnly로 두는 게 안전.
    // 원한다면 아래 line 제거하고 Adjust 플로우만 쓰세요.
    final wantUpdateQtyHere = false;

    repo.updateItemMeta(
      id: i.id,

      // 표기/분류
      displayName: displayNameC.text.trim().isEmpty ? null : displayNameC.text.trim(),
      minQty: minQty,
      unit: unitC.text.trim().isEmpty ? null : unitC.text.trim(),
      folder: folderC.text.trim().isEmpty ? null : folderC.text.trim(),
      subfolder: subfolderC.text.trim().isEmpty ? null : subfolderC.text.trim(),
      subsubfolder: subsubfolderC.text.trim().isEmpty ? null : subsubfolderC.text.trim(),
      kind: kindC.text.trim().isEmpty ? null : kindC.text.trim(),
      attrs: parsedAttrs, // mergeAttrs=true 기본 → 기존 키 유지되며 덮어쓰기

      // 공급처
      supplierName: supplierC.text.trim().isEmpty ? null : supplierC.text.trim(),
      // 환산
      unitIn: unitInC.text.trim().isEmpty ? null : unitInC.text.trim(),
      unitOut: unitOutC.text.trim().isEmpty ? null : unitOutC.text.trim(),
      conversionRate: convRate,
      conversionMode: conversionMode,

      // qty는 여기서 건드리지 않음(이력 보존 위해)
      // 만약 정말 여기서 갱신하고 싶다면 InMemoryRepo.updateItemMeta에 qty: 전달하도록 확장
    );

    if (wantUpdateQtyHere && qty != null) {
      // 정말 여기서 qty까지 바꾸려면 InMemoryRepo.updateItemMeta에 qty 파라미터 추가 필요
      // repo.updateItemMeta(id: i.id, qty: qty);
    }

    Navigator.pop(context, true);
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  @override
  Widget build(BuildContext context) {
    if (it == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

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
  }
}
