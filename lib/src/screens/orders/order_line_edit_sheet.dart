import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart';
import '../../ui/common/item_picker_sheet.dart'; // 네가 만든 파일 경로에 맞춰
import '../../utils/item_presentation.dart';



class OrderLineEditSheet extends StatefulWidget {
  final String orderId;
  final String lineId;
  final String itemId;
  final int qty;

  const OrderLineEditSheet({
    super.key,
    required this.orderId,
    required this.lineId,
    required this.itemId,
    required this.qty,
  });

  @override
  State<OrderLineEditSheet> createState() => _OrderLineEditSheetState();
}

class _OrderLineEditSheetState extends State<OrderLineEditSheet> {
  late final TextEditingController _qtyController;
  late String _selectedItemId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.qty.toString());
    _selectedItemId = widget.itemId;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final orderRepo = context.read<OrderRepo>();
    final workRepo = context.read<WorkRepo>();

    try {
      final newQty = int.tryParse(_qtyController.text.trim()) ?? widget.qty;
      if (newQty <= 0) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('수량 오류'),
            content: const Text('수량은 1 이상이어야 합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }

      final order = await orderRepo.getOrder(widget.orderId);
      if (order == null) {
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final lineIndex = order.lines.indexWhere((l) => l.id == widget.lineId);
      if (lineIndex < 0) {
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final oldLine = order.lines[lineIndex];

      // ✅ 아이템 변경 정책: 해당 라인(기존 itemId)에 연결된 work 중 doneQty>0 있으면 변경 불가
      if (_selectedItemId != oldLine.itemId) {
        final works = await workRepo.findWorksByOrderAndItem(
          widget.orderId,
          oldLine.itemId,
        );

        final hasProgress = works.any((w) => w.doneQty > 0);
        if (hasProgress) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('아이템 변경 불가'),
              content: const Text('이미 일부 생산된 작업이 있어 아이템을 변경할 수 없습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          return;
        }

        // 🔹 진행 0이면 work들의 itemId도 같이 변경(정책적으로 원한다면)
        for (final w in works) {
          await workRepo.updateWorkItem(w.id, _selectedItemId);
        }
      }

      // ✅ 주문 라인 업데이트 (qty + itemId)
      final newLines = [...order.lines];
      newLines[lineIndex] = oldLine.copyWith(
        itemId: _selectedItemId,
        qty: newQty,
      );
      await orderRepo.upsertOrder(
        order.copyWith(lines: newLines).touch(),
      );

      if (!mounted) return;
      Navigator.pop(context, true); // ✅ 저장 성공 표시


    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '수량',
              ),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('아이템', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      // 사람 읽는 라벨로 보여주고 싶으면 ItemLabel로 교체 가능
                      ItemLabel(
                        itemId: _selectedItemId,
                        full: false,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                    final picked = await showItemPickerSheet(
                      context,
                      initialItemId: _selectedItemId,
                      title: '아이템 선택',
                    );
                    if (picked != null && mounted) {
                      setState(() => _selectedItemId = picked);
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('변경'),
                ),
              ],
            ),


            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중...' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
