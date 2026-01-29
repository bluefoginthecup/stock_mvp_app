
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import '../../services/inventory_service.dart';
import '../../ui/common/ui.dart';
import '../../utils/item_presentation.dart';

import '../../ui/common/delete_more_menu.dart';

// ⬇️ l10n
import '../../l10n/l10n.dart';
class WorkDetailScreen extends StatefulWidget {
    final Work work;
    const WorkDetailScreen({super.key, required this.work});

    @override
    State<WorkDetailScreen> createState() => _WorkDetailScreenState();
  }

class _WorkDetailScreenState extends State<WorkDetailScreen> {
    late final ScrollController _scrollCtrl = ScrollController();
    Work get work => widget.work;

    @override
    void dispose() {
      _scrollCtrl.dispose();
      super.dispose();
    }

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
    final canChange = w.status != WorkStatus.canceled;

    return Scaffold(
      appBar: AppBar(title: Text(context.t.work_detail_title),
          actions: [
                  if (work.id.isNotEmpty)
                    DeleteMoreMenu<Work>(
                          entity: work,
                          onChanged: () {
                  // 삭제/취소 후 상세화면에서 목록으로 복귀
                  Navigator.maybePop(context);
                },
                  ),
          ],),
      body: FutureBuilder<(String, String?)>(
        future: _loadNames(context),
        builder: (ctx, snap) {
          final itemName = snap.data?.$1 ?? context.t.work_row_item_fallback(shortId(w.itemId));
          final customer = snap.data?.$2;

          // 날짜 포맷(로케일 반영)
          final locale = Localizations.localeOf(context).toString();
          final createdAtText = (w.createdAt != null)
              ? DateFormat.yMMMd(locale).add_Hms().format(w.createdAt)
              : null;

          return Scrollbar(
                          controller: _scrollCtrl,
                          thumbVisibility: true, // ← 이 옵션을 쓴다면 controller 필수
                          child: SingleChildScrollView(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(16),
                        child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // ✅ 스크롤뷰 안에서는 shrink-wrap
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // 🧭 제목 라인: [루앙] 50기본형 방석커버 ×10  (옵션②)
                       Row(
                         children: [
                           Expanded(
                             child: ItemLabel(
                               itemId: w.itemId,
                                   full: false, // [루앙] 50기본형…  (full: true 로 바꾸면 전체 브레드크럼)
                                 ),
                             ),
                           const SizedBox(width: 8),
                           Text('×${w.qty}', style: const TextStyle(fontWeight: FontWeight.w600)),
                         ],
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
          // 상태: 3분할 버튼 (시작 / 진행중 / 완료)
                              Row(
                                children: [
                                  Text(context.t.field_status_label),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: [
                                        _statusButton(
                                          context: context,
                                          label: '시작',
                                          color: Colors.green,
                                          active: w.status == WorkStatus.planned,
                                          enabled: canChange,
                                          onTapConfirm: () async {
                                            if (w.status == WorkStatus.planned) return;
                                            final ok = await _confirm(context);
                                            if (ok != true) return;
                                            await inv.setWorkStatus(w.id, WorkStatus.planned);
                                            if (context.mounted) Navigator.pop(context);
                                          },
                                        ),
                                        _statusButton(
                                          context: context,
                                          label: '진행중',
                                          color: Colors.blue,
                                          active: w.status == WorkStatus.inProgress,
                                          enabled: canChange,
                                          onTapConfirm: () async {
                                            if (w.status == WorkStatus.inProgress) return;
                                            final ok = await _confirm(context);
                                            if (ok != true) return;
                                            await inv.setWorkStatus(w.id, WorkStatus.inProgress);
                                            if (context.mounted) Navigator.pop(context);
                                          },
                                        ),
                                        _statusButton(
                                          context: context,
                                          label: '완료',
                                          color: Colors.red,
                                          active: w.status == WorkStatus.done,
                                          enabled: canChange,
                                          onTapConfirm: () async {
                                            if (w.status == WorkStatus.done) return;
                                            final ok = await _confirm(context);
                                            if (ok != true) return;
                                            await inv.setWorkStatus(w.id, WorkStatus.done);
                                            if (context.mounted) Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                    const SizedBox(height: 6),

                    if (createdAtText != null)
                      _kv(context.t.label_created_at, createdAtText),

                    const SizedBox(height: 16),


                  ],
                ),
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

  // ✅ 상태 버튼 공통 위젯: 활성(채움) / 비활성(외곽) + 색상
    Widget _statusButton({
      required BuildContext context,
      required String label,
      required Color color,
      required bool active,
      required bool enabled,
      required Future<void> Function() onTapConfirm,
    }) {
    final btn = active
        ? ElevatedButton(
            onPressed: enabled ? () async {} : null, // 활성 상태는 눌러도 아무것도 안함
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: enabled
                ? () async {
                    await onTapConfirm();
                  }
                : null,
            child: Text(label),
          );
    return SizedBox(height: 40, child: btn);
  }

  // ✅ 변경 확인 모달
  Future<bool?> _confirm(BuildContext context) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('상태 변경'),
          content: const Text('상태를 변경하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
          ],
        ),
      );
    }

}
