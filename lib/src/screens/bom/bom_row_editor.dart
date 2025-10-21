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
    if (widget.root == BomRoot.semi && _kind == BomKind.semi) {
      _kind = BomKind.raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kindItems = <DropdownMenuItem<BomKind>>[
      if (widget.root == BomRoot.finished)
        const DropdownMenuItem(value: BomKind.semi, child: Text('Semi-finished')),
      const DropdownMenuItem(value: BomKind.raw, child: Text('Raw')),
      const DropdownMenuItem(value: BomKind.sub, child: Text('Sub')),
    ];

    return AlertDialog(
      title: Text(widget.initial == null ? '행 추가' : '행 수정'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ 구성품 선택: 선택 전엔 안내문구, 선택 후엔 ItemLabel(이름 표시) + ID 보조표시
            ListTile(
              title: _componentId == null
                  ? const Text('구성품 선택')
                  : ItemLabel(itemId: _componentId!, full: true, maxLines: 2, softWrap: true),
              subtitle: _componentId == null ? null : Text(_componentId!, style: const TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.search),
              onTap: () async {
                final picked = await showDialog<String>(
                  context: context,
                  builder: (_) => ComponentPicker(
                    root: widget.root,     // ✅ 빠졌던 root 전달
                    initialQuery: '',      // 선택사항
                  ),
                );
                if (picked != null) setState(() => _componentId = picked);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('종류  '),
                const SizedBox(width: 8),
                DropdownButton<BomKind>(
                  value: _kind,
                  items: kindItems,
                  onChanged: (v) {
                    if (v != null) setState(() => _kind = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '수량(1개당)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _wasteC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '로스율(0~1)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () {
            if (_componentId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('구성품을 선택하세요.')));
              return;
            }
            if (_componentId == widget.parentItemId) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('자기 자신은 구성품이 될 수 없습니다.')));
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
          },
          child: Text(widget.initial == null ? '추가' : '적용'),
        ),
      ],
    );
  }
}
