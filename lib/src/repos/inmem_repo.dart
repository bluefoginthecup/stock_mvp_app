
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/types.dart';
import '../models/work.dart';
import '../models/purchase.dart';

import 'repo_interfaces.dart';

class InMemoryRepo extends ChangeNotifier
    implements ItemRepo, OrderRepo, TxnRepo, BomRepo, WorkRepo, PurchaseRepo {
  final _uuid = const Uuid();
  final Map<String, Item> _items = {};
  final Map<String, Order> _orders = {};
  final Map<String, Txn> _txns = {};
  final Map<String, BomRow> _bom = {};

  InMemoryRepo();
  InMemoryRepo.seeded() {
    // a few seed items
    final i1 = Item(id: _uuid.v4(), name: '루앙 그레이 50 기본형 방석커버', sku: 'LG-50C', unit: 'EA', folder: 'finished', subfolder: 'cushion', minQty: 5, qty: 12);
    final i2 = Item(id: _uuid.v4(), name: '루앙 그레이 40 쿠션커버', sku: 'LG-40C', unit: 'EA', folder: 'finished', subfolder: 'cushion', minQty: 5, qty: 4);
    final fabric = Item(id: _uuid.v4(), name: '원단-루앙 그레이', sku: 'FAB-LG', unit: 'M', folder: 'raw', minQty: 10, qty: 27, subfolder: 'fabric');
    _items[i1.id] = i1;
    _items[i2.id] = i2;
    _items[fabric.id] = fabric;
  }

  void bootstrap() {
    notifyListeners();
  }

  // ItemRepo
  @override
  Future<List<Item>> listItems({String? folder, String? keyword}) async {
    Iterable<Item> values = _items.values;
    if (folder != null) {
      values = values.where((e) => e.folder == folder);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.toLowerCase();
      values = values.where((e) => e.name.toLowerCase().contains(k) || e.sku.toLowerCase().contains(k));
    }
    final list = values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<Item?> getItem(String id) async => _items[id];

  @override
  Future<void> upsertItem(Item item) async {
    _items[item.id] = item;
    notifyListeners();
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.remove(id);
    notifyListeners();
  }

  @override
  Future<void> adjustQty({
    required String itemId,
    required int delta,
    String? refType,  // ← 인터페이스에 맞춰 String?
    String? refId,    // ← 인터페이스에 맞춰 String?
    String? note})
  async {
    final it = _items[itemId];
    if (it == null) return;

    final updated = it.copyWith(qty: it.qty  + delta);
    _items[itemId] = updated;

    // String? -> enum 매핑 (null 안전)
    RefType _parseRefType(String? s) {
      switch (s) {
        case 'order':    return RefType.order;
        case 'work':     return RefType.work;
        case 'purchase': return RefType.purchase;
        default:         return RefType.order; // 기본값
      }
    }

    final txn = Txn(
      id: _uuid.v4(),
      ts: DateTime.now(),
      type: delta >= 0 ? TxnType.in_ : TxnType.out_, // ← enum 값 수정
      itemId: itemId,
      qty: delta.abs(),
      refType: _parseRefType(refType),                 // ✅ enum으로 변환
      refId: refId ?? 'unknown',                       // ✅ null 방지

      note: note,
    );
    _txns[txn.id] = txn;
    notifyListeners();
  }

  @override
  Future<String?> nameOf(String itemId) async {
    return _items[itemId]?.name; // 없으면 null
  }

  // OrderRepo
  @override
  Future<List<Order>> listOrders() async {
    final list = _orders.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<Order?> getOrder(String id) async => _orders[id];

  @override
  Future<void> upsertOrder(Order order) async {
    _orders[order.id] = order;
    notifyListeners();
  }

  @override
  Future<String?> customerNameOf(String orderId) async {
    final o = _orders[orderId];
    return o?.customer; // ✅ Order 클래스에 있는 필드명과 일치
  }


  // TxnRepo
  @override
  Future<List<Txn>> listTxns({String? itemId}) async {
    final list = _txns.values.where((t) => itemId == null || t.itemId == itemId).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    return list;
  }

  // ===== TxnRepo helpers =====
  @override
  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    final txn = Txn(
      id: _uuid.v4(),
      ts: DateTime.now(),
      type: TxnType.in_,
      itemId: itemId,
      qty: qty,
      refType: RefTypeX.fromString(refType),
      refId: refId,
      note: note ?? 'planned inbound',
    );
    _txns[txn.id] = txn;
    notifyListeners();
  }

// addInActual
@override
Future<void> addInActual({
  required String itemId,
  required int qty,
  required String refType,
  required String refId,
  String? note,
}) async {
  final txn = Txn(
    id: _uuid.v4(),
    ts: DateTime.now(),
    type: TxnType.in_,
    itemId: itemId,
    qty: qty,
    refType: RefTypeX.fromString(refType),
    refId: refId,
    note: note ?? 'actual inbound',
  );
  _txns[txn.id] = txn;       // ✅ Map 저장

    final it = _items[itemId];
    if (it != null) {
      _items[itemId] = it.copyWith(qty: it.qty + qty); // ✅
    }
    notifyListeners();
  }

  // BomRepo
  @override
  Future<List<BomRow>> listBom(String parentItemId) async {
    return _bom.values.where((b) => b.parentItemId == parentItemId).toList();
  }

  @override
  Future<void> upsertBomRow(BomRow row) async {
    _bom[row.id] = row;
    notifyListeners();
  }

  @override
  Future<void> deleteBomRow(String id) async {
    _bom.remove(id);
    notifyListeners();
  }

  // ----------------- WorkRepo -----------------
  final _works = <String, Work>{};

  @override
  Future<String> createWork(Work w) async {
    _works[w.id] = w;
    notifyListeners();
    return w.id;
  }

  @override
  Future<Work?> getWorkById(String id) async => _works[id];

  @override
  Stream<List<Work>> watchAllWorks() async* {
    yield _works.values.toList();
  }

  @override
  Future<void> updateWork(Work w) async {
    _works[w.id] = w;
    notifyListeners();
  }

  @override
    Future<void> updateWorkStatus(String id, WorkStatus status) async {
        final w = _works[id];
        if (w == null) return;
        _works[id] = w.copyWith(status: status, updatedAt: DateTime.now());
        notifyListeners();
      }

  @override
    Future<void> cancelWork(String id) async {
        await updateWorkStatus(id, WorkStatus.canceled);
      }

  // ===== WorkRepo.completeWork =====
  @override
  Future<void> completeWork(String id) async {
    final w = _works[id];
    if (w == null) return;
    if (w.status == WorkStatus.done) return;

    // 실제 입고 반영
    await addInActual(
      itemId: w.itemId,
      qty: w.qty,
      refType: 'work',
      refId: id,
      note: '작업 완료 입고',
    );

    // 상태 업데이트
    _works[id] = w.copyWith(
        status: WorkStatus.done,
        updatedAt: DateTime.now());
    notifyListeners();
  }

// ----------------- PurchaseRepo -----------------
  final _purchases = <String, Purchase>{};

  @override
  Future<String> createPurchase(Purchase p) async {
    _purchases[p.id] = p;
    notifyListeners();
    return p.id;
  }

  @override
  Future<Purchase?> getPurchaseById(String id) async => _purchases[id];

  @override
  Stream<List<Purchase>> watchAllPurchases() async* {
    yield _purchases.values.toList();
  }

  @override
  Future<void> updatePurchase(Purchase p) async {
    _purchases[p.id] = p;
    notifyListeners();
  }

  @override
    Future<void> updatePurchaseStatus(String id, PurchaseStatus status) async {
        final p = _purchases[id];
        if (p == null) return;
        _purchases[id] = p.copyWith(status: status, updatedAt: DateTime.now());
        notifyListeners();
      }
  @override
    Future<void> cancelPurchase(String id) async {
        await updatePurchaseStatus(id, PurchaseStatus.canceled);
      }
// ===== PurchaseRepo.completePurchase =====
  @override
  Future<void> completePurchase(String id) async {
    final p = _purchases[id];
    if (p == null) return;
    if (p.status == PurchaseStatus.received) return;

    // 실제 입고 반영
    await addInActual(
      itemId: p.itemId,
      qty: p.qty,
      refType: 'purchase',
      refId: id,
      note: '발주 입고 완료',
    );

    // 상태 업데이트
    _purchases[id] =
        p.copyWith(status: PurchaseStatus.received,
            updatedAt: DateTime.now());
    notifyListeners();
  }


}
