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

  // ✅ qty 정규화 헬퍼: int/num/String/기타 → int (실패 시 0)
    int _asIntQty(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.round();
        return int.tryParse('$v') ?? 0;
      }

  /// inProgress -> done : actual in + 완료
  Future<void> completeWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (!canTransitionWork(w.status, WorkStatus.done)) return;

    // ✅ 수량 정규화(정수화) + >0 가드 (예외 대신 안전 리턴)
        final intQty = _asIntQty(w.qty);
        if (intQty <= 0) {
          // 여기서 예외를 던지면 UI가 못 잡으면 앱이 죽음 → 조용히 무시하고 상태도 바꾸지 않음
          // 필요하면 로그만 남겨도 됨: print('completeWork skipped: qty<=0 (workId:$workId)');
          return;
        }


    await txns.addInActual(
      itemId: w.itemId,
      qty: intQty,
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


    // ================================================
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
          // Txn.qty는 int이므로 정규화 + >0 가드
          final intQty = _asIntQty(line.qty);
          if (intQty <= 0) {
            // 0 수량 라인은 건너뜀 (모델 assert 보호)
            continue;
          }

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
          final intQty = _asIntQty(line.qty);
          if (intQty <= 0) {
            // 0 수량 라인은 건너뜀
            continue;
          }

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



    // =========================================================
    // ✅ 상태 직접 설정 (세 버튼 UI용): 실거래 롤백 + 상태만 변경
    // ---------------------------------------------------------
    // - planned(시작): (inProgress|done)에서 내려올 때 inActual 롤백 후 상태만 planned
    // - inProgress(진행중): done에서 내려올 때 inActual 롤백 후 상태만 inProgress
    // - done(완료): 기존 completeWork() 호출(완제품 inActual 생성 포함)
    // - canceled: 별도 플로우(cancelWork) 사용 권장
    // =========================================================
    Future<void> setWorkStatus(String workId, WorkStatus target) async {
        final w = await works.getWorkById(workId);
        if (w == null) return;
        if (w.status == target) return;
        if (w.status == WorkStatus.canceled) return;

        switch (target) {
          case WorkStatus.planned:
            // 역전환 허용: 진행중/완료 → 시작(계획)
            if (w.status == WorkStatus.inProgress || w.status == WorkStatus.done) {
              await _rollbackWorkActuals(w.id); // 완료 때 생성된 inActual 삭제
            }
            await works.updateWorkStatus(workId, WorkStatus.planned);
            return;

          case WorkStatus.inProgress:
            if (w.status == WorkStatus.done) {
              // 완료 → 진행중 : 실거래 롤백 후 상태만 변경
              await _rollbackWorkActuals(w.id);
              await works.updateWorkStatus(workId, WorkStatus.inProgress);
              return;
            }
            // 시작 → 진행중 : 순방향 기존 진입점 사용
            await startWork(workId);
            return;

          case WorkStatus.done:
            // 진행중 → 완료 : 기존 완료 처리(실거래 생성 포함)
            await completeWork(workId);
            return;

          case WorkStatus.canceled:
            // 화면에서 별도 처리 권장
            return;
        }
      }

    /// ✅ 작업 완료(inActual) 롤백: refType='work', refId=workId 기준
    Future<void> _rollbackWorkActuals(String workId) async {
        try {
          await txns.deleteInActualByRef(refType: 'work', refId: workId);
        } catch (_) {
          // 구현 전이거나 실패해도 앱이 죽지 않도록 방어
        }
        // BOM 자재 소모까지 롤백하려면 여기서 deleteOutActualByRef도 호출하세요.
      }

  // ---------- SHIPMENT (ORDER OUT) ----------
    /// ✅ 주문 상세 > 라인 카드의 "주문 출고" 버튼용
    /// 해당 완제품(itemId)을 '주문 수량(qty)'만큼 즉시 출고(실거래) 처리한다.
    Future<void> shipOrderLine({
      required String orderId,
      required String itemId,
      required int qty,
    }) async {
    if (qty <= 0) {
      throw ArgumentError('출고 수량이 0 이하여서는 안됩니다.');
    }

    // 재고 부족 허용/차단 정책은 여기서 결정한다.
    // 필요하면 현재고 조회 후 가드/모달을 띄워도 된다.
    // ex) final stock = await txns.stockOf(itemId); if (stock < qty) { ... }

    await txns.addOutActual(
      itemId: itemId,
      qty: qty,
      refType: 'order',   // RefType.order 문자열 정책 유지 (프로젝트 컨벤션에 맞춤)
      refId: orderId,
      note: 'order ship',
    );

    /// (선택) 모든 라인 출고 완료 시 주문 상태/ship 처리하고 싶으면 아래 보조함수 구현
     await _maybeMarkOrderShipped(orderId);
  }

   Future<void> _maybeMarkOrderShipped(String orderId) async {
     /// 모든 라인 출고 확인 → orders.updateOrderStatus(orderId, OrderStatus.done) 등
   }
}
