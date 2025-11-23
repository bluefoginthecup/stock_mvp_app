part of '../drift_unified_repo.dart';

mixin WorkRepoMixin on _RepoCore{
@override
Future<String> createWork(Work w) async {
  await db.into(db.works).insert(w.toCompanion());
  return w.id;
}

@override
Future<Work?> getWorkById(String id) async {
  final row = await (db.select(db.works)..where((t) => t.id.equals(id))).getSingleOrNull();
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
  await (db.update(db.works)..where((t) => t.id.equals(w.id))).write(w.toCompanion());
}

@override
Future<void> completeWork(String id) => updateWorkStatus(id, WorkStatus.done);

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
Future<void> cancelWork(String id) => updateWorkStatus(id, WorkStatus.canceled);

@override
Future<void> softDeleteWork(String workId) async {
  await (db.update(db.works)..where((t) => t.id.equals(workId))).write(
    WorksCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ),
  );
}

@override
Future<void> hardDeleteWork(String workId) async {
  await (db.delete(db.works)..where((t) => t.id.equals(workId))).go();
}
}
