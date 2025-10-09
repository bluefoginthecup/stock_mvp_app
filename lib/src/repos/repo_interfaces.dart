import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/work.dart';
import '../models/purchase.dart';


abstract class ItemRepo {
  Future<List<Item>> listItems({String? folder, String? keyword});
  Future<Item?> getItem(String id);
  Future<void> upsertItem(Item item);
  Future<void> deleteItem(String id);
  Future<void> adjustQty({required String itemId, required int delta, String? refType, String? refId, String? note});
}

abstract class OrderRepo {
  Future<List<Order>> listOrders();
  Future<Order?> getOrder(String id);
  Future<void> upsertOrder(Order order);
}

abstract class TxnRepo {
  Future<List<Txn>> listTxns({String? itemId});
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
}

// Purchase 전용 — 메서드 이름에 Purchase 접두사
abstract class PurchaseRepo {
  Future<String> createPurchase(Purchase p);
  Future<Purchase?> getPurchaseById(String id);
  Stream<List<Purchase>> watchAllPurchases();
  Future<void> updatePurchase(Purchase p);
}