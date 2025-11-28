// lib/src/repos/modules/bom_repo.part.dart
part of '../drift_unified_repo.dart';

// ⚠️ 여기서는 절대 implements 쓰지 마세요.
// on 절에는 'DriftUnifiedRepo'만 둡니다. (본체의 db/캐시 필드 접근용)
mixin BomRepoMixin on _RepoCore implements BomRepo{
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

        // 🔧 캐시도 함께 갱신 (finished/semi만)
        final parent = row.parentItemId;
        List<BomRow> _up(List<BomRow> curr) {
          final i = curr.indexWhere(
            (e) => e.componentItemId == row.componentItemId && e.kind == row.kind,
          );
          if (i >= 0) {
            final next = [...curr];
            next[i] = row;
            return next;
          }
          return [...curr, row];
        }
        if (row.root == BomRoot.finished) {
          final curr = _bomFinishedCache[parent] ?? const <BomRow>[];
          _bomFinishedCache[parent] = _up(curr);
        } else if (row.root == BomRoot.semi) {
          final curr = _bomSemiCache[parent] ?? const <BomRow>[];
          _bomSemiCache[parent] = _up(curr);
        }
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
    // 🔧 캐시에서도 제거 (finished/semi만)
        final rootStr = parts[0]; // e.g. BomRoot.finished.name
        final parent  = parts[1];
        final comp    = parts[2];
        final kindStr = parts[3]; // e.g. BomKind.raw.name
        void _remove(List<BomRow>? list) {
          if (list == null) return;
          list.removeWhere(
            (r) => r.componentItemId == comp && r.kind.name == kindStr,
          );
        }
        if (rootStr == BomRoot.finished.name) {
          _remove(_bomFinishedCache[parent]);
        } else if (rootStr == BomRoot.semi.name) {
          _remove(_bomSemiCache[parent]);
        }
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
