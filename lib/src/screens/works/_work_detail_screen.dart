
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
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
  final workRepo = context.read<WorkRepo>(); // ✅
  final workId = widget.work.id;

  return Scaffold(
    appBar: AppBar(
      title: Text(context.t.work_detail_title),
      actions: [
        if (workId.isNotEmpty)
          DeleteMoreMenu<Work>(
            entity: widget.work, // 여기 엔티티는 일단 유지 (삭제 메뉴용)
            onChanged: () => Navigator.maybePop(context),
          ),
      ],
    ),

    body: StreamBuilder<List<Work>>(
      stream: workRepo.watchAllWorks(), // ✅ 간단히 전체 watch 후 id로 찾기
      builder: (context, snapWorks) {
    final list = snapWorks.data ?? const <Work>[];
    final w = list.firstWhere(
    (x) => x.id == workId,
    orElse: () => widget.work,
    );

    final canChange = w.status != WorkStatus.canceled;

    return FutureBuilder<(String, String?)>(
    future: _loadNames(context), // item/orderId는 동일하니 일단 유지
    builder: (ctx, snap) {
    final itemName =
    snap.data?.$1 ?? context.t.work_row_item_fallback(shortId(w.itemId));
    final customer = snap.data?.$2;

    final locale = Localizations.localeOf(context).toString();
    final createdAtText = DateFormat.yMMMd(locale).add_Hms().format(w.createdAt);

    // ✅ 진행 표시
    final remaining = math.max(0, w.qty - w.doneQty);

    return Scrollbar(
    controller: _scrollCtrl,
    thumbVisibility: true,
    child: SingleChildScrollView(
    controller: _scrollCtrl,
    padding: const EdgeInsets.all(16),
    child: Card(
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    Expanded(child: ItemLabel(itemId: w.itemId, full: false)),
    const SizedBox(width: 8),
    Text('×${w.qty}', style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
    ),
    const SizedBox(height: 12),

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

    // ✅ 추가: 진행(완료/남은) 표시
    _kv('진행', '${w.doneQty} / ${w.qty} (남은 ${remaining})'),
    const SizedBox(height: 12),

    // ✅ 추가: 부분완료 버튼
    Row(
    children: [
    Expanded(
    child: FilledButton(
    onPressed: canChange
    ? () => _showPartialCompleteDialog(context, inv, w)
        : null,
    child: const Text('부분 완료'),
    ),
    ),
    const SizedBox(width: 8),
    Expanded(
    child: OutlinedButton(
    onPressed: (canChange && remaining > 0)
    ? () => inv.completeWork(w.id)
        : null,
    child: const Text('전량 완료'),
    ),
    ),
    ],
    ),

    const SizedBox(height: 16),

    // 상태 버튼들 (기존 그대로)
    Row(
    children: [
    Text(context.t.field_status_label),
    const SizedBox(width: 8),
    Expanded(
    child: Wrap(
    spacing: 8,
    runSpacing: 8,
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
    );
    }));
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

    Future<void> _showPartialCompleteDialog(
    BuildContext context,
    InventoryService inv,
    Work w,
    ) async {
    final remaining = w.qty - w.doneQty;

    final controller = TextEditingController(
    text: (remaining > 0 ? remaining : 1).toString(),
    );

    final madeQty = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
    title: const Text('부분 완료'),
    content: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text('완료 수량을 입력하세요. (남은 수량: ${remaining > 0 ? remaining : 0})'),
    const SizedBox(height: 8),
    TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(hintText: '예: 15'),
    ),
    const SizedBox(height: 8),
    const Text('※ 계획 초과 생산도 누적됩니다.'),
    ],
    ),
    actions: [
    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
    FilledButton(
    onPressed: () {
    final v = int.tryParse(controller.text.trim()) ?? 0;
    Navigator.pop(ctx, v);
    },
    child: const Text('완료 처리'),
    ),
    ],
    ),
    );

    if (madeQty == null || madeQty <= 0) return;

    await inv.completeWorkPartial(workId: w.id, madeQty: madeQty);
    }

  }
