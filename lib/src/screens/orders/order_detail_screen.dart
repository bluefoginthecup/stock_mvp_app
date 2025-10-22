import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import 'order_form_screen.dart';
import '../../utils/item_presentation.dart';

// ⛳ 개별 품목 부족분 모달 (정적 show 사용)
import '../bom/shortage_result_screen.dart';
// ⛳ 전체 주문 품목 부족분 결과 화면
import '../bom/order_shortage_result_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _reload(); // 진입 시 최신화(옵션)
  }

  Future<void> _reload() async {
    final orderRepo = context.read<OrderRepo>();
    // 프로젝트에서 sync면 await 제거
    final latest = await orderRepo.getOrder(_order.id);
    if (!mounted) return;
    if (latest == null) return;
    setState(() => _order = latest);
  }

  Future<void> _goEdit() async {
    final editedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(orderId: _order.id),
      ),
    );
    // 편집 화면에서 저장 시 pop(context, orderId)로 반환한다고 가정
    if (editedId != null && editedId.isNotEmpty) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLines = _order.lines.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '편집',
            onPressed: _goEdit,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // ✅ 항상 하나의 위젯을 반환 → body_might_complete_normally 방지
        child: hasLines ? _buildOrderWithLines(context) : _buildOrderEmpty(context),
      ),
    );
  }

  /// 라인이 있는 경우 UI
  Widget _buildOrderWithLines(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 주문 메타
        Text('고객명: ${_order.customer}'),
        Text('주문일: ${_order.date.toIso8601String().split("T").first}'),
        Text('상태: ${_order.status.name}'),
        const SizedBox(height: 12),

        // ✅ 모든 주문 라인 표시
        Expanded(
          child: ListView.separated(
            itemCount: _order.lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final line = _order.lines[index]; // itemId, qty 사용(필드명은 프로젝트 모델에 맞게)
              return _buildLineCard(context, line.itemId, line.qty);
            },
          ),
        ),

        const SizedBox(height: 16),
        // 전체 품목에 대해 한 번에 계산
        ElevatedButton.icon(
          icon: const Icon(Icons.assessment),
          label: const Text('전체 품목 부족분 계산'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderShortageResultScreen(order: _order),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '각 품목 카드를 눌러 개별 부족분을 보거나, 전체 버튼으로 한 번에 계산할 수 있어요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  /// 라인이 없는 경우 UI
  Widget _buildOrderEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('고객명: ${_order.customer}'),
        Text('주문일: ${_order.date.toIso8601String().split("T").first}'),
        Text('상태: ${_order.status.name}'),
        const SizedBox(height: 12),
        const Expanded(
          child: Center(child: Text('(주문 라인이 없습니다)')),
        ),
      ],
    );
  }

  /// 개별 라인 카드
  Widget _buildLineCard(BuildContext context, String itemId, int qty) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목영역
            Row(
              children: [
                Expanded(
                  child: ItemLabel(
                    itemId: itemId,
                    full: false,                  // 전체 경로까지 표시 (원하면 false)
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '수량 $qty',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.blueGrey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 액션
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calculate),
                  label: const Text('이 품목 부족분'),
                  onPressed: () {
                    // ✅ ShortageResultScreen.show(...) 사용 (이름있는 파라미터 정확)
                    ShortageResultScreen.show(
                      context,
                      finishedItemId: itemId,
                      orderQty: qty,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
