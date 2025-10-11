// lib/src/services/order_planning_service.dart
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/work.dart';
import '../models/purchase.dart';
import '../repos/repo_interfaces.dart';
import '../models/types.dart';
import 'package:uuid/uuid.dart';

class OrderPlanningService {
  final ItemRepo items;
  final OrderRepo orders;
  final WorkRepo works;
  final PurchaseRepo purchases;
  final TxnRepo txns;
  final _uuid = const Uuid();

  OrderPlanningService({
    required this.items,
    required this.orders,
    required this.works,
    required this.purchases,
    required this.txns,
  });


  /// 주문 저장 → 품목별 부족분 계산 → Work 또는 Purchase 생성 → 예정 입고 Txn 기록
  Future<void> saveOrderAndAutoPlanShortage(
      Order order, {
        bool preferWork = true,
      }) async {
    await orders.upsertOrder(order);

    for (final ln in order.lines) {
      final it = await items.getItem(ln.itemId);
      if (it == null) continue;

      final available = it.qty; // 예약 수량이 있으면 반영하도록 개선 가능
      final short = ln.qty - available;
      if (short <= 0) continue;

      if (preferWork) {
        final wid = _uuid.v4();
        final w = Work(
          id: wid,
          itemId: ln.itemId,
          qty: short,
          orderId: order.id,
          status: WorkStatus.planned,
          createdAt: DateTime.now(),
          updatedAt: null,
        );
        await works.createWork(w);
        await txns.addInPlanned(
          itemId: ln.itemId,
          qty: short,
          refType: 'work',
          refId: wid,
          note: '예정입고 (order:${order.id})',
        );
      } else {
        final pid = _uuid.v4();
        final p = Purchase(
          id: pid,
          itemId: ln.itemId,
          qty: short,
          orderId: order.id,
          status: PurchaseStatus.planned,
          createdAt: DateTime.now(),
          updatedAt: null,
          vendorId: null,
          note: 'Auto from Order:${order.id}',
        );
        await purchases.createPurchase(p);
        await txns.addInPlanned(
          itemId: ln.itemId,
          qty: short,
          refType: 'purchase',
          refId: pid,
          note: '예정입고 (order:${order.id})',
        );
      }
    }
    if (kDebugMode) {
      print('[OrderPlanning] saved order ${order.id} & planned shortages.');
    }
  }
}
