import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../bom/shortage_test_screen.dart';
import 'order_form_screen.dart';

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
      _reload(); // 진입 시 한 번 최신화(옵션)
    }

    Future<void> _reload() async {
      final orderRepo = context.read<OrderRepo>();
      // ❗️네 프로젝트의 실제 시그니처가 sync면 await 제거
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
      // 편집 화면에서 저장 시 pop(context, orderId) 로 반환함
      if (editedId != null && editedId.isNotEmpty) {
        await _reload();
      }
    }

    @override
    Widget build(BuildContext context) {
      final repo = context.read<ItemRepo>();
      // ✅ 상세 본문에서 사용하던 로컬 변수 재정의 (이전 'order' 기반 사용 지우기)
          final hasLines = _order.lines.isNotEmpty;
          final firstLine = hasLines ? _order.lines.first : null;
          final finishedId = firstLine?.itemId;
          final qty = firstLine?.qty ?? 0;
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
        body:
        Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('고객명: ${_order.customer}'),
            Text('주문일: ${_order.date.toIso8601String().split("T").first}'),
            Text('상태: ${_order.status.name}'),
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
