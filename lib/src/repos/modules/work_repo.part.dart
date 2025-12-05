part of '../drift_unified_repo.dart';

mixin WorkRepoMixin on _RepoCore implements WorkRepo{
@override
Future<String> createWork(Work w) async {
  await db.into(db.works).insert(w.toCompanion());
  return w.id;
}
@override
Future<String> createWorkForOrder({
  required String orderId,
  required String itemId,
  required int qty,
}) async {
  final id = const Uuid().v4();
  final now = DateTime.now();

  final w = Work(
    id: id,
    itemId: itemId,
    qty: qty,
    orderId: orderId,
    status: WorkStatus.planned,
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
  );

  await db.into(db.works).insert(w.toCompanion());
  return id;
}
@override
Future<Work?> findWorkForOrderLine(String orderId, String itemId) async {
  final row = await (db.select(db.works)
    ..where((t) => t.orderId.equals(orderId))
    ..where((t) => t.itemId.equals(itemId))
    ..where((t) => t.isDeleted.equals(false)))
      .getSingleOrNull();

  return row?.toDomain();
}



@override
Future<Work?> getWorkById(String id) async {
  final row = await (db.select(db.works)..where((t) => t.id.equals(id))).getSingleOrNull();
  return row?.toDomain();
}
@override
Stream<List<Work>> watchWorksByOrderAndItem(String orderId, String itemId) {
  final q = (db.select(db.works)
    ..where((t) => t.orderId.equals(orderId))
    ..where((t) => t.itemId.equals(itemId))
    ..where((t) => t.isDeleted.equals(false))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]));
  return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
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
