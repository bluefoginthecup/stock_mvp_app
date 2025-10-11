import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/work.dart';
import '../models/purchase.dart';
import 'repo_interfaces.dart';
import 'inmem_repo.dart';
import '../models/types.dart';

class ItemRepoView implements ItemRepo {
  final InMemoryRepo inner;
  ItemRepoView(this.inner);

  @override
  Future<List<Item>> listItems({String? folder, String? keyword}) =>
      inner.listItems(folder: folder, keyword: keyword);

  @override
  Future<Item?> getItem(String id) => inner.getItem(id);

  @override
  Future<void> upsertItem(Item item) => inner.upsertItem(item);

  @override
  Future<void> deleteItem(String id) => inner.deleteItem(id);

  @override
  Future<void> adjustQty({
    required String itemId,
    required int delta,
    String? refType,
    String? refId,
    String? note}) =>
      inner.adjustQty(itemId: itemId, delta: delta, refType: refType, refId: refId, note: note);

  @override
  Future<String?> nameOf(String itemId) => inner.nameOf(itemId); // ✅ 추가

}

class OrderRepoView implements OrderRepo {
  final InMemoryRepo inner;
  OrderRepoView(this.inner);

  @override
  Future<List<Order>> listOrders() => inner.listOrders();

  @override
  Future<Order?> getOrder(String id) => inner.getOrder(id);

  @override
  Future<void> upsertOrder(Order order) => inner.upsertOrder(order);

  @override
  Future<String?> customerNameOf(String orderId) => inner.customerNameOf(orderId); // ✅ 추가

}

class TxnRepoView implements TxnRepo {
  final InMemoryRepo inner;
  TxnRepoView(this.inner);

  @override
  Future<List<Txn>> listTxns({String? itemId}) => inner.listTxns(itemId: itemId);

  @override
  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note})
  => inner.addInPlanned(itemId: itemId, qty: qty, refType: refType, refId: refId, note: note);

  @override
  Future<void> addInActual({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note})
  => inner.addInActual(itemId: itemId, qty: qty, refType: refType, refId: refId, note: note);

}

class BomRepoView implements BomRepo {
  final InMemoryRepo inner;
  BomRepoView(this.inner);

  @override
  Future<List<BomRow>> listBom(String parentItemId) => inner.listBom(parentItemId);

  @override
  Future<void> upsertBomRow(BomRow row) => inner.upsertBomRow(row);

  @override
  Future<void> deleteBomRow(String id) => inner.deleteBomRow(id);
}

// --- WorkRepoView ---
class WorkRepoView implements WorkRepo {
  final InMemoryRepo _m;
  WorkRepoView(this._m);

  @override Future<String> createWork(Work w) => _m.createWork(w);
  @override Future<Work?> getWorkById(String id) => _m.getWorkById(id);
  @override Stream<List<Work>> watchAllWorks() => _m.watchAllWorks();
  @override Future<void> updateWork(Work w) => _m.updateWork(w);
  @override
  Future<void> completeWork(String id) => _m.completeWork(id);
  @override
    Future<void> updateWorkStatus(String id, WorkStatus status) => _m.updateWorkStatus(id, status);
    @override
    Future<void> cancelWork(String id) => _m.cancelWork(id);

}

// --- PurchaseRepoView ---
class PurchaseRepoView implements PurchaseRepo {
  final InMemoryRepo _m;
  PurchaseRepoView(this._m);

  @override Future<String> createPurchase(Purchase p) => _m.createPurchase(p);
  @override Future<Purchase?> getPurchaseById(String id) => _m.getPurchaseById(id);
  @override Stream<List<Purchase>> watchAllPurchases() => _m.watchAllPurchases();
  @override Future<void> updatePurchase(Purchase p) => _m.updatePurchase(p);

  @override
  Future<void> completePurchase(String id) => _m.completePurchase(id);
  @override
    Future<void> updatePurchaseStatus(String id, PurchaseStatus status) => _m.updatePurchaseStatus(id, status);

    @override
    Future<void> cancelPurchase(String id) => _m.cancelPurchase(id);

}
