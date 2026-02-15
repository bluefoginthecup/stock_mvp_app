import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/work.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/inventory_service.dart';
import '../../ui/common/ui.dart'; // context.t 쓰는 경우(없으면 제거 가능)

class WorkEditSheet extends StatefulWidget {
  final String workId;

  const WorkEditSheet({
    super.key,
    required this.workId,
  });

  @override
  State<WorkEditSheet> createState() => _WorkEditSheetState();
}

class _WorkEditSheetState extends State<WorkEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _doneCtrl = TextEditingController();

  bool _init = false;
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _doneCtrl.dispose();
    super.dispose();
  }

  void _seedIfNeeded(Work w) {
    if (_init) return;
    _init = true;

    _qtyCtrl.text = w.qty.toString();
    _doneCtrl.text = w.doneQty.toString();
  }

  int? _parseInt(String s) => int.tryParse(s.trim());

  Future<void> _save(BuildContext context, Work w) async {
    if (_saving) return;

    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    final newQty = _parseInt(_qtyCtrl.text);
    final newDone = _parseInt(_doneCtrl.text);

    if (newQty == null || newDone == null) return;

    setState(() => _saving = true);
    try {
      await context.read<InventoryService>().editWork(
        workId: w.id,
        newQty: newQty == w.qty ? null : newQty,
        newDoneQty: newDone == w.doneQty ? null : newDone,
        newItemId: null, // ✅ 아이템 변경 기능 제거
      );

      if (!mounted) return;
      debugPrint(
        '[WorkEditSheet] SAVE tapped '
            'workId=${w.id} '
            'itemId=${w.itemId} '
            'oldQty=${w.qty} newQty=$newQty '
            'oldDone=${w.doneQty} newDone=$newDone '
            'orderId=${w.orderId}',
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<WorkRepo>();

    return StreamBuilder<Work?>(
      stream: repo.watchWorkById(widget.workId),
      builder: (context, snap) {
        final w = snap.data;
        if (w == null) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        _seedIfNeeded(w);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '작업 편집',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 폼
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 계획 수량(qty)
                      TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '계획 수량 (qty)',
                          hintText: '예: 10',
                        ),
                        validator: (v) {
                          final n = _parseInt(v ?? '');
                          if (n == null) return '숫자를 입력해 주세요';
                          if (n < 0) return '0 이상이어야 합니다';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 완료 수량(doneQty)
                      TextFormField(
                        controller: _doneCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '완료 수량 (doneQty)',
                          hintText: '예: 2',
                          helperText: '계획 수량을 초과해도 가능(합의된 정책)',
                        ),
                        validator: (v) {
                          final n = _parseInt(v ?? '');
                          if (n == null) return '숫자를 입력해 주세요';
                          if (n < 0) return '0 이상이어야 합니다';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(context, w),
                    icon: _saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save),
                    label: Text(_saving ? '저장 중…' : '저장'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
