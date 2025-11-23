// lib/src/repos/modules/bom_repo.part.dart
part of '../drift_unified_repo.dart';

// ⚠️ 여기서는 절대 implements 쓰지 마세요.
// on 절에는 'DriftUnifiedRepo'만 둡니다. (본체의 db/캐시 필드 접근용)
mixin BomRepoMixin on _RepoCore{
  @override
  Future<List<BomRow>> listBom(String parentItemId) async {
    final rows = await (db.select(db.bomRows)
      ..where((t) => t.parentItemId.equals(parentItemId)))
        .get();
    final list = rows.map((r) => r.toDomain()).toList();
    _cacheBomRows(parentItemId, list);  // 본체의 헬퍼 OK
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

  // 캐시 기반 동기 조회
  @override
  List<BomRow> finishedBomOf(String finishedItemId) {
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
    _bomSemiCache[semiItemId] = rows;
  }
}
