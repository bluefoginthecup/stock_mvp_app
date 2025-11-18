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

    if (keyword != null && keyword.trim().isNotEmpty) {
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
    await (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
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
    await (delete(items)..where((t) => t.id.equals(id))).go();
    await (delete(itemPaths)..where((t) => t.itemId.equals(id))).go();
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
  Future<void> upsertFinishedBom(
      String finishedItemId,
      List<BomRow> rows,
      ) async {
    // root=finished 인 기존 레시피 삭제 후 통째로 갈아끼우기
    await (delete(bomRows)
      ..where((t) => t.parentItemId.equals(finishedItemId))
      ..where((t) => t.root.equals(BomRoot.finished.name)))
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
  Future<void> upsertSemiBom(
      String semiItemId,
      List<BomRow> rows,
      ) async {
    await (delete(bomRows)
      ..where((t) => t.parentItemId.equals(semiItemId))
      ..where((t) => t.root.equals(BomRoot.semi.name)))
        .go();

    for (final r in rows) {
      final fixed = r.copyWith(
        root: BomRoot.semi,
        parentItemId: semiItemId,
      );
      await into(bomRows).insertOnConflictUpdate(fixed.toCompanion());
    }
  }


  // -------------------------------
  // adjustQty (재고 + Txn 로그)
  // -------------------------------
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

    await transaction(() async {
      final now = DateTime.now();

      // 1) 현재 수량 읽기
      final itemRow = await (select(items)..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (itemRow == null) return;

      final newQty = itemRow.qty + delta;

      // 2) 수량 업데이트
      await (update(items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(qty: Value(newQty)),
      );

      // 3) Txn 로그 기록
      final txn = Txn(
        id: 'txn_${now.microsecondsSinceEpoch}',
        ts: now,
        type: delta > 0 ? TxnType.in_ : TxnType.out_,
        status: TxnStatus.actual,
        itemId: itemId,
        qty: delta.abs(),
        refType:
        refType != null ? RefTypeX.fromString(refType) : RefType.manual,
        refId: refId ?? 'manual',
        note: note,
        memo: memo,
        sourceKey: null,
      );

      await into(txns).insert(txn.toCompanion());
      await _refreshTxnSnapshot();
    });
  }

  // -------------------------------
  // updateUnits (단위/환산 비율 수정)
  // -------------------------------
  @override
  Future<void> updateUnits({
    required String itemId,
    String? unitIn,
    String? unitOut,
    double? conversionRate,
  }) async {
    await (update(items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        unitIn: unitIn != null ? Value(unitIn) : const Value.absent(),
        unitOut: unitOut != null ? Value(unitOut) : const Value.absent(),
        conversionRate: conversionRate != null
            ? Value(conversionRate)
            : const Value.absent(),
      ),
    );
  }

  // -------------------------------
  // nameOf
  // -------------------------------
  @override
  Future<String?> nameOf(String itemId) async {
    final row =
    await (select(items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
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

  // snapshot 캐시용
  List<Txn> _txnSnapshot = [];

  Future<void> _refreshTxnSnapshot() async {
    final rows = await (select(txns)
      ..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .get();
    _txnSnapshot = rows.map((r) => r.toDomain()).toList();
  }

  // -------------------------------
  // listTxns (최신순 + snapshot 갱신)
  // -------------------------------
  @override
  Future<List<Txn>> listTxns() async {
    final rows = await (select(txns)
      ..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .get();
    final list = rows.map((r) => r.toDomain()).toList();
    _txnSnapshot = list;
    return list;
  }

  // -------------------------------
  // addInPlanned
  // -------------------------------
  @override
  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    final txn = Txn.in_(
      id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
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

  // -------------------------------
  // addInActual (입고 확정 + 재고 반영)
  // -------------------------------
  @override
  Future<void> addInActual({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    await transaction(() async {
      final txn = Txn.in_(
        id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
        itemId: itemId,
        qty: qty,
        refType: RefTypeX.fromString(refType),
        refId: refId,
        status: TxnStatus.actual,
        note: note,
      );
      await into(txns).insert(txn.toCompanion());

      final itemRow =
      await (select(items)..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      final currentQty = itemRow?.qty ?? 0;
      final newQty = currentQty + qty;

      await (update(items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(qty: Value(newQty)),
      );

      await _refreshTxnSnapshot();
    });
  }

  // -------------------------------
  // snapshotTxnsDesc (동기 스냅샷)
  // -------------------------------
  @override
  List<Txn> snapshotTxnsDesc() => _txnSnapshot;

  // -------------------------------
  // deleteTxn (하드 삭제)
  // -------------------------------
  @override
  Future<void> deleteTxn(String txnId) async {
    await (delete(txns)..where((t) => t.id.equals(txnId))).go();
    await _refreshTxnSnapshot();
  }

  // -------------------------------
  // deletePlannedByRef
  // -------------------------------
  @override
  Future<void> deletePlannedByRef({
    required String refType,
    required String refId,
  }) async {
    final r = RefTypeX.fromString(refType);

    await (delete(txns)
      ..where((t) => t.refType.equals(r.name))
      ..where((t) => t.refId.equals(refId))
      ..where((t) => t.status.equals(TxnStatus.planned.name)))
        .go();

    await _refreshTxnSnapshot();
  }

  // ================================================================
  // =============== BOM REPO =======================================
  //   (일단 최소 구현은 나중 단계에서… 지금은 인터페이스만 만족)
// ================================================================

  @override
  Future<List<BomRow>> listBom(String parentItemId) async {
    final rows = await (select(bomRows)
      ..where((t) => t.parentItemId.equals(parentItemId)))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<void> upsertBomRow(BomRow row) async {
    await into(bomRows).insertOnConflictUpdate(row.toCompanion());
  }

  @override
  Future<void> deleteBomRow(String id) async {
    // BomRows는 composite PK라서, id 대신 전체 키를 받아야 하는데
    // 지금 인터페이스가 String id 하나만 있어서, 우선 parentItemId 기준 삭제는 별도 설계 필요.
    // 당장은 단순히 parentItemId로 통째로 지우는 용도로 쓰지 않는 이상,
    // 여기선 no-op 또는 추후 확장으로 두는 것도 방법.
    throw UnimplementedError(
        'deleteBomRow(String id) 는 composite PK 구조에 맞게 별도 설계가 필요합니다.');
  }

  // ================================================================
  // =============== ORDER REPO =====================================
  //   (여기는 아직 미사용이면 throw로 둬도 OK)
// ================================================================

  @override
  Future<List<Order>> listOrders() {
    throw UnimplementedError();
  }

  @override
  Future<Order?> getOrder(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertOrder(Order order) {
    throw UnimplementedError();
  }

  @override
  Future<String?> customerNameOf(String orderId) {
    throw UnimplementedError();
  }

  @override
  Future<void> softDeleteOrder(String orderId) {
    throw UnimplementedError();
  }

  @override
  Future<void> hardDeleteOrder(String orderId) {
    throw UnimplementedError();
  }

  // ================================================================
  // =============== WORK REPO ======================================
  // ================================================================

  @override
  Future<String> createWork(Work w) {
    throw UnimplementedError();
  }

  @override
  Future<Work?> getWorkById(String id) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Work>> watchAllWorks() {
    throw UnimplementedError();
  }

  @override
  Future<void> updateWork(Work w) {
    throw UnimplementedError();
  }

  @override
  Future<void> completeWork(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateWorkStatus(String id, WorkStatus status) {
    throw UnimplementedError();
  }
// ✅ 여기 추가
  @override
  Future<void> cancelWork(String id) {
    return updateWorkStatus(id, WorkStatus.canceled);
  }
  @override
  Future<void> softDeleteWork(String workId) {
    throw UnimplementedError();
  }

  @override
  Future<void> hardDeleteWork(String workId) {
    throw UnimplementedError();
  }

  // ================================================================
  // =============== PURCHASE ORDER REPO =============================
  // ================================================================

  @override
  Future<String> createPurchaseOrder(PurchaseOrder po) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePurchaseOrder(PurchaseOrder po) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePurchaseOrderStatus(
      String id, PurchaseOrderStatus status) {
    throw UnimplementedError();
  }

  @override
  Stream<List<PurchaseOrder>> watchAllPurchaseOrders() {
    throw UnimplementedError();
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> softDeletePurchaseOrder(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> hardDeletePurchaseOrder(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertLines(String orderId, List<PurchaseLine> lines) {
    throw UnimplementedError();
  }

  @override
  Future<List<PurchaseLine>> getLines(String orderId) {
    throw UnimplementedError();
  }

  // ================================================================
  // =============== SUPPLIER REPO ==================================
  // ================================================================

  @override
  Future<List<Supplier>> list({String? q, bool onlyActive = true}) {
    throw UnimplementedError();
  }

  @override
  Future<Supplier?> get(String id) {
    throw UnimplementedError();
  }

  @override
  Future<String> upsert(Supplier s) {
    throw UnimplementedError();
  }

  @override
  Future<void> softDelete(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> toggleActive(String id, bool isActive) {
    throw UnimplementedError();
  }
}
