import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/inmem_repo.dart';

class StockItemEditSheet extends StatefulWidget {
  final String itemId;
  const StockItemEditSheet({super.key, required this.itemId});

  @override
  State<StockItemEditSheet> createState() => _StockItemEditSheetState();
}

class _StockItemEditSheetState extends State<StockItemEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameC;
  late final TextEditingController _minQtyC;

  @override
  void initState() {
    super.initState();
    final repo = context.read<InMemoryRepo>();
    final it = repo.getItemById(widget.itemId)!;
    _displayNameC = TextEditingController(text: it.displayName?.trim().isNotEmpty == true ? it.displayName : it.name);
    _minQtyC = TextEditingController(text: it.minQty.toString());
  }

  @override
  void dispose() {
    _displayNameC.dispose();
    _minQtyC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit),
                    const SizedBox(width: 8),
                    Text('간단 편집', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _displayNameC,
                  decoration: const InputDecoration(labelText: '표시 이름 (displayName)'),
                  maxLength: 80,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _minQtyC,
                  decoration: const InputDecoration(labelText: '임계치 (minQty)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null) return '숫자를 입력하세요';
                    if (n < 0) return '0 이상 입력';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('저장'),
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final repo = context.read<InMemoryRepo>();
                    final it = repo.getItemById(widget.itemId)!;

                    final displayName = _displayNameC.text.trim();
                    final minQty = int.tryParse(_minQtyC.text.trim());

                    // InMemoryRepo에 부분 업데이트 메서드가 없으면 추가 필요
                    repo.updateItemMeta(
                      id: it.id,
                      displayName: displayName.isEmpty ? null : displayName,
                      minQty: minQty,
                    );

                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
