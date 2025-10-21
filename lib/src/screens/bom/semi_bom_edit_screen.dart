
// lib/src/screens/bom/semi_bom_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/bom.dart';
import 'bom_row_editor.dart';

class SemiBomEditScreen extends StatefulWidget {
  final String semiItemId;
  const SemiBomEditScreen({super.key, required this.semiItemId});

  @override
  State<SemiBomEditScreen> createState() => _SemiBomEditScreenState();
}

class _SemiBomEditScreenState extends State<SemiBomEditScreen> {
  late List<BomRow> _rows;

  @override
  void initState() {
    super.initState();
    final repo = context.read<ItemRepo>();
    _rows = List.of(repo.semiBomOf(widget.semiItemId));
  }

  void _addRow() async {
    final r = await showDialog<BomRow>(
      context: context,
      builder: (_) => BomRowEditor(root: BomRoot.semi, parentItemId: widget.semiItemId),
    );
    if (r != null) {
      if (_rows.any((e) => e.componentItemId == r.componentItemId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('중복 구성은 한 번만 추가하세요.')));
        return;
      }
      if (r.kind == BomKind.semi) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semi BOM에는 semi가 올 수 없습니다.')));
        return;
      }
      setState(() => _rows.add(r));
    }
  }

  void _editRow(int idx) async {
    final r0 = _rows[idx];
    final r = await showDialog<BomRow>(
      context: context,
      builder: (_) => BomRowEditor(root: BomRoot.semi, parentItemId: widget.semiItemId, initial: r0),
    );
    if (r != null) {
      if (r.kind == BomKind.semi) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semi BOM에는 semi가 올 수 없습니다.')));
        return;
      }
      if (r.componentItemId == widget.semiItemId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('자기 자신 참조 금지')));
        return;
      }
      setState(() => _rows[idx] = r);
    }
  }

  Future<void> _save() async {
    final repo = context.read<ItemRepo>();
    await repo.upsertSemiBom(widget.semiItemId, _rows);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Semi BOM 편집'), actions: [
        TextButton(onPressed: _save, child: const Text('저장', style: TextStyle(color: Colors.white)))
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _addRow, child: const Icon(Icons.add)),
      body: _rows.isEmpty
          ? const Center(child: Text('레시피가 없습니다. + 버튼으로 행을 추가하세요.'))
          : ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = _rows[i];
          return ListTile(
            leading: Icon(r.kind == BomKind.raw ? Icons.category : Icons.extension),
            title: Text('${r.componentItemId}  x ${r.qtyPer}  (loss ${r.wastePct})'),
            onTap: () => _editRow(i),
            trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _rows.removeAt(i))),
          );
        },
      ),
    );
  }
}

