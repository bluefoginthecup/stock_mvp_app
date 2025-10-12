import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';

class StockNewItemSheet extends StatefulWidget {
  const StockNewItemSheet({super.key});

  @override
  State<StockNewItemSheet> createState() => _StockNewItemSheetState();
}

class _StockNewItemSheetState extends State<StockNewItemSheet> {
  final _nameC = TextEditingController();
  final _skuC = TextEditingController();
  final _unitC = TextEditingController(text: 'EA');
  final _folderC = TextEditingController(text: 'finished');
  final _subC = TextEditingController();
  final _minC = TextEditingController(text: '5');
  final _qtyC = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ItemRepo>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('새 품목', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'context.t.field_name')),
              TextField(controller: _skuC, decoration: const InputDecoration(labelText: 'context.t.field_sku')),
              TextField(controller: _unitC, decoration: const InputDecoration(labelText: 'context.t.field_unit_hint')),
              TextField(controller: _folderC, decoration: const InputDecoration(labelText: 'context.t.field_folder_hint')),
              TextField(controller: _subC, decoration: const InputDecoration(labelText: 'context.t.field_subfolder_optional')),
              TextField(controller: _minC, decoration: const InputDecoration(labelText: 'context.t.field_threshold'), keyboardType: TextInputType.number),
              TextField(controller: _qtyC, decoration: const InputDecoration(labelText: 'context.t.field_initial_qty'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final id = const Uuid().v4();
                  final item = Item(
                    id: id,
                    name: _nameC.text.trim(),
                    sku: _skuC.text.trim(),
                    unit: _unitC.text.trim(),
                    folder: _folderC.text.trim(),
                    subfolder: _subC.text.trim().isEmpty ? null : _subC.text.trim(),
                    minQty: int.tryParse(_minC.text.trim()) ?? 0,
                    qty: int.tryParse(_qtyC.text.trim()) ?? 0,
                  );
                  await repo.upsertItem(item);
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: Text(context.t.btn_add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
