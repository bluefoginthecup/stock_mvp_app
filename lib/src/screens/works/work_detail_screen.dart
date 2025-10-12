import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import '../../services/inventory_service.dart';
import '../../ui/ui_utils.dart'; // shortId 사용

class WorkDetailScreen extends StatelessWidget {
  final Work work;
  const WorkDetailScreen({super.key, required this.work});

  String _statusLabel(WorkStatus s) {
    switch (s) {
      case WorkStatus.planned:    return '작업 대기';
      case WorkStatus.inProgress: return '진행중';
      case WorkStatus.done:       return '완료';
      case WorkStatus.canceled:   return '취소';
    }
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

    if (itemName.isEmpty) itemName = '아이템 ${shortId(work.itemId)}';
    return (itemName, customer);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.read<InventoryService>(); // ✅ 전이/재고 반영은 여기로
    final w = work;
    final canAdvance = w.status != WorkStatus.done && w.status != WorkStatus.canceled;

    return Scaffold(
      appBar: AppBar(title: const Text('작업 상세')),
      body: FutureBuilder<(String, String?)>(
        future: _loadNames(context),
        builder: (ctx, snap) {
          final itemName = snap.data?.$1 ?? '아이템 ${shortId(w.itemId)}';
          final customer = snap.data?.$2;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목: 사람이 읽을 이름 + 수량
                    Text('$itemName  x${w.qty}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),

                    // 메타 정보
                    if (customer != null) ...[
                      _kv('주문자', customer),
                      const SizedBox(height: 6),
                    ],
                    if (w.orderId != null) ...[
                      _kv('주문번호', shortId(w.orderId!)),
                      const SizedBox(height: 6),
                    ],
                    _kv('아이템ID', shortId(w.itemId)),
                    const SizedBox(height: 6),
                    _statusRow(_statusLabel(w.status)),
                    const SizedBox(height: 6),
                    if (w.createdAt != null)
                      _kv('생성일', w.createdAt!.toString().split('.').first),

                    const Spacer(),

                    // 액션 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !canAdvance
                            ? null
                            : () async {
                          if (w.status == WorkStatus.planned) {
                            // planned → inProgress (planned 입고 예약 포함)
                            await inv.startWork(w.id);
                          } else if (w.status == WorkStatus.inProgress) {
                            // inProgress → done (actual 입고 + 완료)
                            await inv.completeWork(w.id);
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          switch (w.status) {
                            WorkStatus.planned    => '작업 시작 (inProgress)',
                            WorkStatus.inProgress => '완료 처리 (done)',
                            WorkStatus.done       => '이미 완료됨',
                            WorkStatus.canceled   => '취소됨',

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

  // 상태 뱃지
  Widget _statusRow(String label) => Row(
    children: [
      const Text('상태: '),
      Chip(label: Text(label)),
    ],
  );
}
