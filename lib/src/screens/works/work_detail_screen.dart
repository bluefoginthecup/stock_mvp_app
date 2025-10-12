import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import '../../services/inventory_service.dart';
import '../../ui/ui_utils.dart';
import '../../ui/common/ui.dart';

// ⬇️ l10n
import '../../l10n/l10n.dart';
import '../../l10n/l10n_x.dart';
import '../../l10n/labels.dart'; // 상태 라벨용

class WorkDetailScreen extends StatelessWidget {
  final Work work;
  const WorkDetailScreen({super.key, required this.work});

  // 아이템명, 주문자명 로드
  Future<(String /*itemName*/, String? /*customer*/)> _loadNames(BuildContext ctx) async {
    final itemRepo  = ctx.read<ItemRepo?>();
    final orderRepo = ctx.read<OrderRepo?>();

    String itemName = '';
    String? customer;

    try {
      if (itemRepo != null) {
        final n = await itemRepo.nameOf(work.itemId);
        final nt = n?.trim();
        if (nt != null && nt.isNotEmpty) itemName = nt;
      }
    } catch (_) {}

    if (work.orderId != null && orderRepo != null) {
      try {
        final r = await orderRepo.customerNameOf(work.orderId!);
        final rt = r?.trim();
        if (rt != null && rt.isNotEmpty) customer = rt;
      } catch (_) {}
    }

    if (itemName.isEmpty) {
      // 폴백도 다국어
      itemName = L10n.of(ctx).work_row_item_fallback(shortId(work.itemId));
    }
    return (itemName, customer);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.read<InventoryService>();
    final w = work;
    final canAdvance = w.status != WorkStatus.done && w.status != WorkStatus.canceled;

    return Scaffold(
      appBar: AppBar(title: Text(context.t.work_detail_title)),
      body: FutureBuilder<(String, String?)>(
        future: _loadNames(context),
        builder: (ctx, snap) {
          final itemName = snap.data?.$1 ?? context.t.work_row_item_fallback(shortId(w.itemId));
          final customer = snap.data?.$2;

          // 날짜 포맷(로케일 반영)
          final locale = Localizations.localeOf(context).toString();
          final createdAtText = (w.createdAt != null)
              ? DateFormat.yMMMd(locale).add_Hms().format(w.createdAt!)
              : null;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목: 사람이 읽을 이름 + 수량
                    Text(
                      context.t.work_detail_item_qty(itemName, w.qty),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),

                    // 메타 정보
                    if (customer != null) ...[
                      _kv(context.t.label_customer, customer),
                      const SizedBox(height: 6),
                    ],
                    if (w.orderId != null) ...[
                      _kv(context.t.label_order_no, shortId(w.orderId!)),
                      const SizedBox(height: 6),
                    ],
                    _kv(context.t.label_item_id, shortId(w.itemId)),
                    const SizedBox(height: 6),

                    // 상태
                    _statusRow(context, Labels.workStatus(context, w.status)),
                    const SizedBox(height: 6),

                    if (createdAtText != null)
                      _kv(context.t.label_created_at, createdAtText),

                    const Spacer(),

                    // 액션 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !canAdvance
                            ? null
                            : () async {
                          if (w.status == WorkStatus.planned) {
                            await inv.startWork(w.id);      // planned → inProgress
                          } else if (w.status == WorkStatus.inProgress) {
                            await inv.completeWork(w.id);   // inProgress → done
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          switch (w.status) {
                            WorkStatus.planned    => context.t.work_btn_start,
                            WorkStatus.inProgress => context.t.work_btn_complete,
                            WorkStatus.done       => context.t.work_btn_already_done,
                            WorkStatus.canceled   => context.t.work_btn_canceled,
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Key–Value 한 줄
  Widget _kv(String k, String v) => RichText(
    text: TextSpan(
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      children: [
        TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: v),
      ],
    ),
  );

  // 상태 라인
  Widget _statusRow(BuildContext context, String label) => Row(
    children: [
      Text(context.t.field_status_label),
      const SizedBox(width: 4),
      Chip(label: Text(label)),
    ],
  );
}
