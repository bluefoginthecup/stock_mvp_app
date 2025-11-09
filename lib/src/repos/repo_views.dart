import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/work.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';

import 'repo_interfaces.dart';
import 'inmem_repo.dart';
import '../models/types.dart';


class ItemRepoView implements ItemRepo {
final InMemoryRepo inner;
ItemRepoView(this.inner);

@override

  Future<List<Item>> listItems({String? folder, String? keyword}) async {
    // 레거시 호환: folder 이름이 있으면 L1 이름으로 간주해 경로 검색으로 위임
    if (folder != null && folder.trim().isNotEmpty) {
      final ids = await inner.pathIdsByNames(
        l1Name: folder,
        createIfMissing: false,
      );
      return inner.listItemsByFolderPath(
        l1: ids[0],
        keyword: keyword,
        recursive: true,
      );
    }
    // 폴더 없으면 전역 검색
    if (keyword != null && keyword.trim().isNotEmpty) {
      return inner.searchItemsGlobal(keyword);
    }
    // 키워드도 없으면 전체(이름순)
    return inner.listItemsByFolderPath(recursive: true);
  }

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
    String? note,
    String? memo,
  }) {
    return inner.adjustQty(
      itemId: itemId,
      delta: delta,
      refType: refType,
      refId: refId,
      note: note,
      memo: memo,
    );
  }
@override
Future<void> updateUnits({
  required String itemId,
  String? unitIn,
  String? unitOut,
  double? conversionRate,
}) => inner.updateUnits(
  itemId: itemId,
  unitIn: unitIn,
  unitOut: unitOut,
  conversionRate: conversionRate,
);

@override
Future<String?> nameOf(String itemId) => inner.nameOf(itemId);

  // ★ 추가: 새 인터페이스 구현
  @override
  Future<List<Item>> searchItemsGlobal(String keyword) {
    return inner.searchItemsGlobal(keyword);
  }

  @override
  Future<List<Item>> searchItemsByPath({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  }) {
    return inner.searchItemsByPath(
      l1: l1, l2: l2, l3: l3, keyword: keyword, recursive: recursive,
    );
  }

  // ===== BOM (pass-through) =====
  @override
  List<BomRow> finishedBomOf(String finishedItemId) => inner.finishedBomOf(finishedItemId);
  @override
  Future<void> upsertFinishedBom(String finishedItemId, List<BomRow> rows)
    => inner.upsertFinishedBom(finishedItemId, rows);

  @override
  List<BomRow> semiBomOf(String semiItemId) => inner.semiBomOf(semiItemId);
  @override
  Future<void> upsertSemiBom(String semiItemId, List<BomRow> rows)
    => inner.upsertSemiBom(semiItemId, rows);

@override
int stockOf(String itemId) => inner.stockOf(itemId);

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

  @override
  Future<void> softDeleteOrder(String orderId) => inner.softDeleteOrder(orderId);

  @override
  Future<void> hardDeleteOrder(String orderId) => inner.hardDeleteOrder(orderId);

}

class TxnRepoView implements TxnRepo {
  final InMemoryRepo inner;
  TxnRepoView(this.inner);


  @override
   Future<List<Txn>> listTxns() => inner.listTxns();
   // 선택: 아이템별 트랜잭션 보기
   Future<List<Txn>> listTxnsByItem(String itemId) => inner.listTxnsByItem(itemId);


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

  @override
  List<Txn> snapshotTxnsDesc() => inner.snapshotTxnsDesc();

  @override
    Future<void> deleteTxn(String txnId) => inner.deleteTxn(txnId);
    @override
    Future<void> deletePlannedByRef({required String refType, required String refId})
      => inner.deletePlannedByRef(refType: refType, refId: refId);

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

    // 🧹 삭제 위임
    @override
    Future<void> softDeleteWork(String workId) => _m.softDeleteWork(workId);
    @override
    Future<void> hardDeleteWork(String workId) => _m.hardDeleteWork(workId);

}

  ///--- PurchaseRepoView ---///
///
class PurchaseRepoView implements PurchaseOrderRepo { // ✅ 표준 인터페이스 구현
  final InMemoryRepo _repo;
  PurchaseRepoView(this._repo);

  @override
  Future<String> createPurchaseOrder(PurchaseOrder po) => _repo.createPurchaseOrder(po);
  @override
  Future<void> updatePurchaseOrder(PurchaseOrder po) => _repo.updatePurchaseOrder(po);
  @override
  Future<void> updatePurchaseOrderStatus(String id, PurchaseOrderStatus s) =>
      _repo.updatePurchaseOrderStatus(id, s);
  @override
  Stream<List<PurchaseOrder>> watchAllPurchaseOrders() => _repo.watchAllPurchaseOrders();
  @override
  Future<PurchaseOrder?> getPurchaseOrderById(String id) => _repo.getPurchaseOrderById(id);
  @override
  Future<void> softDeletePurchaseOrder(String id) => _repo.softDeletePurchaseOrder(id);
  @override
  Future<void> hardDeletePurchaseOrder(String id) => _repo.hardDeletePurchaseOrder(id);
  @override
  Future<void> upsertLines(String id, List<PurchaseLine> lines) => _repo.upsertLines(id, lines);
  @override
  Future<List<PurchaseLine>> getLines(String id) => _repo.getLines(id);
}
