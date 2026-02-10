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
    doneQty: 0,
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
Stream<Work?> watchWorkById(String id) {
  final q = (db.select(db.works)..where((t) => t.id.equals(id)));
  return q.watchSingleOrNull().map((row) => row?.toDomain());
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
Future<void> updateWorkDoneQty(String id, int doneQty) async {
  assert(doneQty >= 0);
  await (db.update(db.works)..where((t) => t.id.equals(id))).write(
    WorksCompanion(
      doneQty: Value(doneQty),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ),
  );
}


@override
Future<void> addWorkDoneQty(String id, int delta) async {
  assert(delta > 0);

  final row = await (db.select(db.works)..where((t) => t.id.equals(id))).getSingleOrNull();
  if (row == null) return;

  final next = row.doneQty + delta;

  await (db.update(db.works)..where((t) => t.id.equals(id))).write(
    WorksCompanion(
      doneQty: Value(next),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ),
  );
}


@override
Future<void> updateWorkProgress({
  required String id,
  required WorkStatus status,
  DateTime? startedAt,
  DateTime? finishedAt,
}) async {
  final nowIso = DateTime.now().toIso8601String();

  await (db.update(db.works)..where((t) => t.id.equals(id))).write(
    WorksCompanion(
      status: Value(status.name),
      updatedAt: Value(nowIso),
      startedAt: startedAt != null
          ? Value(startedAt.toIso8601String())
          : const Value.absent(),
      finishedAt: finishedAt != null
          ? Value(finishedAt.toIso8601String())
          : const Value.absent(),
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
