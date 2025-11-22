// lib/src/services/inventory_service.dart
import '../repos/repo_interfaces.dart';
import '../models/types.dart';
import '../models/state_guard.dart';
import '../models/purchase_order.dart';   // ✅ 추가: 상태(enum) 사용

class InventoryService {
  final WorkRepo works;
  final PurchaseOrderRepo purchases;   // ✅ PurchaseOrderRepo
  final TxnRepo txns;
  final BomRepo boms;                  // 선택: BOM 소비 planned/actual 쓰려면 사용
  final OrderRepo orders;

  InventoryService({
    required this.works,
    required this.purchases,
    required this.txns,
    required this.boms,
    required this.orders,
  });

  /// 주문 삭제 (소프트/하드 옵션)
  Future<void> deleteOrderCascade(String orderId, {bool hard = false}) async {
    if (hard) {
      await orders.hardDeleteOrder(orderId);
    } else {
      await orders.softDeleteOrder(orderId);
    }
  }

  // ---------- WORK ----------
  /// planned -> inProgress : 상태 전환 (예약 Txn은 현재 비활성)
  Future<void> startWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (!canTransitionWork(w.status, WorkStatus.inProgress)) return;

    // (필요 시 planned in/out 등록 로직 복구)

    await works.updateWorkStatus(workId, WorkStatus.inProgress);
  }

  /// inProgress -> done : actual in + 완료
  Future<void> completeWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (!canTransitionWork(w.status, WorkStatus.done)) return;

    await txns.addInActual(
      itemId: w.itemId,
      qty: w.qty,
      refType: 'work',
      refId: w.id,
      note: 'work actual in',
    );

    // (필요 시 BOM actual out 등록)

    await works.updateWorkStatus(workId, WorkStatus.done);
  }

  /// 취소
  Future<void> cancelWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (!canTransitionWork(w.status, WorkStatus.canceled)) return;

    // (필요 시 planned 롤백)
    await works.updateWorkStatus(workId, WorkStatus.canceled);
  }

  // ⚙️ 작업 삭제 (소프트/하드)
  Future<void> deleteWorkSafe(String workId, {bool hard = false}) async {
    if (hard) {
      await works.hardDeleteWork(workId);
    } else {
      await works.softDeleteWork(workId);
    }
  }

  // ---------- PURCHASE ORDER ----------
  /// draft -> ordered : 발주 라인 기준 planned in + 상태 전환
  Future<void> orderPurchase(String purchaseId) async {
    final po = await purchases.getPurchaseOrderById(purchaseId);
    if (po == null) return;

    // 간단 가드: draft 에서만 ordered 로
    if (po.status != PurchaseOrderStatus.draft) return;

    // 각 라인별 planned in
    final lines = await purchases.getLines(po.id);
    for (final line in lines) {
      // Txn.qty는 int이므로 반올림
      final intQty = (line.qty is int) ? line.qty as int : (line.qty).round();
      await txns.addInPlanned(
        itemId: line.itemId,
        qty: intQty,
        refType: 'purchase',
        refId: po.id,
        note: 'purchase planned in',
      );
    }

    await purchases.updatePurchaseOrderStatus(po.id, PurchaseOrderStatus.ordered);
  }

  /// ordered -> received : 발주 라인 기준 actual in + 상태 전환
  Future<void> receivePurchase(String purchaseId) async {
    final po = await purchases.getPurchaseOrderById(purchaseId);
    if (po == null) return;

    // 간단 가드: ordered 에서만 received 로
    if (po.status != PurchaseOrderStatus.ordered) return;

    // 각 라인별 actual in
    final lines = await purchases.getLines(po.id);
    for (final line in lines) {
      final intQty = (line.qty is int) ? line.qty as int : (line.qty).round();
      await txns.addInActual(
        itemId: line.itemId,
        qty: intQty,
        refType: 'purchase',
        refId: po.id,
        note: 'purchase actual in',
      );
    }

    await purchases.updatePurchaseOrderStatus(po.id, PurchaseOrderStatus.received);
  }

  /// 취소: planned 롤백(가능하면) + 상태 전환
  Future<void> cancelPurchase(String purchaseId) async {
    final po = await purchases.getPurchaseOrderById(purchaseId);
    if (po == null) return;

    // received면 취소 불가(정책에 맞게)
    if (po.status == PurchaseOrderStatus.received) return;

    // planned 롤백 지원 시 사용
    await txns.deletePlannedByRef(refType: 'purchase', refId: po.id);

    await purchases.updatePurchaseOrderStatus(po.id, PurchaseOrderStatus.canceled);
  }

  /// 발주 삭제 (소프트/하드)
  Future<void> deletePurchase(String purchaseId, {bool hard = false}) async {
    if (hard) {
      await purchases.hardDeletePurchaseOrder(purchaseId);   // ✅ 새로운 이름
    } else {
      await purchases.softDeletePurchaseOrder(purchaseId);   // ✅ 새로운 이름
    }
  }

  /// 입출고 기록 단일 삭제
  Future<void> deleteTxn(String txnId) => txns.deleteTxn(txnId);
}
