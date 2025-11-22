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


/// ============================================================================
///  DriftUnifiedRepo
///  - 앱의 모든 데이터(재고/주문/생산/발주/거래처/레시피)를 Drift 하나로 통합 관리
/// ============================================================================

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

  final AppDatabase db;

  DriftUnifiedRepo(this.db);

  // ====== 📦 캐시 ======
  // Item 전체(단위/힌트 포함) & 재고 수량(int) 동기 접근용
  final Map<String, Item> _itemsById = {};
  final Map<String, int> _stockCache = {};

  // 캐시에 넣기 (seed/import, list/get, upsert 이후에 호출)
  void _cacheItem(Item it) {
    _itemsById[it.id] = it;
    _stockCache[it.id] = it.qty; // 최신 qty로 동기 캐시
  }
  void _cacheItems(Iterable<Item> list) {
    for (final it in list) {
      _cacheItem(it);
    }
  }

  Item? _cachedItemOrNull(String id) => _itemsById[id];

  // ─── BOM 캐시(동기 finishedBomOf / semiBomOf 지원) ───
  final Map<String, List<BomRow>> _bomFinishedCache = {};
  final Map<String, List<BomRow>> _bomSemiCache = {};

  void _cacheBomRows(String parentId, List<BomRow> rows) {
    // parentId 기준으로 root별로 분류해서 저장
    final finished = <BomRow>[];
    final semi = <BomRow>[];
    for (final r in rows) {
      if (r.root == BomRoot.finished) finished.add(r);
      else if (r.root == BomRoot.semi) semi.add(r);
    }
    if (finished.isNotEmpty || _bomFinishedCache.containsKey(parentId)) {
      _bomFinishedCache[parentId] = finished;
    }
    if (semi.isNotEmpty || _bomSemiCache.containsKey(parentId)) {
      _bomSemiCache[parentId] = semi;
    }
  }



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
    final list = rows.map((r) => r.toDomain()).toList();
    _cacheItems(list);                 // ✅ 캐시에 저장
    return list;

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

    final list = rows.map((e) => e.toDomain()).toList();
    _cacheItems(list);          // ← 추가
    return list;
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
    final list = rows.map((r) => r.readTable(db.items).toDomain()).toList();
    _cacheItems(list);          // ← 추가
    return list;

  }

  // 폴더 경로 기반 아이템 조회 (StockBrowser에서 사용)
  // l1/l2/l3는 item_paths 테이블의 l1Id/l2Id/l3Id와 매칭
  // recursive=false 이면 "딱 그 깊이"에 있는 아이템만, true면 하위까지 포함
  Future<List<Item>> listItemsByFolderPath({
    String? l1,
    String? l2,
    String? l3,
    bool recursive = true,
  }) async {
    final join = db.select(db.items).join([
      innerJoin(
        db.itemPaths,
        db.itemPaths.itemId.equalsExp(db.items.id),
      ),
    ]);

    // 경로 필터
    if (l1 != null) {
      join.where(db.itemPaths.l1Id.equals(l1));
    }
    if (l2 != null) {
      join.where(db.itemPaths.l2Id.equals(l2));
    }
    if (l3 != null) {
      join.where(db.itemPaths.l3Id.equals(l3));
    }

    // recursive=false 일 때는 "바로 아래"만 가져오도록 deeper 레벨은 null 조건
    if (!recursive) {
      if (l3 != null) {
        // l3까지 지정됐으면 더 내려갈 레벨이 없으니 추가 조건 없음
      } else if (l2 != null) {
        // L2까지만 지정 → L3는 null인 것만
        join.where(db.itemPaths.l3Id.isNull());
      } else if (l1 != null) {
        // L1만 지정 → L2/L3 둘 다 null인 것만
        join.where(
          db.itemPaths.l2Id.isNull() & db.itemPaths.l3Id.isNull(),
        );
      } else {
        // 루트에서 recursive=false로 부르면, 아예 어떤 폴더도 없는 아이템만
        join.where(
          db.itemPaths.l1Id.isNull() &
          db.itemPaths.l2Id.isNull() &
          db.itemPaths.l3Id.isNull(),
        );
      }
    }

    final rows = await join.get();
    final list = rows.map((r) => r.readTable(db.items).toDomain()).toList();
    _cacheItems(list);          // ← 추가
    return list;


  }

  @override
  Future<Item?> getItem(String id) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final it = row?.toDomain();
    if (it != null) _cacheItem(it);  // ✅ 캐시 갱신
    return it;
  }




  @override
  Future<void> upsertItem(Item item) async {
    await db.into(db.items).insertOnConflictUpdate(item.toCompanion());
    await _updateItemPaths(item);
    // DB write 이후
    final fresh = await getItem(item.id);  // 새로 읽어 domain으로
    if (fresh != null) _cacheItem(fresh);  // ✅ 캐시 갱신

  }
  Future<void> upsertItemWithPath(
      Item item,
      String? l1,
      String? l2,
      String? l3,
      ) async {
    await db.transaction(() async {
      // 1) items 테이블 upsert
      await db.into(db.items).insertOnConflictUpdate(item.toCompanion());

      // 2) 실제 사용할 경로 확정
      final effL1 = l1 ?? (item.folder.isNotEmpty ? item.folder : null);
      final effL2 = l2 ?? item.subfolder;
      final effL3 = l3 ?? item.subsubfolder;

      // 3) 폴더는 seed에서 생성된다고 가정 → 여기서는 folders 안 건드림

      // 4) item_paths upsert
      await db.into(db.itemPaths).insertOnConflictUpdate(
        ItemPathsCompanion(
          itemId: Value(item.id),
          l1Id: Value(effL1),
          l2Id: Value(effL2),
          l3Id: Value(effL3),
        ),
      );
      // DB write 이후
      final fresh = await getItem(item.id);  // 새로 읽어 domain으로
      if (fresh != null) _cacheItem(fresh);  // ✅ 캐시 갱신

    });
  }
  Future<void> _updateItemPaths(Item item) async {
    // 폴더 정보가 없으면 경로를 비워둔다.
    if (item.folder.isEmpty) {
      await db.into(db.itemPaths).insertOnConflictUpdate(
        ItemPathsCompanion(
          itemId: Value(item.id),
          l1Id: const Value(null),
          l2Id: const Value(null),
          l3Id: const Value(null),
        ),
      );
      return;
    }

    final l1Name = item.folder;        // "Finished" / "Raw" / "SemiFinished"
    final l2Name = item.subfolder;     // 예: "4seasons"
    final l3Name = item.subsubfolder;  // 예: "rouen_gray"

    // ✅ 시드와 동일한 규칙으로 id 생성
    final l1Id = l1Name; // 루트는 그냥 이름 = id

    String? l2Id;
    if (l2Name != null && l2Name.isNotEmpty) {
      l2Id = '$l1Id-$l2Name'; // Finished-4seasons
    }

    String? l3Id;
    if (l3Name != null && l3Name.isNotEmpty) {
      if (l2Id != null) {
        l3Id = '$l2Id-$l3Name'; // Finished-4seasons-rouen_gray
      } else {
        l3Id = '$l1Id-$l3Name'; // (중간 단계 없이 바로 2단계로 가는 특수 케이스)
      }
    }

    // 폴더 테이블에 해당 경로가 있는지 보장
    await _ensureFolderPath(
      l1: l1Name,
      l2: l2Name,
      l3: l3Name,
    );

    // item_paths 에는 **폴더 id** (위에서 만든 l1Id/l2Id/l3Id)를 저장
    final row = ItemPathsCompanion(
      itemId: Value(item.id),
      l1Id: Value(l1Id),
      l2Id: Value(l2Id),
      l3Id: Value(l3Id),
    );

    await db.into(db.itemPaths).insertOnConflictUpdate(row);
  }



  @override
  Future<void> deleteItem(String id) async {
    await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
    await (db.delete(db.itemPaths)..where((t) => t.itemId.equals(id))).go();
    _itemsById.remove(id);
    _stockCache.remove(id);

  }

  /// 아이템 즐겨찾기 추가
  Future<void> toggleFavorite(String itemId, bool value) async {
    await (db.update(db.items)
      ..where((t) => t.id.equals(itemId)))
        .write(ItemsCompanion(isFavorite: Value(value)));
  }

  @override
  Stream<List<Item>> watchItems({String? keyword}) {
    final q = db.select(db.items);
    if (keyword != null && keyword.isNotEmpty) {
      // name/sku LIKE 검색 예시
      final like = '%${keyword.replaceAll('%', r'\%')}%';
      q.where((t) => t.name.like(like) | t.sku.like(like));
    }
    // 생성된 확장 메서드 r.toDomain() 사용
        return q.watch().map((rows) {
          final list = rows.map((r) => r.toDomain()).toList();
          _cacheItems(list); // 선택: 캐시 최신화
          return list;
        });
  }



  // ================================================================
  // =============== FOLDER TREE REPO ===============================
  // ================================================================
