import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../../ui/common/ui.dart';
import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/cart_item.dart';
import 'order_form_screen.dart';

/// ✅ 선택 항목으로 내부주문 생성 (재고보충)
Future<void> createInternalOrderFromPicked(
    BuildContext context, {
      required List<CartItem> picked,
      VoidCallback? onAfterSaved, // ✅ 추가
    }) async {
  if (picked.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('선택된 항목이 없어요')));
    return;
  }

  // 1) itemId별 수량 합산
  final grouped = <String, num>{};
  for (final c in picked) {
    grouped[c.itemId] = (grouped[c.itemId] ?? 0) + (c.qty);
  }

  // 2) 주문(draft) 생성
  final orderId = 'ord_${const Uuid().v4()}';
  final lines = grouped.entries.map((e) {
    final lineId = const Uuid().v4();
    final intQty = e.value.toDouble().round();
    return OrderLine(id: lineId, itemId: e.key, qty: intQty);
  }).toList();

  final order = Order(
    id: orderId,
    date: DateTime.now(),
    customer: '재고보충',
    memo: '장바구니(선택)에서 생성',
    status: OrderStatus.draft,
    lines: lines,
  );

  final orderRepo = context.read<OrderRepo>();
  await orderRepo.upsertOrder(order);

  // 편집 화면으로 이동 (저장 후 savedOrderId를 돌려받는 구조)
  final savedOrderId = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => OrderFormScreen(orderId: orderId, createIfMissing: false),
    ),
  );

  if (!context.mounted || savedOrderId == null) return;

  // ✅ 여기서 장바구니 제거 트리거
  onAfterSaved?.call();

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: const Text('저장 + 부족분 자동 계획 생성 완료'),
        action: SnackBarAction(
          label: '주문상세 보기',
          onPressed: () {
            Navigator.of(context).pushNamed(
              '/orders/detail',
              arguments: savedOrderId,
            );
          },
        ),
      ),
    );
}

