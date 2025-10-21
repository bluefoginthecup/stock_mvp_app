import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../bom/shortage_test_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ItemRepo>();

    // ✅ 첫 번째 라인 기준으로 완제품/수량 가져오기
    final hasLines = order.lines.isNotEmpty;
    final finishedId = hasLines ? order.lines.first.itemId : '(라인 없음)';
    final qty = hasLines ? order.lines.first.qty : 0;

    return Scaffold(
      appBar: AppBar(title: Text('주문 상세 (${order.customer})')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('고객명: ${order.customer}'),
            Text('주문일: ${order.date.toIso8601String().split("T").first}'),
            Text('상태: ${order.status.name}'),
            const SizedBox(height: 12),
            if (hasLines) ...[
              Text('완제품 ID: $finishedId'),
              Text('수량: $qty개'),
            ] else
              const Text('(주문 라인이 없습니다)'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.calculate),
              label: const Text('부족 계산 보기'),
              onPressed: hasLines
                  ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ShortageTestScreen(),
                  ),
                );
              }
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              '※ 이 버튼은 BOM 기반 부족 계산 테스트용입니다.\n'
                  '   실제 연계는 order_planning_service.dart로 확장 가능.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