// 📁 폴더 저장 (SeedImporter에서 사용)
  @override
  Future<void> upsertFolderNode(FolderNode node) async {
    // ⚠️ 여기는 app_database.dart에 정의한 `folders` 테이블 컬럼 이름에 맞게 수정해야 함
    await db.into(db.folders).insertOnConflictUpdate(
      FoldersCompanion(
        id: Value(node.id),
        name: Value(node.name),
        parentId: Value(node.parentId), // 루트면 null
        depth: Value(node.depth),
        // 만약 FolderNode에 path / sortOrder 같은 필드가 있다면 여기서 추가:
        // path: Value(node.path),
        // sortOrder: Value(node.sortOrder ?? 0),
      ),
    );
  }

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
  FolderNode? folderById(String id) {
    // 지금은 간단히 placeholder로 둠
    // 나중에 필요하면 캐시 기반으로 개선 가능
    return FolderNode(
      id: id,
      name: id,
      parentId: null,
      depth: 0,
      order: 0,
    );
  }



  @override
  Future<FolderNode> createFolderNode({
    required String? parentId,
    required String name,
  }) async {
    final parentRow = parentId == null
        ? null
        : await (db.select(db.folders)
      ..where((t) => t.id.equals(parentId!)))
        .getSingleOrNull();

    // 🔧 루트는 depth = 0, 자식은 parent.depth + 1
    final depth = parentRow != null ? parentRow.depth + 1 : 0;

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

  Future<void> _ensureFolderPath({
    required String l1,
    String? l2,
    String? l3,
  }) async {
    final l1Id = l1; // 루트 id
    final String? l2Id =
    (l2 != null && l2.isNotEmpty) ? '$l1Id-$l2' : null;
    final String? l3Id =
    (l3 != null && l3.isNotEmpty && l2Id != null) ? '$l2Id-$l3' : null;

    // depth 0: 루트
    await db.into(db.folders).insertOnConflictUpdate(
      FoldersCompanion(
        id: Value(l1Id),
        name: Value(l1),
        parentId: const Value(null),
        depth: const Value(0),
      ),
    );

    // depth 1: L2
    if (l2Id != null) {
      await db.into(db.folders).insertOnConflictUpdate(
        FoldersCompanion(
          id: Value(l2Id),
          name: Value(l2!),      // 사용자에게 보이는 이름은 "4seasons" 그대로
          parentId: Value(l1Id),
          depth: const Value(1),
        ),
      );
    }

    // depth 2: L3
    if (l3Id != null) {
      await db.into(db.folders).insertOnConflictUpdate(
        FoldersCompanion(
          id: Value(l3Id),
          name: Value(l3!),      // "rouen_gray" 등
          parentId: Value(l2Id),
          depth: const Value(2),
        ),
      );
    }
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
    _cacheItems(itemsFound);    // ← 추가
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
      final newParentId =
      req.pathIds.isNotEmpty ? req.pathIds.last : null;
      final newDepth = req.pathIds.length; // 🔧 핵심

      await (db.update(db.folders)..where((t) => t.id.equals(req.id))).write(
        FoldersCompanion(
          parentId: Value(newParentId),
          depth: Value(newDepth),
        ),
      );
      return;
    }

    throw UnsupportedError('Unknown entity kind');
  }

