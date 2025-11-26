part of '../drift_unified_repo.dart';

mixin SupplierRepoMixin on _RepoCore implements SupplierRepo{
@override
Future<List<Supplier>> list({String? q, bool onlyActive = true}) async {
  final query = db.select(db.suppliers);

  if (onlyActive) query.where((t) => t.isActive.equals(true));

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
  final row = await (db.select(db.suppliers)..where((t) => t.id.equals(id))).getSingleOrNull();
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
}
