import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';

class AdjustForm extends StatefulWidget {
  final Item item;
  const AdjustForm({super.key, required this.item});

  @override
  State<AdjustForm> createState() => _AdjustFormState();
}

class _AdjustFormState extends State<AdjustForm> {
  final _deltaC = TextEditingController(text: '1');
  final _noteC = TextEditingController();

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
            children: [
              Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('현재 수량: ${widget.item.qty} (min ${widget.item.minQty})'),
              const SizedBox(height: 12),
              TextField(controller: _deltaC, decoration: const InputDecoration(labelText: '변경 수량 (+입고 / -출고)'), keyboardType: TextInputType.number),
              TextField(controller: _noteC, decoration: const InputDecoration(labelText: '메모(선택)')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final delta = int.tryParse(_deltaC.text.trim()) ?? 0;
                  await repo.adjustQty(itemId: widget.item.id, delta: delta, refType: 'MANUAL', note: _noteC.text.trim());
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('적용'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
