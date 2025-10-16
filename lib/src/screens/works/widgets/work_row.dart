
import 'package:provider/provider.dart';

import '../../../models/work.dart';
import '../../../models/types.dart';
import '../../../repos/repo_interfaces.dart';
import '../../../ui/ui_utils.dart';
import '../../../ui/common/ui.dart';

// ⬇️ l10n 임포트 (context.t / L10n.of)
import '../../../l10n/l10n.dart';
// ⬇️ 상태라벨 변환 (없으면 아래 ARB 라벨로 직접 사용해도 됨)

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

    // ⬇️ 로컬라이즈드 폴백 (아이템 {shortId})
    if (itemName.isEmpty) {
      itemName = L10n.of(ctx).work_row_item_fallback(shortId(w.itemId));
    }
    return (itemName, customer);
  }

  Widget _statusBadge(BuildContext context, WorkStatus s) {
    // 라벨은 i18n으로 (Labels.*가 내부에서 L10n을 사용)
    final text = Labels.workStatus(context, s);
    switch (s) {
      case WorkStatus.planned:
        return badge(text, Colors.blueGrey);
      case WorkStatus.inProgress:
        return badge(text, Colors.blue, icon: Icons.play_arrow);
      case WorkStatus.done:
        return badge(text, Colors.green, icon: Icons.check);
      case WorkStatus.canceled:
        return badge(text, Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, String?)>(
      future: _loadNames(context),
      builder: (_, snap) {
        final itemName = snap.data?.$1 ?? context.t.work_row_item_fallback(shortId(w.itemId));
        final customer = snap.data?.$2;

        // 오른쪽 버튼 영역
        Widget? trailing;
        if (w.status == WorkStatus.planned && onStart != null) {
          trailing = OutlinedButton(onPressed: onStart, child: Text(context.t.work_action_start));
        } else if (w.status == WorkStatus.inProgress && onDone != null) {
          trailing = OutlinedButton(onPressed: onDone, child: Text(context.t.work_action_done));
        } else if (w.status == WorkStatus.done) {
          trailing = const Icon(Icons.check, color: Colors.green);
        }

        return ListTile(
          // "$itemName   x${w.qty}" → 플레이스홀더 키
          title: Text(
            context.t.work_row_item_qty(itemName, w.qty),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusBadge(context, w.status),
              if (w.orderId != null)
                Text(context.t.work_row_order_short(shortId(w.orderId!))),
              if (customer != null)
                Text(context.t.work_row_customer(customer)),
              Text(context.t.work_row_item_short(shortId(w.itemId))),
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
