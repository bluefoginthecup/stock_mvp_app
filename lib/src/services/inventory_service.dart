// lib/src/services/inventory_service.dart
import '../repos/repo_interfaces.dart';
import '../models/types.dart';
import '../models/state_guard.dart';
import '../models/purchase_order.dart';   // ✅ 추가: 상태(enum) 사용
import 'dart:math' as math;
import '../models/bom.dart';


class InventoryService {
  final WorkRepo works;
  final PurchaseOrderRepo purchases;   // ✅ PurchaseOrderRepo
  final TxnRepo txns;
  final BomRepo boms;                  // 선택: BOM 소비 planned/actual 쓰려면 사용
  final OrderRepo orders;
  final ItemRepo items;

  InventoryService({
    required this.works,
    required this.purchases,
    required this.txns,
    required this.boms,
    required this.orders,
    required this.items,
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


  Future<void> completeWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;

    final remaining = w.qty - w.doneQty;
    if (remaining <= 0) {
      // 이미 전량(또는 초과) 달성 상태면 굳이 또 처리 안 함
      await works.updateWorkStatus(workId, WorkStatus.done);
      return;
    }

    await completeWorkPartial(workId: workId, madeQty: remaining);
  }


  Future<void> completeWorkPartial({
    required String workId,
    required int madeQty,
  }) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;

    if (madeQty <= 0) return;
    if (w.isDeleted) return;
    if (w.status == WorkStatus.canceled) return;

    // 필요하면 상태 전이 규칙 적용(너희 canTransitionWork)
    // 부분완료는 done이 아니므로 여기선 done 체크만 마지막에
    // if (!canTransitionWork(w.status, WorkStatus.inProgress)) return;

    print('[WORK] completeWorkPartial start workId=$workId madeQty=$madeQty');
    print('[WORK] itemId=${w.itemId} planned=${w.qty} done=${w.doneQty} status=${w.status}');

    // ✅ 1) semi/sub만 차감 (raw 금지, 폭발 금지)
    await _consumeFinishedSemiSubOnly(
      workId: w.id,
      finishedItemId: w.itemId,
      madeQty: madeQty,
    );

    // ✅ 2) 완제품 입고
    await txns.addInActual(
      itemId: w.itemId,
      qty: madeQty,
      refType: 'work',
      refId: w.id,
      note: 'work actual in (partial)',
    );

    // ✅ 3) doneQty 누적 저장
    final newDoneQty = w.doneQty + madeQty;
    await works.updateWorkDoneQty(workId, newDoneQty);

    // ✅ 4) 상태/타임스탬프 갱신
    final now = DateTime.now();

    if (newDoneQty >= w.qty) {
      // 전량 달성(또는 초과) → done
      await works.updateWorkProgress(
        id: workId,
        status: WorkStatus.done,
        startedAt: w.startedAt ?? now,
        finishedAt: now,
      );

    } else {
      await works.updateWorkProgress(
        id: workId,
        status: WorkStatus.inProgress, // enum에 없으면 WorkStatus.planned
        startedAt: w.startedAt ?? now,
      );

    }
  }

  Future<void> setWorkDoneQty({
    required String workId,
    required int targetDoneQty,
  }) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (w.isDeleted) return;
    if (w.status == WorkStatus.canceled) return;

    final clamped = targetDoneQty.clamp(0, 1<<30);

    final delta = clamped - w.doneQty;
    if (delta == 0) return;

    if (delta > 0) {
      // ✅ 추가 생산은 기존 로직 재사용
      await completeWorkPartial(workId: workId, madeQty: delta);
      return;
    }

    // ✅ 감소(정정) = 롤백
    final rollbackQty = -delta; // abs
    await _rollbackWorkProduction(
      workId: workId,
      finishedItemId: w.itemId,
      rollbackQty: rollbackQty,
    );

    // ✅ doneQty 감소 저장
    final newDone = w.doneQty - rollbackQty;
    await works.updateWorkDoneQty(workId, newDone);

