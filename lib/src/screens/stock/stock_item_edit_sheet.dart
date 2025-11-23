import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';

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

  late Future<Item?> _itemFuture;
  Item? _loaded; // 저장 시 원본 보관

  @override
  void initState() {
    super.initState();
    _displayNameC = TextEditingController();
    _minQtyC = TextEditingController();

    final repo = context.read<ItemRepo>();
    _itemFuture = repo.getItemById(widget.itemId);
  }

  @override
  void dispose() {
    _displayNameC.dispose();
    _minQtyC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final item = _loaded;
    if (item == null) return;

    final repo = context.read<ItemRepo>();

    final displayName = _displayNameC.text.trim();
    final minQty = int.tryParse(_minQtyC.text.trim());

    // 변경된 필드만 덮고 나머지는 유지
    final updated = Item(
      id: item.id,
      name: item.name,
      displayName: displayName.isEmpty ? item.displayName : displayName,
      sku: item.sku,
      unit: item.unit,
      folder: item.folder,
      subfolder: item.subfolder,
      subsubfolder: item.subsubfolder,
      minQty: minQty ?? item.minQty,
      qty: item.qty, // 수량은 여기서 건드리지 않음(Adjust 권장)
      kind: item.kind,
      attrs: item.attrs,
      unitIn: item.unitIn,
      unitOut: item.unitOut,
      conversionRate: item.conversionRate,
      conversionMode: item.conversionMode,
      stockHints: item.stockHints,
      supplierName: item.supplierName,
      isFavorite: item.isFavorite,
    );

    await repo.updateItemMeta(updated);
    if (mounted) Navigator.pop(context, true);
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
          child: FutureBuilder<Item?>(
            future: _itemFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final it = snap.data;
              if (it == null) {
                // 아이템이 없으면 닫기
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) Navigator.pop(context);
                });
                return const SizedBox.shrink();
              }

              // 최초 한 번만 컨트롤러에 값 채우기
              if (_loaded == null) {
                _loaded = it;
                _displayNameC.text =
                (it.displayName?.trim().isNotEmpty == true) ? it.displayName! : it.name;
                _minQtyC.text = it.minQty.toString();
              }

              return Form(
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
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
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
                      onPressed: _save,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
