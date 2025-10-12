import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/work.dart';
import '../../../models/types.dart';
import '../../../repos/repo_interfaces.dart';
import '../../../ui/ui_utils.dart';

class WorkRow extends StatelessWidget {
  final Work w;
  final VoidCallback? onStart;
  final VoidCallback? onDone;
  final VoidCallback? onTap;     // 상세 이동 (옵션)

  const WorkRow({
    super.key,
    required this.w,
    this.onStart,
    this.onDone,
    this.onTap,
  });

  Future<(String /*itemName*/, String? /*customer*/)> _loadNames(BuildContext ctx) async {
    final itemRepo  = ctx.read<ItemRepo?>();
    final orderRepo = ctx.read<OrderRepo?>();

    String itemName = '';
    String? customer;

    try {
      if (itemRepo != null) {
        final n  = await itemRepo.nameOf(w.itemId);
        final nt = n?.trim();
        if (nt != null && nt.isNotEmpty) itemName = nt;
      }
    } catch (_) {}

    if (w.orderId != null && orderRepo != null) {
      try {
        final r  = await orderRepo.customerNameOf(w.orderId!);
        final rt = r?.trim();
        if (rt != null && rt.isNotEmpty) customer = rt;
      } catch (_) {}
    }

    if (itemName.isEmpty) itemName = '아이템 ${shortId(w.itemId)}';
    return (itemName, customer);
  }

  Widget _statusBadge(WorkStatus s) {
    switch (s) {
      case WorkStatus.planned:
        return badge('planned', Colors.blueGrey);
      case WorkStatus.inProgress:
        return badge('진행중', Colors.blue, icon: Icons.play_arrow);
      case WorkStatus.done:
        return badge('완료', Colors.green, icon: Icons.check);
      case WorkStatus.canceled:
        return badge('취소', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, String?)>(
      future: _loadNames(context),
      builder: (_, snap) {
        final itemName = snap.data?.$1 ?? '아이템 ${shortId(w.itemId)}';
        final customer = snap.data?.$2;

        // 오른쪽 버튼 영역
        Widget? trailing;
        if (w.status == WorkStatus.planned && onStart != null) {
          trailing = OutlinedButton(onPressed: onStart, child: const Text('Start'));
        } else if (w.status == WorkStatus.inProgress && onDone != null) {
          trailing = OutlinedButton(onPressed: onDone, child: const Text('Done'));
        } else if (w.status == WorkStatus.done) {
          trailing = const Icon(Icons.check, color: Colors.green);
        }

        return ListTile(
          title: Text('$itemName   x${w.qty}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusBadge(w.status),
              if (w.orderId != null) Text('order ${shortId(w.orderId!)}'),
              if (customer != null) Text('주문자 $customer'),
              Text('item ${shortId(w.itemId)}'),
            ],
          ),
          trailing: trailing,
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: onTap,
        );
      },
    );
  }
}