    // ✅ 상태/타임스탬프 갱신
    final now = DateTime.now();
    if (newDone <= 0) {
      // 0이면 진행중으로 둘지 planned로 둘지 정책 선택
      await works.updateWorkProgress(
        id: workId,
        status: WorkStatus.inProgress, // 또는 WorkStatus.planned
        startedAt: w.startedAt,
        finishedAt: null,
      );
    } else if (newDone >= w.qty) {
      await works.updateWorkProgress(
        id: workId,
        status: WorkStatus.done,
        startedAt: w.startedAt ?? now,
        finishedAt: w.finishedAt ?? now,
      );
    } else {
      await works.updateWorkProgress(
        id: workId,
        status: WorkStatus.inProgress,
        startedAt: w.startedAt ?? now,
        finishedAt: null,
      );
    }
  }
  Future<void> _rollbackWorkProduction({
    required String workId,
    required String finishedItemId,
    required int rollbackQty,
  }) async {
    if (rollbackQty <= 0) return;

    // (권장) 여기서 안전장치: 완제품 재고가 rollbackQty 이상 있는지 체크
    // 예: final stock = await items.getCurrentQty(finishedItemId);
    // if (stock < rollbackQty) throw Exception('완제품 재고가 부족해서 정정할 수 없습니다.');

    // ✅ 1) 완제품 “입고했던 걸 되돌림” = 완제품 출고(out)
    await txns.addOutActual(
      itemId: finishedItemId,
      qty: rollbackQty,
      refType: 'work',
      refId: workId,
      note: 'rollback finished (adjust doneQty)',
    );

    // ✅ 2) 소모했던 semi/sub 되돌림 = semi/sub 입고(in)
    final rows = await boms.listBom(finishedItemId);
    final comps = rows.where((r) =>
    r.root == BomRoot.finished &&
        (r.kind == BomKind.semi || r.kind == BomKind.sub));

    for (final r in comps) {
      final needInt = _asIntQty(r.needFor(rollbackQty));
      if (needInt <= 0) continue;

      await txns.addInActual(
        itemId: r.componentItemId,
        qty: needInt,
        refType: 'work',
        refId: workId,
        note: 'rollback consume ${r.kind.name} (adjust doneQty)',
      );
    }
  }


  Future<void> _consumeFinishedSemiSubOnly({
    required String workId,
    required String finishedItemId,
    required int madeQty,
  }) async {
    final rows = await boms.listBom(finishedItemId);

    final comps = rows.where((r) =>
    r.root == BomRoot.finished &&
        (r.kind == BomKind.semi || r.kind == BomKind.sub));

    for (final r in comps) {
      final needInt = _asIntQty(r.needFor(madeQty));
      if (needInt <= 0) continue;

      await txns.addOutActual(
        itemId: r.componentItemId,
        qty: needInt,
        refType: 'work',
        refId: workId,
        note: 'consume ${r.kind.name} for finished (partial)',
      );
    }
  }


  /// ✅ 작업 편집 엔트리포인트 (UI는 이것만 호출)
  /// - qty 변경
  /// - doneQty 변경(증가/감소는 기존 setWorkDoneQty 재사용)
  /// - item 변경(조건: doneQty == 0)
  Future<void> editWork({
    required String workId,
    int? newQty,
    int? newDoneQty,
    String? newItemId,
  }) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (w.isDeleted) return;
    if (w.status == WorkStatus.canceled) return;

    // 1) item 변경: doneQty == 0 일 때만
    if (newItemId != null && newItemId != w.itemId) {
      if (w.doneQty != 0) {
        throw Exception('완료 수량이 0일 때만 아이템 변경이 가능합니다.');
      }
      await works.updateWorkItem(workId, newItemId); // ⬅️ 아래 2)에서 추가할 메서드
    }

    // 2) qty 변경: progress가 아니라 qty 컬럼을 직접 업데이트해야 함
    if (newQty != null && newQty != w.qty) {
      await works.updateWorkQty(workId, newQty); // ⬅️ 아래 2)에서 추가할 메서드
    }

    // 3) doneQty 변경: 증감/재고/롤백은 기존 로직 재사용
    if (newDoneQty != null && newDoneQty != w.doneQty) {
      await setWorkDoneQty(workId: workId, targetDoneQty: newDoneQty);
    }
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
          await txns.deleteOutActualByRef(refType: 'work', refId: workId);  // 자재 소모 취소(+)

        } catch (_) {
          // 구현 전이거나 실패해도 앱이 죽지 않도록 방어
        }
        // BOM 자재 소모까지 롤백하려면 여기서 deleteOutActualByRef도 호출하세요.
      }
  /// ✅ 출고 전에 현재고가 충분한지 검증 (검증 소스 = Item.qty)
    Future<void> _ensureStockAvailable({
      required String itemId,
      required int requestQty,
    }) async {
    if (requestQty <= 0) {
      throw StateError('출고 수량은 1개 이상이어야 합니다.');
    }
    // 🔑 핵심: Txn 합산이 아니라 아이템 현재고를 신뢰
    final current = await items.getCurrentQty(itemId);
    if (current <= 0) {
      throw StateError('재고부족: 현재고 0개입니다.');
    }
    if (requestQty > current) {
      throw StateError('재고부족: 현재고 $current개, 요청 $requestQty개');
    }
  }
  // ---------- SHIPMENT (ORDER OUT) ----------
    /// ✅ 주문 상세 > 라인 카드의 "주문 출고" 버튼용
    /// 해당 완제품(itemId)을 '주문 수량(qty)'만큼 즉시 출고(실거래) 처리한다.
    Future<void> shipOrderLine({
      required String orderId,
      required String itemId,
      required int qty,
    }) async {

      // 1) ✅ 라인 중복 출고 가드
      final already = await txns.existsOutActual(refType: 'order', refId: orderId, itemId: itemId);
      if (already) {
        throw StateError(
            '이 품목은 이미 해당 주문으로 출고되었습니다. (orderId=$orderId, itemId=$itemId)');
      }

          // 2) 재고 가드: 현 재고 초과 출고 방지
          await _ensureStockAvailable(itemId: itemId, requestQty: qty);

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

  int _ceilToInt(num v) => v <= 0 ? 0 : v.ceil();

  Future<void> _consumeBomForWork({
    required String workId,
    required String parentItemId,
    required int parentQty,
  }) async {
    final rows = await boms.listBom(parentItemId);
    print('[BOM] listBom parent=$parentItemId rows=${rows.length}');

    for (final r in rows) {
      final need = _ceilToInt(r.needFor(parentQty));
      if (need <= 0) continue;

      // ✅ 1단계 정책: finished 완료 시 "semi/sub만" 차감 (raw 차감 금지)
      if (r.kind == BomKind.semi || r.kind == BomKind.sub) {
        await txns.addOutActual(
          itemId: r.componentItemId,
          qty: need,
          refType: 'work',
          refId: workId,
          note: 'work consume (${r.kind.name})',
        );
        continue;
      }

      // raw는 무시
      print('[BOM] skip raw consume (policy): item=${r.componentItemId} need=$need');
    }
  }


}
