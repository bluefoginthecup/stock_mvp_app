part of '../drift_unified_repo.dart';

mixin PurchaseRepoMixin on _RepoCore implements PurchaseOrderRepo {
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
Future<void> updatePurchaseOrderStatus(String id, PurchaseOrderStatus status) async {
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
  final row = await (db.select(db.purchaseOrders)..where((t) => t.id.equals(id))).getSingleOrNull();
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
    await (db.delete(db.purchaseLines)..where((l) => l.orderId.equals(id))).go();
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
    await (db.delete(db.purchaseLines)..where((l) => l.orderId.equals(orderId))).go();
    for (final line in lines) {
      await db.into(db.purchaseLines).insert(line.toCompanion());
    }
  });
}

@override
Future<List<PurchaseLine>> getLines(String orderId) async {
  final rows = await (db.select(db.purchaseLines)..where((l) => l.orderId.equals(orderId))).get();
  return rows.map((r) => r.toDomain()).toList();
}
}
