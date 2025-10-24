// lib/src/screens/bom/bom_row_editor.dart
import 'package:flutter/material.dart';
import '../../models/bom.dart';
import 'component_picker.dart';
// ✅ 선택된 구성품을 사람이 읽을 이름으로 보여주기
import '../../utils/item_presentation.dart'; // ItemLabel(itemId: ...)

class BomRowEditor extends StatefulWidget {
  final BomRoot root;
  final String parentItemId;
  final BomRow? initial;
  const BomRowEditor({super.key, required this.root, required this.parentItemId, this.initial});

  @override
  State<BomRowEditor> createState() => _BomRowEditorState();
}

class _BomRowEditorState extends State<BomRowEditor> {
  late BomKind _kind;
  String? _componentId;
  final _qtyC = TextEditingController();
  final _wasteC = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _kind = widget.initial?.kind ?? BomKind.semi;
    _componentId = widget.initial?.componentItemId;
    _qtyC.text = (widget.initial?.qtyPer ?? 1).toString();
    _wasteC.text = (widget.initial?.wastePct ?? 0).toString();

    // Semi BOM 안에는 semi를 넣지 못하게 기본값 보정
    if (widget.root == BomRoot.semi && _kind == BomKind.semi) {
      _kind = BomKind.raw;
    }
  }

  @override
  void dispose() {
    _qtyC.dispose();
    _wasteC.dispose();
    super.dispose();
  }

  Future<void> _pickComponent() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => ComponentPicker(
        root: widget.root,
        initialQuery: '',
      ),
    );
    if (picked != null) setState(() => _componentId = picked);
  }

  void _save() {
    if (_componentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('구성품을 선택하세요.')));
      return;
    }
    if (_componentId == widget.parentItemId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('자기 자신은 구성품이 될 수 없습니다.')));
      return;
    }
    final qty = double.tryParse(_qtyC.text.trim());
    final waste = double.tryParse(_wasteC.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수량을 올바르게 입력하세요.')));
      return;
    }
    if (waste == null || waste < 0 || waste > 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로스율은 0~1 사이로 입력하세요.')));
      return;
    }
    if (widget.root == BomRoot.semi && _kind == BomKind.semi) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semi BOM에는 semi가 올 수 없습니다.')));
      return;
    }

    final row = BomRow(
      root: widget.root,
      parentItemId: widget.parentItemId,
      componentItemId: _componentId!,
      kind: _kind,
      qtyPer: qty,
      wastePct: waste,
    );
    Navigator.pop(context, row);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // 화면 비율 기반으로 여유있는 크기
    final dialogW = (size.width * 0.8).clamp(600.0, 900.0);
    final dialogH = (size.height * 0.8).clamp(480.0, 700.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Column(
          children: [
            // 헤더(타이틀바)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    widget.initial == null ? '행 추가' : '행 수정',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '닫기',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 본문
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // ✅ 구성품 선택: 선택 전 안내 / 선택 후 라벨+ID 보조표시
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: _componentId == null
                            ? const Text('구성품 선택')
                            : ItemLabel(itemId: _componentId!, full: false, maxLines: 2, softWrap: true),
                        subtitle: _componentId == null
                            ? null
                            : Text(_componentId!, style: const TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.search),
                        onTap: _pickComponent,
                      ),
                      const SizedBox(height: 12),

                      // 종류 선택
                      Row(
                        children: [
                          const Text('종류  '),
                          const SizedBox(width: 8),
                          DropdownButton<BomKind>(
                            value: _kind,
                            items: [
                              if (widget.root == BomRoot.finished)
                                const DropdownMenuItem(value: BomKind.semi, child: Text('Semi-finished')),
                              const DropdownMenuItem(value: BomKind.raw, child: Text('Raw')),
                              const DropdownMenuItem(value: BomKind.sub, child: Text('Sub')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _kind = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 수량
                      TextFormField(
                        controller: _qtyC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '수량(1개당)',
                          helperText: '완제품 1개를 만들 때 필요한 구성품 수량',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 로스율
                      TextFormField(
                        controller: _wasteC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '로스율(0~1)',
                          helperText: '예: 0.05 = 5% 로스',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(widget.initial == null ? '추가' : '적용'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
