import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/work.dart';
import '../models/purchase.dart';
import '../models/types.dart';


abstract class ItemRepo {
  Future<List<Item>> listItems({String? folder, String? keyword});
  // ✅ 추가: 전역(경로 무시) 간단 검색
  Future<List<Item>> searchItemsGlobal(String keyword);

  // ✅ 추가(선택): 경로기반 검색 표준화
  Future<List<Item>> searchItemsByPath({
    String? l1, String? l2, String? l3,
    required String keyword,
    bool recursive = true,
  });

  Future<Item?> getItem(String id);
  Future<void> upsertItem(Item item);
  Future<void> deleteItem(String id);
  Future<void> adjustQty({required String itemId, required int delta, String? refType, String? refId, String? note});
  /// itemId -> 사람 읽는 '아이템명'
  Future<String?> nameOf(String itemId);

}

abstract class OrderRepo {
  Future<List<Order>> listOrders();
  Future<Order?> getOrder(String id);
  Future<void> upsertOrder(Order order);
  /// orderId -> 사람 읽는 '주문자명'
  Future<String?> customerNameOf(String orderId);
  // 🧹 삭제 API
    /// 기본: 소프트 삭제 (isDeleted=true). 목록/검색에서 숨김.
    Future<void> softDeleteOrder(String orderId);
    /// 관리용: 하드 삭제. 연계 데이터 처리 여부는 상위 서비스에서 보장.
    Future<void> hardDeleteOrder(String orderId);
}

abstract class TxnRepo {
  Future<List<Txn>> listTxns();
  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note});
  Future<void> addInActual({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note});
  // 🧹 삭제 API
    /// 입출고 기록은 일반적으로 단일 하드삭제가 필요(실수 입력 취소 등).
    Future<void> deleteTxn(String txnId);
    /// (선택) 특정 참조에 묶인 planned 기록 일괄 삭제가 필요하면 제공
    Future<void> deletePlannedByRef({required String refType, required String refId});


}

abstract class BomRepo {
  Future<List<BomRow>> listBom(String parentItemId);
  Future<void> upsertBomRow(BomRow row);
  Future<void> deleteBomRow(String id);
}
// Work 전용 — 메서드 이름에 Work 접두사
abstract class WorkRepo {
  Future<String> createWork(Work w);
  Future<Work?> getWorkById(String id);
  Stream<List<Work>> watchAllWorks();
  Future<void> updateWork(Work w);
  Future<void> completeWork(String id);
    /// 상태만 변경(재고 반영 없음). 예) planned → inProgress, 또는 취소 처리
    Future<void> updateWorkStatus(String id, WorkStatus status);
    /// 선택: 편의 메서드(원하면 구현)
    Future<void> cancelWork(String id) => updateWorkStatus(id, WorkStatus.canceled);

    // 🧹 삭제 API
    /// 기본: 소프트 삭제 (planned이면 삭제, 진행/완료면 canceled 처리 권장).
    Future<void> softDeleteWork(String workId);
    /// 관리용: 하드 삭제(연계 planned Txn 등은 상위/내부에서 정리).
    Future<void> hardDeleteWork(String workId);

}

// Purchase 전용 — 메서드 이름에 Purchase 접두사
abstract class PurchaseRepo {
  Future<String> createPurchase(Purchase p);
  Future<Purchase?> getPurchaseById(String id);
  Stream<List<Purchase>> watchAllPurchases();
  Future<void> updatePurchase(Purchase p);
  Future<void> completePurchase(String id);
    /// 상태만 변경(재고 반영 없음). 예) planned → ordered
    Future<void> updatePurchaseStatus(String id, PurchaseStatus status);
    /// 선택: 편의 메서드(원하면 구현)
     Future<void> cancelPurchase(String id) => updatePurchaseStatus(id, PurchaseStatus.canceled);

    // 🧹 삭제 API
    /// 기본: 소프트 삭제 (isDeleted=true)로 숨김.
    Future<void> softDeletePurchase(String purchaseId);
    /// 관리용: 하드 삭제.
    Future<void> hardDeletePurchase(String purchaseId);
}