
import 'package:uuid/uuid.dart';

import '../../models/purchase_line.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';


class PurchaseLineFullEditScreen extends StatefulWidget {
  final PurchaseOrderRepo repo;
  final String orderId;
  final PurchaseLine? initial;

  const PurchaseLineFullEditScreen({
    super.key,
    required this.repo,
    required this.orderId,
    this.initial,
  });

  @override
  State<PurchaseLineFullEditScreen> createState() => _PurchaseLineFullEditScreenState();
}

class _PurchaseLineFullEditScreenState extends State<PurchaseLineFullEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  late final TextEditingController itemIdC;
  late final TextEditingController nameC;
  late final TextEditingController unitC;
  late final TextEditingController qtyC;
  late final TextEditingController colorNoC;
  late final TextEditingController noteC;
  late final TextEditingController memoC;

  late final bool isEdit;
  late final String lineId;

  @override
  void initState() {
    super.initState();
    isEdit = widget.initial != null;
    lineId = widget.initial?.id ?? const Uuid().v4();

    final i = widget.initial;
    itemIdC  = TextEditingController(text: i?.itemId ?? '');
    nameC    = TextEditingController(text: i?.name ?? '');
    unitC    = TextEditingController(text: i?.unit ?? 'EA');
    qtyC     = TextEditingController(text: (i?.qty ?? 1).toString());
    colorNoC = TextEditingController(text: i?.colorNo ?? '');
    noteC    = TextEditingController(text: i?.note ?? '');
    memoC    = TextEditingController(text: i?.memo ?? '');
  }

  @override
  void dispose() {
    itemIdC.dispose();
    nameC.dispose();
    unitC.dispose();
    qtyC.dispose();
    colorNoC.dispose();
    noteC.dispose();
    memoC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final qty = double.tryParse(qtyC.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수량은 0보다 큰 숫자여야 합니다')));
      return;
    }

    final newLine = PurchaseLine(
      id: lineId,
      orderId: widget.orderId,
      itemId: itemIdC.text.trim(),
      name: nameC.text.trim(),
      unit: (unitC.text.trim().isEmpty) ? 'EA' : unitC.text.trim(),
      qty: qty,
      colorNo: colorNoC.text.trim().isEmpty ? null : colorNoC.text.trim(),
      note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
      memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),
    );

    final lines = await widget.repo.getLines(widget.orderId);
    final idx = lines.indexWhere((e) => e.id == newLine.id);
    if (idx >= 0) {
      lines[idx] = newLine;
    } else {
      lines.add(newLine);
    }
    await widget.repo.upsertLines(widget.orderId, lines);
    if (!mounted) return;
    Navigator.pop(context, newLine);
  }

  Future<void> _delete() async {
    if (!isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.t.common_delete),
        content: Text('${nameC.text.trim().isNotEmpty ? nameC.text.trim() : itemIdC.text.trim()} 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t.common_cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.t.common_delete)),
        ],
      ),
    );
    if (ok != true) return;

    final lines = await widget.repo.getLines(widget.orderId);
    final next = lines.where((e) => e.id != lineId).toList();
    await widget.repo.upsertLines(widget.orderId, next);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '발주 라인 편집' : '발주 라인 추가'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: '저장',
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('필수', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: itemIdC,
                decoration: _dec('itemId', hint: '예: it_rouen_gray_cc_50'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'itemId를 입력하세요' : null,
              ),
              TextFormField(
                controller: nameC,
                decoration: _dec('name (표시명, 선택)'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: unitC,
                      decoration: _dec('unit', hint: 'EA/M/ROLL...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: qtyC,
                      decoration: _dec('qty'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '수량';
                        final d = double.tryParse(v);
                        if (d == null || d <= 0) return '0보다 큰 숫자';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text('옵션', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(controller: colorNoC, decoration: _dec('colorNo (선택)')),
              TextFormField(controller: noteC, decoration: _dec('note (선택)')),
              TextFormField(
                controller: memoC,
                decoration: _dec('memo (선택)'),
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(context.t.btn_save),
              ),
              const SizedBox(height: 8),
              if (isEdit)
                OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete),
                  label: Text(context.t.common_delete),
                ),
              const SizedBox(height: 16),
              Text('Line ID: $lineId', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