// DriftUnifiedRepo 안에

  @override
  Future<void> upsertLots(String itemId, List<Lot> lots) async {
    if (lots.isEmpty) return;

    // 안전하게: lot 안의 itemId가 비어 있으면 인자로 받은 itemId를 채워줄 수도 있음
    List<Lot> normalized = lots.map((lot) {
      if (lot.itemId.isNotEmpty && lot.itemId != itemId) {
        // itemId가 다른 경우는 경고만 찍고 lot.itemId를 신뢰
        return lot;
      }
      if (lot.itemId.isNotEmpty) return lot;
      // lot.itemId가 비어 있는 경우라면 itemId를 채워서 새 Lot 생성
      return Lot(
        itemId: itemId,
        lotNo: lot.lotNo,
        receivedQtyRoll: lot.receivedQtyRoll,
        measuredLengthM: lot.measuredLengthM,
        usableQtyM: lot.usableQtyM,
        status: lot.status,
        receivedAt: lot.receivedAt,
      );
    }).toList();

    String _lotId(Lot lot) => '${lot.itemId}__${lot.lotNo}';

    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.lots,
        normalized.map((lot) {
          return LotsCompanion(
            id: Value(_lotId(lot)),
            itemId: Value(lot.itemId),
            lotNo: Value(lot.lotNo),
            receivedQtyRoll: Value(lot.receivedQtyRoll),
            measuredLengthM: Value(lot.measuredLengthM),
            usableQtyM: Value(lot.usableQtyM),
            status: Value(lot.status),
            receivedAt: Value(lot.receivedAt.toIso8601String()),
          );
        }).toList(),
      );
    });
  }



  // ----------------------------------------------------------
  // BOM — finished / semi (sync 미지원 → 예외)
  // ----------------------------------------------------------
  @override
  List<BomRow> finishedBomOf(String finishedItemId) {
    // 캐시에 없으면 빈 리스트(보수적) 반환
    return _bomFinishedCache[finishedItemId] ?? const <BomRow>[];
  }

  @override
  List<BomRow> semiBomOf(String semiItemId) {
    return _bomSemiCache[semiItemId] ?? const <BomRow>[];
  }



  @override
  Future<void> upsertFinishedBom(String finishedItemId, List<BomRow> rows) async {
    await (db.delete(db.bomRows)
      ..where((t) => t.parentItemId.equals(finishedItemId))
      ..where((t) => t.root.equals(BomRoot.finished.name)))
        .go();

    for (final r in rows) {
      await db.into(db.bomRows).insertOnConflictUpdate(
        r.copyWith(root: BomRoot.finished, parentItemId: finishedItemId).toCompanion(),
      );
    }
    // ✅ 캐시 갱신
    _bomFinishedCache[finishedItemId] = rows;
  }

  @override
  Future<void> upsertSemiBom(String semiItemId, List<BomRow> rows) async {
    await (db.delete(db.bomRows)
      ..where((t) => t.parentItemId.equals(semiItemId))
      ..where((t) => t.root.equals(BomRoot.semi.name)))
        .go();

    for (final r in rows) {
      await db.into(db.bomRows).insertOnConflictUpdate(
        r.copyWith(root: BomRoot.semi, parentItemId: semiItemId).toCompanion(),
      );
    }
    // ✅ 캐시 갱신
    _bomSemiCache[semiItemId] = rows;
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
    _stockCache[itemId] = (await getItem(itemId))?.qty ?? _stockCache[itemId] ?? 0;
    await _refreshTxnSnapshot(); // 👈 추가

  }

  Stream<List<Txn>> watchTxns() {
    final q = db.select(db.txns)
      ..orderBy([(t) => OrderingTerm.desc(t.ts)]);
    return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
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
    final fresh = await getItem(itemId);
    if (fresh != null) _cacheItem(fresh);
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
// 출고 단위 힌트: unitOut 우선, 없으면 unit
  String? hintUnitOut(String id) {
    final it = _cachedItemOrNull(id);
    if (it == null) return null;
    final uo = it.unitOut.trim();
    if (uo.isNotEmpty) return uo;
    final u = it.unit.trim();
    return u.isNotEmpty ? u : null;
  }

// EA(개수) 폴백 힌트: stockHints.qty
  double? hintQtyOut(String id) {
    final it = _cachedItemOrNull(id);
    final h = it?.stockHints;
    if (h == null) return null;
    final v = h.qty;
    if (v != null && v > 0) return v.toDouble();
    return null;
  }

// M(길이) 폴백 힌트: stockHints.usableQtyM
  double? hintUsableMeters(String id) {
    final it = _cachedItemOrNull(id);
    final h = it?.stockHints;
    if (h == null) return null;
    final v = h.usableQtyM;
    if (v != null && v > 0) return v.toDouble();
    return null;
  }


  @override
  int stockOf(String itemId) {
    // 동기 캐시에서 즉시 반환
    final v = _stockCache[itemId];
    return v ?? 0; // 캐시에 없으면 0 (보수적으로)
  }



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
    notifyListeners();
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
    notifyListeners();
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
    _stockCache[itemId] = (await getItem(itemId))?.qty ?? _stockCache[itemId] ?? 0;
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
    final rows = await (db.select(db.bomRows)
      ..where((t) => t.parentItemId.equals(parentItemId)))
        .get();
    final list = rows.map((r) => r.toDomain()).toList();
    _cacheBomRows(parentItemId, list);   // ← 캐시에 저장
    return list;
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
  Future<List<Order>> listOrders({bool includeDeleted = false}) async {
    final q = db.select(db.orders);

    if (!includeDeleted) {
      q.where((t) => t.isDeleted.equals(false));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.date)]);

    final rows = await q.get();

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

  // ✅ soft delete: isDeleted=true, updatedAt=now ISO8601
  @override
  Future<void> softDeleteOrder(String orderId) async {
    final nowIso = DateTime.now().toIso8601String();
    await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(nowIso),
        deletedAt: Value(nowIso),
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

// ✅ restore: isDeleted=false, updatedAt=now ISO8601
    @override
    Future<void> restoreOrder(String orderId) async {
      final nowIso = DateTime.now().toIso8601String();
      await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(
        OrdersCompanion(
          isDeleted: const Value(false),
          updatedAt: Value(nowIso),
          deletedAt: const Value<String?>(null), // ⬅️ 복구 시 삭제일자 제거

        ),
      );


    // 통합 휴지통 레지스트리 쓰는 경우 함께 정리
    // await (db.delete(db.deletedRegistry)
    //        ..where((t) => t.kind.equals('order') & t.entityId.equals(orderId)))
    //      .go();
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
    final nowIso = DateTime.now().toIso8601String();
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(nowIso),
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
  Future<void> restorePurchaseOrder(String id) async {
    final nowIso = DateTime.now().toIso8601String();
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(nowIso),
      ),
    );
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

  Future<void> debugPrintAllFolders() async {
    final rows = await (db.select(db.folders)
      ..orderBy([(t) => OrderingTerm.asc(t.depth), (t) => OrderingTerm.asc(t.name)]))
        .get();

    debugPrint('===== FOLDERS TABLE DUMP =====');
    for (final r in rows) {
      debugPrint(
        '[Folder] id=${r.id}, name=${r.name}, parentId=${r.parentId}, depth=${r.depth}, order=${r.order}',
      );
    }

    final roots = await (db.select(db.folders)
      ..where((t) => t.parentId.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    debugPrint('===== ROOT FOLDERS (parentId IS NULL) =====');
    for (final r in roots) {
      debugPrint('[Root] id=${r.id}, name=${r.name}, depth=${r.depth}');
    }
  }

}
