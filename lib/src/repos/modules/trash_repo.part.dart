// lib/src/repos/modules/trash_repo.part.dart
part of '../drift_unified_repo.dart';

mixin TrashRepoMixin on _RepoCore implements TrashRepo {
  @override
  Future<List<TrashEntry>> listTrash() async {
    final List<TrashEntry> all = [];

    // items
    final di = await (db.select(db.items)..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(di.where((r) => r.deletedAt != null).map((r) => TrashEntry(
      id: r.id,
      entityType: 'item',
      title: r.displayName ?? r.name,
      deletedAt: DateTime.parse(r.deletedAt!),
    )));

    // orders
    final dor = await (db.select(db.orders)..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dor.where((r) => r.deletedAt != null).map((r) => TrashEntry(
      id: r.id,
      entityType: 'order',
      title: r.customer ?? r.id,
      deletedAt: DateTime.parse(r.deletedAt!),
    )));

    // txns
    final dtx = await (db.select(db.txns)..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dtx.where((r) => r.deletedAt != null).map((r) => TrashEntry(
      id: r.id,
      entityType: 'txn',
      title: '${r.refType}/${r.refId} (${r.qty})',
      deletedAt: DateTime.parse(r.deletedAt!),
    )));

    // works (title 컬럼 없음 → itemId/qty로 노출)
    final dw = await (db.select(db.works)..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dw.where((r) => r.deletedAt != null).map((r) => TrashEntry(
      id: r.id,
      entityType: 'work',
      title: '${r.itemId} x${r.qty}',
      deletedAt: DateTime.parse(r.deletedAt!),
    )));

    // purchase orders
    final dpo = await (db.select(db.purchaseOrders)..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dpo.where((r) => r.deletedAt != null).map((r) => TrashEntry(
      id: r.id,
      entityType: 'po',
      title: r.supplierName ?? r.id,
      deletedAt: DateTime.parse(r.deletedAt!),
    )));

    all.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return all;
  }

  @override
  Future<void> restore(String entityType, String id) async {
    switch (entityType) {
      case 'item':
        await (db.update(db.items)..where((t) => t.id.equals(id))).write(
          const ItemsCompanion(isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
      case 'order':
        await (db.update(db.orders)..where((t) => t.id.equals(id))).write(
          const OrdersCompanion(isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
      case 'txn':
        await (db.update(db.txns)..where((t) => t.id.equals(id))).write(
          const TxnsCompanion(isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
      case 'work':
        await (db.update(db.works)..where((t) => t.id.equals(id))).write(
          const WorksCompanion(isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
      case 'po':
        await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
          const PurchaseOrdersCompanion(isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
    }
    notifyListeners();
  }

  @override
  Future<void> hardDelete(String entityType, String id) async {
    switch (entityType) {
      case 'item':
        await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
        break;
      case 'order':
        await (db.delete(db.orders)..where((t) => t.id.equals(id))).go(); // lines는 CASCADE 가정
        break;
      case 'txn':
        await (db.delete(db.txns)..where((t) => t.id.equals(id))).go();
        break;
      case 'work':
        await (db.delete(db.works)..where((t) => t.id.equals(id))).go();
        break;
      case 'po':
        await (db.delete(db.purchaseOrders)..where((t) => t.id.equals(id))).go(); // lines CASCADE
        break;
    }
    notifyListeners();
  }
}
