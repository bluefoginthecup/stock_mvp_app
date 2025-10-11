import '../repos/repo_interfaces.dart';
import '../models/types.dart';

class InventoryService {
  final WorkRepo works;
  final PurchaseRepo purchases;
  final TxnRepo txns;
  final BomRepo boms; // 선택: BOM 소비 planned/actual 쓰려면 사용

  InventoryService({
    required this.works,
    required this.purchases,
    required this.txns,
    required this.boms,
  });

  // ---------- WORK ----------
  /// planned -> inProgress : 입고 예정(완제품) planned 등록 + 상태 전환
  Future<void> startWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (w.status != WorkStatus.planned) return;

    // 완제품 planned in (예약)
    await txns.addInPlanned(
      itemId: w.itemId,
      qty: w.qty,
      refType: 'work',
      refId: w.id,
      note: 'work planned in',
    );

    // (선택) BOM 소비 planned out — 현재 TxnRepo에 out 플로우가 없으면 생략
    // final rows = await boms.listBom(w.itemId);
    // for (final r in rows) {
    //   await txns.addOutPlanned(itemId: r.childItemId, qty: r.qty * w.qty, refType: 'work', refId: w.id);
    // }

    await works.updateWorkStatus(workId, WorkStatus.inProgress);
  }

  /// inProgress -> done : planned 정리/실재 반영 + 완료
  Future<void> completeWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (w.status == WorkStatus.done || w.status == WorkStatus.canceled) return;

    // 실제 입고 actual in (완제품)
    await txns.addInActual(
      itemId: w.itemId,
      qty: w.qty,
      refType: 'work',
      refId: w.id,
      note: 'work actual in',
    );

    // (선택) BOM 소비 actual out
    // final rows = await boms.listBom(w.itemId);
    // for (final r in rows) {
    //   await txns.addOutActual(itemId: r.childItemId, qty: r.qty * w.qty, refType: 'work', refId: w.id);
    // }

    await works.completeWork(workId); // 내부에서 status=done 처리(또는 여기에 updateWorkStatus(done))
  }

  /// 취소: planned 예약 롤백(현재 TxnRepo에 remove/cancel planned 없으면 상태만 취소)
  Future<void> cancelWork(String workId) async {
    final w = await works.getWorkById(workId);
    if (w == null) return;
    if (w.status == WorkStatus.done || w.status == WorkStatus.canceled) return;

    // TODO: planned 취소 로직 추가 시 여기서 롤백
    await works.updateWorkStatus(workId, WorkStatus.canceled);
  }

  // ---------- PURCHASE ----------
  /// planned -> ordered : 입고 예정 planned 등록 + 상태 전환
  Future<void> orderPurchase(String purchaseId) async {
    final p = await purchases.getPurchaseById(purchaseId);
    if (p == null) return;
    if (p.status != PurchaseStatus.planned) return;

    await txns.addInPlanned(
      itemId: p.itemId,
      qty: p.qty,
      refType: 'purchase',
      refId: p.id,
      note: 'purchase planned in',
    );
    await purchases.updatePurchaseStatus(purchaseId, PurchaseStatus.ordered);
  }

  /// ordered -> received : planned 정리/실재 반영 + 입고 완료
  Future<void> receivePurchase(String purchaseId) async {
    final p = await purchases.getPurchaseById(purchaseId);
    if (p == null) return;
    if (p.status == PurchaseStatus.received || p.status == PurchaseStatus.canceled) return;

    await txns.addInActual(
      itemId: p.itemId,
      qty: p.qty,
      refType: 'purchase',
      refId: p.id,
      note: 'purchase actual in',
    );
    await purchases.completePurchase(purchaseId); // 내부에서 status=received 처리
  }

  Future<void> cancelPurchase(String purchaseId) async {
    final p = await purchases.getPurchaseById(purchaseId);
    if (p == null) return;
    if (p.status == PurchaseStatus.received || p.status == PurchaseStatus.canceled) return;

    // TODO: planned 취소 로직 추가 시 여기서 롤백
    await purchases.updatePurchaseStatus(purchaseId, PurchaseStatus.canceled);
  }
}
