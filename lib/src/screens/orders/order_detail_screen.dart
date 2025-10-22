import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../bom/shortage_test_screen.dart';
import 'order_form_screen.dart';
import '../bom/shortage_result_screen.dart';


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
            // (변경) 실제 부족분 결과 모달로 표시
                        ElevatedButton.icon(
                    icon: const Icon(Icons.calculate),
                    label: const Text('부족분 계산'),
                    onPressed: () async {
                      // 👉 주문 라인에서 대상 완제품 id/수량을 가져온다.
                      //    실제 필드명은 프로젝트의 Order/OrderLine 정의에 맞게 바꿔주세요.
                      //    예시: order.lines.first.finishedItemId / order.lines.first.qty
                      final order = widget.order;
                      if (order.lines.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('주문 품목이 없습니다.')),
                        );
                        return;
                      }
                      final line = order.lines.first; // TODO: 여러 라인 선택 UI로 확장 가능
                      final finishedId = line.itemId; // 또는 line.finishedItemId
                      final qty = line.qty;

                      await ShortageResultScreen.show(
                        context,
                        finishedItemId: finishedId,
                        orderQty: qty,
                      );
                    },
                  ),
            const SizedBox(height: 12),
      // 안내 문구 교체
                  Text(
                    '현재 선택한 주문 품목 기준으로 세미/원자재/부자재 필요·부족을 계산해 보여줍니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
          ],
        ),
      ),
    );
  }
}
