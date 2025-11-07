import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../ui/common/ui.dart';
import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/order_planning_service.dart';
import '../../providers/cart_manager.dart'; // CartManager 경로에 맞게
import 'order_form_screen.dart';

Future<void> onCreateInternalOrderPressed(BuildContext context) async {
  final cart = context.read<CartManager>().items;
  if (cart.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('장바구니가 비어있어요')));
    return;
  }

  // 1) 아이템별 수량 합산(동일 품목 여러 번 담긴 경우 대비)
  final grouped = <String, num>{};
  for (final c in cart) {
    grouped[c.itemId] = (grouped[c.itemId] ?? 0) + (c.qty);
  }

  // 2) 주문 객체 생성(draft)
  final orderId = 'ord_${const Uuid().v4()}';
  final lines = grouped.entries.map((e) {
    final lineId = const Uuid().v4();
    // OrderLine.qty가 정수라면 반올림/올림 정책 택1 (여기서는 반올림)
    final intQty = (e.value is int) ? (e.value as int) : (e.value.toDouble().round());
    return OrderLine(id: lineId, itemId: e.key, qty: intQty);
  }).toList();

  final order = Order(
    id: orderId,
    date: DateTime.now(),
    customer: '재고보충', // 재고 보충용임을 구분
    memo: '장바구니에서 생성',
    status: OrderStatus.draft,
    lines: lines,
  );

  final orderRepo = context.read<OrderRepo>();
  await orderRepo.upsertOrder(order);


  // ─────────────────────────────────────────────
  // 옵션 B) 생성된 주문 편집 화면으로 이동해서 확인 후 저장하고 싶다면:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OrderFormScreen(orderId: orderId, createIfMissing: false),
    ),
  );
  // ─────────────────────────────────────────────
}
