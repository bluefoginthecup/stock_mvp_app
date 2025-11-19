import 'package:flutter/foundation.dart';        // 👈 ChangeNotifier
import 'package:drift/drift.dart';

// DB
import '../db/app_database.dart';

// 도메인 모델
import '../models/item.dart';
import '../models/folder_node.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/order.dart';
import '../models/work.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';
import '../models/suppliers.dart';
import '../models/lot.dart';
import '../models/types.dart';

// 표준 repo 인터페이스
import 'repo_interfaces.dart';

part 'drift_unified_repo.g.dart';

/// ============================================================================
///  DriftUnifiedRepo
///  - 앱의 모든 데이터(재고/주문/생산/발주/거래처/레시피)를 Drift 하나로 통합 관리
/// ============================================================================

// ⛔ 이제 DriftAccessor + DatabaseAccessor 안 씀
// @DriftAccessor(
//   tables: [
//     Items,
//     Folders,
//     ItemPaths,
//     Txns,
//     BomRows,
//     Orders,
//     OrderLines,
//     Works,
//     PurchaseOrders,
//     PurchaseLines,
//     Suppliers,
//     Lots,
//   ],
// )
class DriftUnifiedRepo extends ChangeNotifier
    implements
        ItemRepo,
        TxnRepo,
        BomRepo,
        OrderRepo,
        WorkRepo,
        PurchaseOrderRepo,
        SupplierRepo,
        FolderTreeRepo {

  /// Drift DB 인스턴스
  final AppDatabase db;

  DriftUnifiedRepo(this.db);

  // ================================================================
  // =============== ITEM REPO ======================================
  // ================================================================

  @override
  Future<List<Item>> listItems({String? folder, String? keyword}) async {
    final q = db.select(db.items);

    if (folder != null && folder.isNotEmpty) {
      q.where((tbl) => tbl.folder.equals(folder));
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final like = '%${keyword.trim()}%';
      q.where((tbl) => tbl.name.like(like) | tbl.displayName.like(like));
    }

    final rows = await q.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<List<Item>> searchItemsGlobal(String keyword) async {
    final kw = '%${keyword.trim()}%';

    final rows = await (db.select(db.items)
      ..where((t) =>
      t.name.like(kw) |
      t.displayName.like(kw) |
      t.sku.like(kw) |
      t.id.like(kw)))
        .get();

    return rows.map((e) => e.toDomain()).toList();
  }

  @override
  Future<List<Item>> searchItemsByPath({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  }) async {
    final kw = '%${keyword.trim()}%';

    final joinQuery = db.select(db.items).join([
      innerJoin(
        db.itemPaths,
        db.itemPaths.itemId.equalsExp(db.items.id),
      ),
    ]);

    if (l1 != null) joinQuery.where(db.itemPaths.l1Id.equals(l1));
    if (l2 != null) joinQuery.where(db.itemPaths.l2Id.equals(l2));
    if (l3 != null) joinQuery.where(db.itemPaths.l3Id.equals(l3));

    joinQuery.where(
      db.items.name.like(kw) |
      db.items.displayName.like(kw) |
      db.items.sku.like(kw),
    );

    final rows = await joinQuery.get();
    return rows.map((r) => r.readTable(db.items).toDomain()).toList();
  }

  @override
  Future<Item?> getItem(String id) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> upsertItem(Item item) async {
    await db.into(db.items).insertOnConflictUpdate(item.toCompanion());
    await _updateItemPaths(item);
  }

  Future<void> _updateItemPaths(Item item) async {
    final row = ItemPathsCompanion(
      itemId: Value(item.id),
      l1Id: Value(item.folder.isNotEmpty ? item.folder : null),
      l2Id: Value(item.subfolder),
      l3Id: Value(item.subsubfolder),
    );

    await db.into(db.itemPaths).insertOnConflictUpdate(row);
  }

  @override
  Future<void> deleteItem(String id) async {
    await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
    await (db.delete(db.itemPaths)..where((t) => t.itemId.equals(id))).go();
  }

  // ----------------------------------------------------------
  // BOM — finished / semi (sync 미지원 → 예외)
  // ----------------------------------------------------------
  @override
  List<BomRow> finishedBomOf(String finishedItemId) =>
      throw UnimplementedError('Use listBom() instead.');

  @override
  List<BomRow> semiBomOf(String semiItemId) =>
      throw UnimplementedError('Use listBom() instead.');

  @override
  Future<void> upsertFinishedBom(String finishedItemId, List<BomRow> rows) async {
    await (db.delete(db.bomRows)
      ..where((t) => t.parentItemId.equals(finishedItemId))
      ..where((t) => t.root.equals(BomRoot.finished.name)))
        .go();

    for (final r in rows) {
      await db.into(db.bomRows).insertOnConflictUpdate(
        r
            .copyWith(
          root: BomRoot.finished,
          parentItemId: finishedItemId,
        )
            .toCompanion(),
      );
    }
  }

  @override
  Future<void> upsertSemiBom(String semiItemId, List<BomRow> rows) async {
    await (db.delete(db.bomRows)
      ..where((t) => t.parentItemId.equals(semiItemId))
      ..where((t) => t.root.equals(BomRoot.semi.name)))
        .go();

    for (final r in rows) {
      await db.into(db.bomRows).insertOnConflictUpdate(
        r
            .copyWith(
          root: BomRoot.semi,
          parentItemId: semiItemId,
        )
            .toCompanion(),
      );
    }
  }

  @override
  Future<void> adjustQty({
    required String itemId,
    required int delta,
    String? refType,
    String? refId,
    String? note,
    String? memo,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      final row = await (db.select(db.items)..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (row == null) return;

      await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(qty: Value(row.qty + delta)),
      );

      await db.into(db.txns).insert(
        Txn(
          id: 'txn_${now.microsecondsSinceEpoch}',
          ts: now,
          type: delta > 0 ? TxnType.in_ : TxnType.out_,
          status: TxnStatus.actual,
          itemId: itemId,
          qty: delta.abs(),
          refType: refType != null
              ? RefTypeX.fromString(refType)
              : RefType.manual,
          refId: refId ?? 'manual',
          note: note,
          memo: memo,
          sourceKey: null,
        ).toCompanion(),
      );
    });
  }

  @override
  Future<void> updateUnits({
    required String itemId,
    String? unitIn,
    String? unitOut,
    double? conversionRate,
  }) async {
    await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        unitIn: unitIn != null ? Value(unitIn) : const Value.absent(),
        unitOut: unitOut != null ? Value(unitOut) : const Value.absent(),
        conversionRate:
        conversionRate != null ? Value(conversionRate) : const Value.absent(),
      ),
    );
  }

  @override
  Future<List<String>> itemPathNames(String itemId) async {
    final pathRow =
    await (db.select(db.itemPaths)..where((t) => t.itemId.equals(itemId)))
        .getSingleOrNull();
    if (pathRow == null) return [];

    Future<String?> getFolderName(String? id) async {
      if (id == null) return null;
      final row =
      await (db.select(db.folders)..where((f) => f.id.equals(id)))
          .getSingleOrNull();
      return row?.name;
    }

    final names = <String>[];
    final l1 = await getFolderName(pathRow.l1Id);
    final l2 = await getFolderName(pathRow.l2Id);
    final l3 = await getFolderName(pathRow.l3Id);

    if (l1 != null) names.add(l1);
    if (l2 != null) names.add(l2);
    if (l3 != null) names.add(l3);

    return names;
  }

  @override
  Future<String?> nameOf(String itemId) async {
    final row =
    await (db.select(db.items)..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    return row?.name;
  }

  @override
  int stockOf(String itemId) =>
      throw UnimplementedError('Use getItem() instead.');

  // ================================================================
  // =============== TXN REPO =======================================
  // ================================================================

  List<Txn> _txnSnapshot = [];

  @override
  Future<List<Txn>> listTxns() async {
    final rows =
    await (db.select(db.txns)
      ..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .get();
    _txnSnapshot = rows.map((r) => r.toDomain()).toList();
    return _txnSnapshot;
  }

  @override
  List<Txn> snapshotTxnsDesc() => _txnSnapshot;

  Future<void> _refreshTxnSnapshot() async {
    final rows =
    await (db.select(db.txns)
      ..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .get();
    _txnSnapshot = rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    await db.into(db.txns).insert(
      Txn.in_(
        id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
        itemId: itemId,
        qty: qty,
        refType: RefTypeX.fromString(refType),
        refId: refId,
        status: TxnStatus.planned,
        note: note,
      ).toCompanion(),
    );
    await _refreshTxnSnapshot();
  }

  @override
  Future<void> addInActual({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    await db.transaction(() async {
      await db.into(db.txns).insert(
        Txn.in_(
          id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
          itemId: itemId,
          qty: qty,
          refType: RefTypeX.fromString(refType),
          refId: refId,
          status: TxnStatus.actual,
          note: note,
        ).toCompanion(),
      );

      final row =
      await (db.select(db.items)..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      final newQty = (row?.qty ?? 0) + qty;

      await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(qty: Value(newQty)),
      );
    });

    await _refreshTxnSnapshot();
  }

  @override
  Future<void> deleteTxn(String txnId) async {
    await (db.delete(db.txns)..where((t) => t.id.equals(txnId))).go();
    await _refreshTxnSnapshot();
  }

  @override
  Future<void> deletePlannedByRef({
    required String refType,
    required String refId,
  }) async {
    await (db.delete(db.txns)
      ..where((t) => t.refType.equals(refType))
      ..where((t) => t.refId.equals(refId))
      ..where((t) => t.status.equals(TxnStatus.planned.name)))
        .go();

    await _refreshTxnSnapshot();
  }

  // ================================================================
  // =============== BOM REPO =======================================
  // ================================================================

  @override
  Future<List<BomRow>> listBom(String parentItemId) async {
    final rows =
    await (db.select(db.bomRows)
      ..where((t) => t.parentItemId.equals(parentItemId)))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<void> upsertBomRow(BomRow row) async {
    await db.into(db.bomRows).insertOnConflictUpdate(row.toCompanion());
  }

  @override
  Future<void> deleteBomRow(String id) async {
    final parts = id.split('|');
    if (parts.length != 4) return;

    await (db.delete(db.bomRows)
      ..where((t) => t.root.equals(parts[0]))
      ..where((t) => t.parentItemId.equals(parts[1]))
      ..where((t) => t.componentItemId.equals(parts[2]))
      ..where((t) => t.kind.equals(parts[3])))
        .go();
  }

  // ================================================================
  // =============== ORDER REPO =====================================
  // ================================================================

  @override
  Future<List<Order>> listOrders() async {
    final rows = await (db.select(db.orders)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();

    final list = <Order>[];

    for (final o in rows) {
      final lineRows = await (db.select(db.orderLines)
        ..where((l) => l.orderId.equals(o.id)))
          .get();
      list.add(
        o.toDomain(
          lineRows.map((r) => r.toDomain()).toList(),
        ),
      );
    }

    return list;
  }

  @override
  Future<Order?> getOrder(String id) async {
    final row =
    await (db.select(db.orders)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final lineRows =
    await (db.select(db.orderLines)..where((l) => l.orderId.equals(id)))
        .get();
    return row.toDomain(lineRows.map((r) => r.toDomain()).toList());
  }

  @override
  Future<void> upsertOrder(Order order) async {
    await db.transaction(() async {
      await db.into(db.orders).insertOnConflictUpdate(
        OrdersCompanion(
          id: Value(order.id),
          date: Value(order.date.toIso8601String()),
          customer: Value(order.customer),
          memo: Value(order.memo),
          status: Value(order.status.name),
          isDeleted: Value(order.isDeleted),
          updatedAt: Value(order.updatedAt != null
              ? order.updatedAt!.toIso8601String()
              : null),
        ),
      );

      await (db.delete(db.orderLines)
        ..where((l) => l.orderId.equals(order.id)))
          .go();

      for (final line in order.lines) {
        await db.into(db.orderLines).insert(line.toCompanion(order.id));
      }
    });
  }

  @override
  Future<String?> customerNameOf(String orderId) async {
    final row =
    await (db.select(db.orders)..where((t) => t.id.equals(orderId)))
        .getSingleOrNull();
    return row?.customer;
  }

  @override
  Future<void> softDeleteOrder(String orderId) async {
    await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> hardDeleteOrder(String orderId) async {
    await db.transaction(() async {
      await (db.delete(db.orderLines)
        ..where((l) => l.orderId.equals(orderId)))
          .go();
      await (db.delete(db.orders)..where((t) => t.id.equals(orderId))).go();
    });
  }

  // ================================================================
  // =============== WORK REPO ======================================
  // ================================================================

  @override
  Future<String> createWork(Work w) async {
    await db.into(db.works).insert(w.toCompanion());
    return w.id;
  }

  @override
  Future<Work?> getWorkById(String id) async {
    final row =
    await (db.select(db.works)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Stream<List<Work>> watchAllWorks() {
    final q = db.select(db.works)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  @override
  Future<void> updateWork(Work w) async {
    await (db.update(db.works)..where((t) => t.id.equals(w.id)))
        .write(w.toCompanion());
  }

  @override
  Future<void> completeWork(String id) =>
      updateWorkStatus(id, WorkStatus.done);

  @override
  Future<void> updateWorkStatus(String id, WorkStatus status) async {
    await (db.update(db.works)..where((t) => t.id.equals(id))).write(
      WorksCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> cancelWork(String id) =>
      updateWorkStatus(id, WorkStatus.canceled);

  @override
  Future<void> softDeleteWork(String workId) async {
    await (db.update(db.works)..where((t) => t.id.equals(workId))).write(
      WorksCompanion(
        isDeleted: Value(true),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> hardDeleteWork(String workId) async {
    await (db.delete(db.works)..where((t) => t.id.equals(workId))).go();
  }

  // ================================================================
  // =============== PURCHASE ORDER REPO =============================
  // ================================================================

  @override
  Future<String> createPurchaseOrder(PurchaseOrder po) async {
    await db.into(db.purchaseOrders).insertOnConflictUpdate(po.toCompanion());
    return po.id;
  }

  @override
  Future<void> updatePurchaseOrder(PurchaseOrder po) async {
    await db.into(db.purchaseOrders).insertOnConflictUpdate(po.toCompanion());
  }

  @override
  Future<void> updatePurchaseOrderStatus(
      String id,
      PurchaseOrderStatus status,
      ) async {
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Stream<List<PurchaseOrder>> watchAllPurchaseOrders() {
    final q = db.select(db.purchaseOrders)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    final row =
    await (db.select(db.purchaseOrders)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> softDeletePurchaseOrder(String id) async {
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> hardDeletePurchaseOrder(String id) async {
    await db.transaction(() async {
      await (db.delete(db.purchaseLines)
        ..where((l) => l.orderId.equals(id)))
          .go();
      await (db.delete(db.purchaseOrders)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<void> upsertLines(String orderId, List<PurchaseLine> lines) async {
    await db.transaction(() async {
      await (db.delete(db.purchaseLines)
        ..where((l) => l.orderId.equals(orderId)))
          .go();
      for (final line in lines) {
        await db.into(db.purchaseLines).insert(line.toCompanion());
      }
    });
  }

  @override
  Future<List<PurchaseLine>> getLines(String orderId) async {
    final rows = await (db.select(db.purchaseLines)
      ..where((l) => l.orderId.equals(orderId)))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  // ================================================================
  // =============== SUPPLIER REPO ==================================
  // ================================================================

  @override
  Future<List<Supplier>> list({String? q, bool onlyActive = true}) async {
    final query = db.select(db.suppliers);

    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }

    if (q != null && q.trim().isNotEmpty) {
      final k = '%${q.trim()}%';
      query.where((t) =>
      t.name.like(k) |
      t.contactName.like(k) |
      t.phone.like(k) |
      t.email.like(k));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.name)]);

    final rows = await query.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<Supplier?> get(String id) async {
    final row =
    await (db.select(db.suppliers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<String> upsert(Supplier s) async {
    await db.into(db.suppliers).insertOnConflictUpdate(s.toCompanion());
    return s.id;
  }

  @override
  Future<void> softDelete(String id) async {
    await (db.update(db.suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> toggleActive(String id, bool isActive) async {
    await (db.update(db.suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // ================================================================
  // =============== FOLDER TREE REPO ===============================
  // ================================================================

  FolderSortMode _sortMode = FolderSortMode.name;

  @override
  FolderSortMode get sortMode => _sortMode;

  @override
  Future<void> setSortMode(FolderSortMode mode) async {
    _sortMode = mode;
    notifyListeners();
  }

  @override
  Future<List<FolderNode>> listFolderChildren(String? parentId) async {
    final q = db.select(db.folders)
      ..where(
            (tbl) => parentId == null
            ? tbl.parentId.isNull()
            : tbl.parentId.equals(parentId),
      );

    if (_sortMode == FolderSortMode.name) {
      q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    } else {
      q.orderBy([(t) => OrderingTerm.asc(t.order)]);
    }

    final rows = await q.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  FolderNode? folderById(String id) =>
      throw UnimplementedError('Use async select() instead.');

  @override
  Future<FolderNode> createFolderNode({
    required String? parentId,
    required String name,
  }) async {
    // 🔧 parentId가 null일 때는 쿼리 안 날림
    final parentRow = parentId == null
        ? null
        : await (db.select(db.folders)
      ..where((t) => t.id.equals(parentId!)))
        .getSingleOrNull();

    final depth = parentRow != null ? parentRow.depth + 1 : 1;

    final newId = 'fo_${DateTime.now().microsecondsSinceEpoch}';

    final row = FoldersCompanion(
      id: Value(newId),
      name: Value(name),
      parentId: Value(parentId),
      depth: Value(depth),
      order: const Value(0),
    );

    await db.into(db.folders).insert(row);

    return FolderNode(
      id: newId,
      name: name,
      parentId: parentId,
      depth: depth,
      order: 0,
    );
  }


  @override
  Future<void> renameFolderNode({
    required String id,
    required String newName,
  }) async {
    await (db.update(db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(name: Value(newName)),
    );
  }

  @override
  Future<void> deleteFolderNode(String id) async {
    final hasChildren =
    await (db.select(db.folders)..where((t) => t.parentId.equals(id)))
        .get();
    if (hasChildren.isNotEmpty) throw StateError('subfolders exist');

    final containsItems = await (db.select(db.itemPaths)
      ..where(
            (t) =>
        t.l1Id.equals(id) | t.l2Id.equals(id) | t.l3Id.equals(id),
      ))
        .get();
    if (containsItems.isNotEmpty) throw StateError('referenced by items');

    await (db.delete(db.folders)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<(List<FolderNode>, List<Item>)> searchAll({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  }) async {
    final kw = '%${keyword.trim()}%';

    final folderRows =
    await (db.select(db.folders)..where((t) => t.name.like(kw))).get();
    final folderNodes = folderRows.map((r) => r.toDomain()).toList();

    final join = db.select(db.items).join([
      innerJoin(
        db.itemPaths,
        db.itemPaths.itemId.equalsExp(db.items.id),
      ),
    ]);

    if (l1 != null) join.where(db.itemPaths.l1Id.equals(l1));
    if (l2 != null) join.where(db.itemPaths.l2Id.equals(l2));
    if (l3 != null) join.where(db.itemPaths.l3Id.equals(l3));

    join.where(
      db.items.name.like(kw) |
      db.items.displayName.like(kw) |
      db.items.sku.like(kw),
    );

    final itemRows = await join.get();
    final itemsFound =
    itemRows.map((r) => r.readTable(db.items).toDomain()).toList();

    return (folderNodes, itemsFound);
  }

  @override
  Future<int> moveItemsToPath({
    required List<String> itemIds,
    required List<String> pathIds,
  }) async {
    int moved = 0;
    for (final itemId in itemIds) {
      await _moveSingleItem(itemId, pathIds);
      moved++;
    }
    return moved;
  }

  Future<void> _moveSingleItem(String itemId, List<String> pathIds) async {
    final l1 = pathIds.isNotEmpty ? pathIds[0] : null;
    final l2 = pathIds.length > 1 ? pathIds[1] : null;
    final l3 = pathIds.length > 2 ? pathIds[2] : null;

    await (db.update(db.itemPaths)..where((t) => t.itemId.equals(itemId)))
        .write(
      ItemPathsCompanion(
        l1Id: Value(l1),
        l2Id: Value(l2),
        l3Id: Value(l3),
      ),
    );
  }

  @override
  Future<void> moveEntityToPath(MoveRequest req) async {
    if (req.kind == EntityKind.item) {
      return _moveSingleItem(req.id, req.pathIds);
    }

    if (req.kind == EntityKind.folder) {
      final depth = req.pathIds.length + 1;
      await (db.update(db.folders)..where((t) => t.id.equals(req.id))).write(
        FoldersCompanion(
          parentId:
          Value(req.pathIds.isNotEmpty ? req.pathIds.last : null),
          depth: Value(depth),
        ),
      );
      return;
    }

    throw UnsupportedError('Unknown entity kind');
  }
}
