import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/work.dart';
import '../models/purchase.dart';
import '../models/types.dart';


abstract class ItemRepo {
  Future<List<Item>> listItems({String? folder, String? keyword});
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

}