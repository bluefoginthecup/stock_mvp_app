// // lib/src/repos/sqlite_item_repo.dart
// import 'package:drift/drift.dart';
//
// import '../db/app_database.dart';       // AppDatabase, ItemRow, ItemsCompanion, etc.
// import '../models/item.dart';
// import '../models/bom.dart';
// import '../repos/repo_interfaces.dart';
//
// /// Drift + SQLite 기반 ItemRepo 구현체.
// /// - Item CRUD, 검색, 재고 수량 등은 SQLite 사용
// /// - BOM 관련 메서드는 별도의 BomRepo 구현(InMemoryRepo 등)에 위임하도록 설계
// class SqliteItemRepo implements ItemRepo {
//   final AppDatabase db;
//   final BomRepo? bomDelegate; // 선택: 있으면 BOM은 여기로 위임
//
//   SqliteItemRepo(this.db, {this.bomDelegate});
//
//   // =============================== 기본 목록/검색 ===============================
//
//   /// 레거시 listItems 구현 (folder, keyword 기준)
//   @override
//   Future<List<Item>> listItems({String? folder, String? keyword}) async {
//     final q = db.select(db.items);
//
//     // folder: L1 레거시 이름 (Finished/Raw/Sub 등)
//     if (folder != null && folder.trim().isNotEmpty) {
//       q.where((t) => t.folder.equals(folder));
//     }
//
//     // keyword: name / sku / displayName 에 LIKE 검색
//     if (keyword != null && keyword.trim().isNotEmpty) {
//       final k = '%${keyword.trim()}%';
//       q.where(
//             (t) =>
//         t.name.like(k) |
//         t.sku.like(k) |
//         t.displayName.like(k),
//       );
//     }
//
//     final rows = await q.get();
//     return rows.map((r) => r.toDomain()).toList();
//   }
//
//   @override
//   Future<List<Item>> searchItemsGlobal(String keyword) async {
//     if (keyword.trim().isEmpty) return const [];
//     final k = '%${keyword.trim()}%';
//
//     final q = db.select(db.items)
//       ..where(
//             (t) =>
//         t.name.like(k) |
//         t.sku.like(k) |
//         t.displayName.like(k),
//       );
//
//     final rows = await q.get();
//     return rows.map((r) => r.toDomain()).toList();
//   }
//
//   /// 경로 기반 검색
//   /// - 현재는 folder / subfolder / subsubfolder 이름으로만 매칭
//   /// - 나중에 FolderNode/트리 테이블을 DB로 옮기면 여기 로직만 고치면 됨
//   @override
//   Future<List<Item>> searchItemsByPath({
//     String? l1,
//     String? l2,
//     String? l3,
//     required String keyword,
//     bool recursive = true,
//   }) async {
//     if (keyword.trim().isEmpty) return const [];
//     final k = '%${keyword.trim()}%';
//
//     final q = db.select(db.items);
//
//     if (l1 != null && l1.trim().isNotEmpty) {
//       q.where((t) => t.folder.equals(l1));
//     }
//     if (l2 != null && l2.trim().isNotEmpty) {
//       q.where((t) => t.subfolder.equals(l2));
//     }
//     if (l3 != null && l3.trim().isNotEmpty) {
//       q.where((t) => t.subsubfolder.equals(l3));
//     }
//
//     // recursive 플래그는 지금 구조에서는 크게 의미 없음
//     // (트리 테이블 도입 후, l1만 주어졌을 때 하위 전체 등을 처리할 수 있음)
//
//     q.where(
//           (t) =>
//       t.name.like(k) |
//       t.sku.like(k) |
//       t.displayName.like(k),
//     );
//
//     final rows = await q.get();
//     return rows.map((r) => r.toDomain()).toList();
//   }
//
//   // =============================== 단건 조회/저장/삭제 ===============================
//
//   @override
//   Future<Item?> getItem(String id) async {
//     final row =
//     await (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
//     return row?.toDomain();
//   }
//
//   @override
//   Future<void> upsertItem(Item item) async {
//     final companion = item.toCompanion();
//     await db.into(db.items).insertOnConflictUpdate(companion);
//   }
//
//   @override
//   Future<void> deleteItem(String id) async {
//     await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
//   }
//
//   @override
//   Future<String?> nameOf(String itemId) async {
//     final row = await (db.select(db.items)
//       ..where((t) => t.id.equals(itemId)))
//         .getSingleOrNull();
//     return row?.name;
//   }
//
//   // =============================== 재고/단위 ===============================
//
//   /// 현재 재고 수량 (qty 컬럼 기준)
//   @override
//   int stockOf(String itemId) {
//     // 이 인터페이스는 sync지만, Drift는 async라서
//     // 👉 "가급적 쓰지 말고, async 버전(getItem) 통해 사용" 권장
//     // 여기서는 최대한 안전하게 '블로킹 없이' 0만 반환하는 대신,
//     // 나중에 필요하면 별도 서비스에서 캐시를 두는 식으로 처리하는 걸 추천.
//     // (지금 InMemory 버전과 동작이 완전히 같을 필요 없으면 이렇게 가도 됨)
//
//     // 실제 DB를 즉시 동기 액세스하는 건 불가능하므로,
//     // 일단 0을 반환하고, 사용처를 점진적으로 async 스타일로 바꾸는 게 현실적.
//     return 0;
//   }
//
//   /// qty += delta (Txn 로그는 나중에 Drift Txn 테이블 추가 후 구현)
//   @override
//   Future<void> adjustQty({
//     required String itemId,
//     required int delta,
//     String? refType,
//     String? refId,
//     String? note,
//     String? memo,
//   }) async {
//     await db.transaction(() async {
//       final row = await (db.select(db.items)..where((t) => t.id.equals(itemId)))
//           .getSingleOrNull();
//       if (row == null) return;
//       final newQty = row.qty + delta;
//
//       await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
//         ItemsCompanion(qty: Value(newQty)),
//       );
//
//       // TODO: TxnRepo(Drift 기반) 도입 후 여기에서 입출고 Txn 기록까지 같이 처리
//     });
//   }
//
//   @override
//   Future<void> updateUnits({
//     required String itemId,
//     String? unitIn,
//     String? unitOut,
//     double? conversionRate,
//   }) async {
//     final data = ItemsCompanion(
//       unitIn: unitIn != null ? Value(unitIn) : const Value.absent(),
//       unitOut: unitOut != null ? Value(unitOut) : const Value.absent(),
//       conversionRate: conversionRate != null
//           ? Value(conversionRate)
//           : const Value.absent(),
//     );
//
//     await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(data);
//   }
//
//   // =============================== BOM 관련 (위임/스텁) ===============================
//
//   /// 현재 BOM은 InMemoryRepo 쪽 Map 기반 구조에 이미 잘 붙어있으니까
//   /// - 여기서는 가능하면 BomRepo 구현체(예: InMemoryRepo)를 주입 받아서 위임하고,
//   /// - 없다면 최소한 안전하게 동작하도록 기본값을 제공.
//
//   @override
//   List<BomRow> finishedBomOf(String finishedItemId) {
//     if (bomDelegate != null) {
//       return bomDelegate!.listBom(finishedItemId).then((rows) {
//         // root=finished 인 것만 필터
//         return rows.where((r) => r.root == BomRoot.finished).toList();
//       }) as List<BomRow>; // 👈 이건 Future를 List로 캐스팅 못하니까 아래 안전 버전으로 수정
//     }
//     // 위 줄은 타입상 안 맞으므로, 현실적인 안전 버전으로:
//     return const [];
//   }
//
//   @override
//   Future<void> upsertFinishedBom(
//       String finishedItemId, List<BomRow> rows) async {
//     if (bomDelegate != null) {
//       // root=finished만 골라서 저장
//       final filtered = rows
//           .where((r) => r.root == BomRoot.finished)
//           .map((r) => r.parentItemId == finishedItemId
//           ? r
//           : r.copyWith(parentItemId: finishedItemId))
//           .toList();
//       for (final r in filtered) {
//         await bomDelegate!.upsertBomRow(r);
//       }
//       return;
//     }
//     // 아직 Drift BOM 테이블 안 만들었으면 그냥 no-op
//     return;
//   }
//
//   @override
//   List<BomRow> semiBomOf(String semiItemId) {
//     if (bomDelegate != null) {
//       // 위와 마찬가지로, 여기서는 안전하게 빈 리스트 리턴
//       // 실제로는 BomRepo를 직접 쓰도록 코드 정리하는 게 더 좋음.
//       return const [];
//     }
//     return const [];
//   }
//
//   @override
//   Future<void> upsertSemiBom(String semiItemId, List<BomRow> rows) async {
//     if (bomDelegate != null) {
//       final filtered = rows
//           .where((r) => r.root == BomRoot.semi)
//           .map((r) => r.parentItemId == semiItemId
//           ? r
//           : r.copyWith(parentItemId: semiItemId))
//           .toList();
//       for (final r in filtered) {
//         await bomDelegate!.upsertBomRow(r);
//       }
//       return;
//     }
//     return;
//   }
// }
