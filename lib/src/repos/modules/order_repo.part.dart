part of '../drift_unified_repo.dart';

mixin OrderRepoMixin on _RepoCore implements OrderRepo{
@override
Future<List<Order>> listOrders({bool includeDeleted = false}) async {
  final q = db.select(db.orders);
  if (!includeDeleted) q.where((t) => t.isDeleted.equals(false));
  q.orderBy([(t) => OrderingTerm.desc(t.date)]);

  final rows = await q.get();
  final list = <Order>[];

  for (final o in rows) {
    final lineRows = await (db.select(db.orderLines)
      ..where((l) => l.orderId.equals(o.id)))
        .get();
    list.add(o.toDomain(lineRows.map((r) => r.toDomain()).toList()));
  }
  return list;
}

@override
Stream<List<Order>> watchOrders({bool includeDeleted = false}) {
  final o = db.orders;
  final l = db.orderLines;

  final joined = db.select(o).join([
    leftOuterJoin(l, l.orderId.equalsExp(o.id)),
  ]);

  if (!includeDeleted) joined.where(o.isDeleted.equals(false));
  joined.orderBy([OrderingTerm.desc(o.date)]);

  return joined.watch().map((rows) {
    final map = <String, (OrderRow, List<OrderLineRow>)>{};
    for (final r in rows) {
      final header = r.readTable(o);
      final line = r.readTableOrNull(l);
      final entry = map.putIfAbsent(header.id, () => (header, <OrderLineRow>[]));
      if (line != null) entry.$2.add(line);
    }
    return map.values.map((tuple) {
      final header = tuple.$1;
      final lines = tuple.$2.map((e) => e.toDomain()).toList();
      return header.toDomain(lines);
    }).toList();
  });
}

@override
Future<Order?> getOrder(String id) async {
  final row = await (db.select(db.orders)..where((t) => t.id.equals(id))).getSingleOrNull();
  if (row == null) return null;
  final lineRows =
  await (db.select(db.orderLines)..where((l) => l.orderId.equals(id))).get();
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
        updatedAt: Value(order.updatedAt != null ? order.updatedAt.toIso8601String() : null),
      ),
    );

    await (db.delete(db.orderLines)..where((l) => l.orderId.equals(order.id))).go();
    for (final line in order.lines) {
      await db.into(db.orderLines).insert(line.toCompanion(order.id));
    }
  });
}

@override
Future<String?> customerNameOf(String orderId) async {
  final row = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingleOrNull();
  return row?.customer;
}

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
    await (db.delete(db.orderLines)..where((l) => l.orderId.equals(orderId))).go();
    await (db.delete(db.orders)..where((t) => t.id.equals(orderId))).go();
  });
}

@override
Future<void> restoreOrder(String orderId) async {
  final nowIso = DateTime.now().toIso8601String();
  await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(
    OrdersCompanion(
      isDeleted: const Value(false),
      updatedAt: Value(nowIso),
      deletedAt: const Value<String?>(null),
    ),
  );
}
}
