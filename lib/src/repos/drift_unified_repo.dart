// lib/src/repos/drift_unified_repo.dart

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
@DriftAccessor(
  tables: [
    Items,
    Folders,
    ItemPaths,
    Txns,
    BomRows,
    Orders,
    OrderLines,
    Works,
    PurchaseOrders,
    PurchaseLines,
    Suppliers,
    Lots,
  ],
)
class DriftUnifiedRepo extends DatabaseAccessor<AppDatabase>
    with _$DriftUnifiedRepoMixin
    implements
        ItemRepo,
        TxnRepo,
        BomRepo,
        OrderRepo,
        WorkRepo,
        PurchaseOrderRepo,
        SupplierRepo {
  DriftUnifiedRepo(AppDatabase db) : super(db);

  // ================================================================
  // =============== ITEM REPO ======================================
  // ================================================================

  // -------------------------------
  // listItems
  // -------------------------------
  @override
  Future<List<Item>> listItems({String? folder, String? keyword}) async {
    final q = select(items);

    if (folder != null && folder.isNotEmpty) {
      q.where((tbl) => tbl.folder.equals(folder));
    }

    if (keyword != null && keyword
        .trim()
        .isNotEmpty) {
      final like = '%${keyword.trim()}%';
      q.where(
            (tbl) => tbl.name.like(like) | tbl.displayName.like(like),
      );
    }

    final rows = await q.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  // -------------------------------
  // searchItemsGlobal
  // -------------------------------
  @override
  Future<List<Item>> searchItemsGlobal(String keyword) async {
    final kw = '%${keyword.trim()}%';

    final rows = await (select(items)
      ..where(
            (t) =>
        t.name.like(kw) |
        t.displayName.like(kw) |
        t.sku.like(kw) |
        t.id.like(kw),
      ))
        .get();

    return rows.map((e) => e.toDomain()).toList();
  }

  // -------------------------------
  // searchItemsByPath (ItemPaths join)
  // -------------------------------
  @override
  Future<List<Item>> searchItemsByPath({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true, // 현재는 사용하지 않지만 시그니처 맞춤 용
  }) async {
    final kw = '%${keyword.trim()}%';

    final joinQuery = select(items).join([
      innerJoin(itemPaths, itemPaths.itemId.equalsExp(items.id)),
    ]);

    if (l1 != null) {
      joinQuery.where(itemPaths.l1Id.equals(l1));
    }
    if (l2 != null) {
      joinQuery.where(itemPaths.l2Id.equals(l2));
    }
    if (l3 != null) {
      joinQuery.where(itemPaths.l3Id.equals(l3));
    }

    joinQuery.where(
      items.name.like(kw) |
      items.displayName.like(kw) |
      items.sku.like(kw),
    );

    final rows = await joinQuery.get();
    return rows.map((r) => r.readTable(items).toDomain()).toList();
  }

  // -------------------------------
  // getItem
  // -------------------------------
  @override
  Future<Item?> getItem(String id) async {
    final row =
    await (select(items)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  // -------------------------------
  // upsertItem (+ ItemPaths 유지)
  // -------------------------------
  @override
  Future<void> upsertItem(Item item) async {
    final companion = item.toCompanion();
    await into(items).insertOnConflictUpdate(companion);
    await _updateItemPaths(item);
  }

  Future<void> _updateItemPaths(Item item) async {
    final l1 = item.folder.isNotEmpty ? item.folder : null;
    final l2 = item.subfolder;
    final l3 = item.subsubfolder;

    final row = ItemPathsCompanion(
      itemId: Value(item.id),
      l1Id: Value(l1),
      l2Id: Value(l2),
      l3Id: Value(l3),
    );

    await into(itemPaths).insertOnConflictUpdate(row);
  }

  // -------------------------------
  // deleteItem (hard delete)
  // -------------------------------
  @override
  Future<void> deleteItem(String id) async {
    await (delete(items)
      ..where((t) => t.id.equals(id))).go();
    await (delete(itemPaths)
      ..where((t) => t.itemId.equals(id))).go();
  }


  // ===============================
  // ItemRepo: BOM 편의 메서드들 (임시 Stub)
  // ===============================

  @override
  List<BomRow> finishedBomOf(String finishedItemId) {
    // ⚠️ Drift에서는 sync DB 쿼리가 안 되므로,
    // 이 메서드는 실제로는 쓰지 않는 걸 권장.
    throw UnimplementedError(
      'finishedBomOf()는 DriftUnifiedRepo에서 sync로 지원되지 않습니다. '
          '대신 BomRepo.listBom(finishedItemId)를 사용해 주세요.',
    );
  }

  @override
  List<BomRow> semiBomOf(String semiItemId) {
    throw UnimplementedError(
      'semiBomOf()는 DriftUnifiedRepo에서 sync로 지원되지 않습니다. '
          '대신 BomRepo.listBom(semiItemId)를 사용해 주세요.',
    );
  }

  @override
  Future<void> upsertFinishedBom(String finishedItemId,
      List<BomRow> rows,) async {
    // root=finished 인 기존 레시피 삭제 후 통째로 갈아끼우기
    await (delete(bomRows)
      ..where((t) => t.parentItemId.equals(finishedItemId))..where((t) =>
          t.root.equals(BomRoot.finished.name)))
        .go();

    for (final r in rows) {
      final fixed = r.copyWith(
        root: BomRoot.finished,
        parentItemId: finishedItemId,
      );
      await into(bomRows).insertOnConflictUpdate(fixed.toCompanion());
    }
  }

  @override
  Future<void> upsertSemiBom(String semiItemId,
      List<BomRow> rows,) async {
    await (delete(bomRows)
      ..where((t) => t.parentItemId.equals(semiItemId))..where((t) =>
          t.root.equals(BomRoot.semi.name)))
        .go();

    for (final r in rows) {
      final fixed = r.copyWith(
        root: BomRoot.semi,
        parentItemId: semiItemId,
      );
      await into(bomRows).insertOnConflictUpdate(fixed.toCompanion());
    }
  }


// ===============================
// ItemRepo: adjustQty
// ===============================
  @override
  Future<void> adjustQty({
    required String itemId,
    required int delta,
    String? refType,
    String? refId,
    String? note,
    String? memo,
  }) async {
    assert(delta != 0);

    final now = DateTime.now();

    await transaction(() async {
      // 1) 현재 수량 읽기
      final row = await (select(items)
        ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();

      if (row == null) {
        // 없는 아이템이면 그냥 리턴 (혹은 throw 해도 됨)
        return;
      }

      final newQty = row.qty + delta;

      // 2) 수량 업데이트
      await (update(items)
        ..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(
          qty: Value(newQty),
        ),
      );

      // 3) Txn 기록 남기기
      final txn = Txn(
        id: 'txn_${now.microsecondsSinceEpoch}',
        ts: now,
        type: delta > 0 ? TxnType.in_ : TxnType.out_,
        status: TxnStatus.actual,
        itemId: itemId,
        qty: delta.abs(),
        refType: refType != null ? RefTypeX.fromString(refType) : RefType
            .manual,
        refId: refId ?? 'manual',
        note: note,
        memo: memo,
        sourceKey: null,
      );

      await into(txns).insert(txn.toCompanion());
    });
  }

  @override
  Future<void> updateUnits({
    required String itemId,
    String? unitIn,
    String? unitOut,
    double? conversionRate,
  }) async {
    final companion = ItemsCompanion(
      unitIn: unitIn != null ? Value(unitIn) : const Value.absent(),
      unitOut: unitOut != null ? Value(unitOut) : const Value.absent(),
      conversionRate: conversionRate != null
          ? Value(conversionRate)
          : const Value.absent(),
    );

    await (update(items)
      ..where((t) => t.id.equals(itemId))).write(companion);
  }

  // -------------------------------
  // nameOf
  // -------------------------------
  @override
  Future<String?> nameOf(String itemId) async {
    final row =
    await (select(items)
      ..where((t) => t.id.equals(itemId))).getSingleOrNull();
    return row?.name;
  }

  // -------------------------------
  // stockOf (sync 미지원 → 예외)
  // -------------------------------
  @override
  int stockOf(String itemId) {
    throw UnimplementedError(
      'Use getItem() or a stream instead of sync stockOf() in Drift.',
    );
  }

  // ================================================================
  // =============== TXN REPO =======================================
  // ================================================================

  // 최신 트랜잭션 스냅샷 (동기 접근용 캐시)
  List<Txn> _txnSnapshot = [];

  // 전체 Txn 리스트 (ts 내림차순) + 스냅샷 갱신
  @override
  Future<List<Txn>> listTxns() async {
    final rows = await (select(txns)
      ..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .get();

    final list = rows.map((r) => r.toDomain()).toList();
    _txnSnapshot = list;
    return list;
  }

  // 스냅샷 그대로 돌려주기
  @override
  List<Txn> snapshotTxnsDesc() => _txnSnapshot;

  Future<void> _refreshTxnSnapshot() async {
    final rows = await (select(txns)
      ..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .get();
    _txnSnapshot = rows.map((r) => r.toDomain()).toList();
  }

  // ------------------------------------------------
  // planned inbound 추가 (예: 발주 planned 수량)
  // ------------------------------------------------
  @override
  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    final txn = Txn.in_(
      id: 'txn_${DateTime
          .now()
          .microsecondsSinceEpoch}',
      itemId: itemId,
      qty: qty,
      refType: RefTypeX.fromString(refType),
      refId: refId,
      status: TxnStatus.planned,
      note: note,
    );

    await into(txns).insert(txn.toCompanion());
    await _refreshTxnSnapshot();
  }

  // ------------------------------------------------
  // actual inbound 추가 + items.qty 반영
  // ------------------------------------------------
  @override
  Future<void> addInActual({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    await transaction(() async {
      // 1) Txn 기록(actual)
      final txn = Txn.in_(
        id: 'txn_${DateTime
            .now()
            .microsecondsSinceEpoch}',
        itemId: itemId,
        qty: qty,
        refType: RefTypeX.fromString(refType),
        refId: refId,
        status: TxnStatus.actual,
        note: note,
      );
      await into(txns).insert(txn.toCompanion());

      // 2) items.qty 증가
      final row = await (select(items)
        ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();

      final currentQty = row?.qty ?? 0;
      final newQty = currentQty + qty;

      await (update(items)
        ..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(qty: Value(newQty)),
      );
    });

    await _refreshTxnSnapshot();
  }

  // ------------------------------------------------
  // 단건 삭제 (하드 삭제)
  // ------------------------------------------------
  @override
  Future<void> deleteTxn(String txnId) async {
    await (delete(txns)
      ..where((t) => t.id.equals(txnId))).go();
    await _refreshTxnSnapshot();
  }

  // ------------------------------------------------
  // planned 기록 refType/refId 기준 일괄 삭제
  // ------------------------------------------------
  @override
  Future<void> deletePlannedByRef({
    required String refType,
    required String refId,
  }) async {
    final rt = RefTypeX.fromString(refType);

    await (delete(txns)
      ..where((t) => t.refType.equals(rt.name))..where((t) =>
          t.refId.equals(refId))..where((t) =>
          t.status.equals(TxnStatus.planned.name)))
        .go();

    await _refreshTxnSnapshot();
  }

  // ================================================================
  // =============== BOM REPO =======================================
  // ================================================================
  @override
  Future<List<BomRow>> listBom(String parentItemId) async {
    final rows = await (select(bomRows)
      ..where((t) => t.parentItemId.equals(parentItemId)))
        .get();

    return rows.map((r) => r.toDomain()).toList(); // BomRowDbMapping 확장 사용
  }

  @override
  Future<void> upsertBomRow(BomRow row) async {
    await into(bomRows).insertOnConflictUpdate(row.toCompanion());
  }

  /// id 포맷을 "root|parentItemId|componentItemId|kind" 로 가정하고 삭제
  /// 예: 'finished|it_F_rouen_gray_cc_50|it_SF_piping_gray|raw'
  @override
  Future<void> deleteBomRow(String id) async {
    final parts = id.split('|');
    if (parts.length != 4) {
      // 잘못된 형식이면 그냥 무시 (원하면 throw로 바꿔도 됨)
      return;
    }

    final rootStr = parts[0];
    final parentId = parts[1];
    final compId = parts[2];
    final kindStr = parts[3];

    await (delete(bomRows)
      ..where((t) => t.root.equals(rootStr))..where((t) =>
          t.parentItemId.equals(parentId))..where((t) =>
          t.componentItemId.equals(compId))..where((t) =>
          t.kind.equals(kindStr)))
        .go();
  }

  // ================================================================
  // =============== ORDER REPO =====================================
  // ================================================================
  @override
  Future<List<Order>> listOrders() async {
    final orderRows = await (select(orders)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();

    final result = <Order>[];

    for (final o in orderRows) {
      final lineRows = await (select(orderLines)
        ..where((l) => l.orderId.equals(o.id)))
          .get();

      final lines = lineRows.map((r) => r.toDomain()).toList();
      result.add(o.toDomain(lines)); // OrderRowMappingExt 사용
    }

    return result;
  }

  @override
  Future<Order?> getOrder(String id) async {
    final row = await (select(orders)
      ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final lineRows =
    await (select(orderLines)
      ..where((l) => l.orderId.equals(id))).get();
    final lines = lineRows.map((r) => r.toDomain()).toList();

    return row.toDomain(lines);
  }

  @override
  Future<void> upsertOrder(Order order) async {
    await transaction(() async {
      // 1) 헤더 upsert
      await into(orders).insertOnConflictUpdate(
        OrdersCompanion(
          id: Value(order.id),
          date: Value(order.date.toIso8601String()),
          customer: Value(order.customer),
          memo: Value(order.memo),
          status: Value(order.status.name),
          isDeleted: Value(order.isDeleted),
          updatedAt: Value(order.updatedAt?.toIso8601String()),
        ),
      );

      // 2) 라인 싹 지우고 다시 삽입
      await (delete(orderLines)
        ..where((l) => l.orderId.equals(order.id))).go();

      for (final line in order.lines) {
        await into(orderLines).insert(line.toCompanion(order.id));
      }
    });
  }

  @override
  Future<String?> customerNameOf(String orderId) async {
    final row = await (select(orders)
      ..where((t) => t.id.equals(orderId)))
        .getSingleOrNull();
    return row?.customer;
  }

  @override
  Future<void> softDeleteOrder(String orderId) async {
    await (update(orders)
      ..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> hardDeleteOrder(String orderId) async {
    await transaction(() async {
      await (delete(orderLines)
        ..where((l) => l.orderId.equals(orderId))).go();
      await (delete(orders)
        ..where((t) => t.id.equals(orderId))).go();
    });
  }

  // ================================================================
  // =============== WORK REPO ======================================
  // ================================================================
  @override
  Future<String> createWork(Work w) async {
    await into(works).insert(w.toCompanion());
    return w.id;
  }

  @override
  Future<Work?> getWorkById(String id) async {
    final row =
    await (select(works)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Stream<List<Work>> watchAllWorks() {
    final q = select(works)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return q.watch().map(
          (rows) => rows.map((r) => r.toDomain()).toList(),
    );
  }

  @override
  Future<void> updateWork(Work w) async {
    await (update(works)
      ..where((t) => t.id.equals(w.id)))
        .write(w.toCompanion());
  }

  @override
  Future<void> completeWork(String id) async {
    await updateWorkStatus(id, WorkStatus.done);
  }

  @override
  Future<void> updateWorkStatus(String id, WorkStatus status) async {
    await (update(works)
      ..where((t) => t.id.equals(id))).write(
      WorksCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // cancelWork는 인터페이스 기본 구현이 있지만, 여기서 명시적으로 override 해 둠
  @override
  Future<void> cancelWork(String id) =>
      updateWorkStatus(id, WorkStatus.canceled);

  @override
  Future<void> softDeleteWork(String workId) async {
    await (update(works)
      ..where((t) => t.id.equals(workId))).write(
      WorksCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> hardDeleteWork(String workId) async {
    await (delete(works)
      ..where((t) => t.id.equals(workId))).go();
  }

  // ================================================================
  // =============== PURCHASE ORDER REPO =============================
  // ================================================================
  @override
  Future<String> createPurchaseOrder(PurchaseOrder po) async {
    await into(purchaseOrders).insertOnConflictUpdate(po.toCompanion());
    return po.id;
  }

  @override
  Future<void> updatePurchaseOrder(PurchaseOrder po) async {
    // upsert로 통일 (id 기준으로 갱신)
    await into(purchaseOrders).insertOnConflictUpdate(po.toCompanion());
  }

  @override
  Future<void> updatePurchaseOrderStatus(String id,
      PurchaseOrderStatus status) async {
    await (update(purchaseOrders)
      ..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Stream<List<PurchaseOrder>> watchAllPurchaseOrders() {
    final q = select(purchaseOrders)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return q.watch().map(
          (rows) => rows.map((r) => r.toDomain()).toList(),
    );
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    final row = await (select(purchaseOrders)
      ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> softDeletePurchaseOrder(String id) async {
    await (update(purchaseOrders)
      ..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> hardDeletePurchaseOrder(String id) async {
    await transaction(() async {
      await (delete(purchaseLines)
        ..where((l) => l.orderId.equals(id))).go();
      await (delete(purchaseOrders)
        ..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<void> upsertLines(String orderId, List<PurchaseLine> lines) async {
    await transaction(() async {
      // 기존 라인 삭제
      await (delete(purchaseLines)
        ..where((l) => l.orderId.equals(orderId)))
          .go();

      // 새 라인 삽입
      for (final line in lines) {
        await into(purchaseLines).insert(line.toCompanion());
      }
    });
  }

  @override
  Future<List<PurchaseLine>> getLines(String orderId) async {
    final rows = await (select(purchaseLines)
      ..where((l) => l.orderId.equals(orderId)))
        .get();

    return rows.map((r) => r.toDomain()).toList();
  }

  // ================================================================
  // =============== SUPPLIER REPO ==================================
  // ================================================================
  @override
  Future<List<Supplier>> list({String? q, bool onlyActive = true}) async {
    final query = select(suppliers);

    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }

    if (q != null && q
        .trim()
        .isNotEmpty) {
      final k = '%${q.trim()}%';
      query.where(
            (t) =>
        t.name.like(k) |
        t.contactName.like(k) |
        t.phone.like(k) |
        t.email.like(k),
      );
    }

    query.orderBy([(t) => OrderingTerm.asc(t.name)]);

    final rows = await query.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<Supplier?> get(String id) async {
    final row =
    await (select(suppliers)
      ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<String> upsert(Supplier s) async {
    await into(suppliers).insertOnConflictUpdate(s.toCompanion());
    return s.id;
  }

  @override
  Future<void> softDelete(String id) async {
    await (update(suppliers)
      ..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Future<void> toggleActive(String id, bool isActive) async {
    await (update(suppliers)
      ..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }
}