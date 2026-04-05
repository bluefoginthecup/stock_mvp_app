// lib/src/repos/modules/trash_repo.part.dart
part of '../drift_unified_repo.dart';

mixin TrashRepoMixin on _RepoCore implements TrashRepo {
  @override
  Future<List<TrashEntry>> listTrash() async {
    final List<TrashEntry> all = [];

    // items
    final di = await (db.select(db.items)
      ..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(di.where((r) => r.deletedAt != null).map((r) =>
        TrashEntry(
          id: r.id,
          entityType: 'item',
          title: r.displayName ?? r.name,
          deletedAt: DateTime.parse(r.deletedAt!),
        )));

    //folders
    final df = await (db.select(db.folders)
      ..where((t) => t.isDeleted.equals(true)))
        .get();

    all.addAll(df.where((r) => r.deletedAt != null).map((r) =>
        TrashEntry(
          id: r.id,
          entityType: 'folder',
          title: r.name,
          deletedAt: DateTime.parse(r.deletedAt!),
        )));

    // orders
    final dor = await (db.select(db.orders)
      ..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dor.where((r) => r.deletedAt != null).map((r) =>
        TrashEntry(
          id: r.id,
          entityType: 'order',
          title: r.customer ?? r.id,
          deletedAt: DateTime.parse(r.deletedAt!),
        )));

    // txns
    final dtx = await (db.select(db.txns)
      ..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dtx.where((r) => r.deletedAt != null).map((r) =>
        TrashEntry(
          id: r.id,
          entityType: 'txn',
          title: '${r.refType}/${r.refId} (${r.qty})',
          deletedAt: DateTime.parse(r.deletedAt!),
        )));

    // works (title 컬럼 없음 → itemId/qty로 노출)
    final dw = await (db.select(db.works)
      ..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dw.where((r) => r.deletedAt != null).map((r) =>
        TrashEntry(
          id: r.id,
          entityType: 'work',
          title: '${r.itemId} x${r.qty}',
          deletedAt: DateTime.parse(r.deletedAt!),
        )));

    // purchase orders
    final dpo = await (db.select(db.purchaseOrders)
      ..where((t) => t.isDeleted.equals(true))).get();
    all.addAll(dpo.where((r) => r.deletedAt != null).map((r) =>
        TrashEntry(
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
    // 🔥 ITEM 복구 (핵심)
      case 'item':
        await _restoreItem(id);
        break;

    // 🔥 FOLDER 복구
      case 'folder':
        await _restoreFolder(id);
        break;


      case 'order':
        await (db.update(db.orders)
          ..where((t) => t.id.equals(id))).write(
          const OrdersCompanion(
              isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
      case 'txn':
        await (db.update(db.txns)
          ..where((t) => t.id.equals(id))).write(
          const TxnsCompanion(isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
      case 'work':
        await (db.update(db.works)
          ..where((t) => t.id.equals(id))).write(
          const WorksCompanion(isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
      case 'po':
        await (db.update(db.purchaseOrders)
          ..where((t) => t.id.equals(id))).write(
          const PurchaseOrdersCompanion(
              isDeleted: Value(false), deletedAt: Value(null)),
        );
        break;
    }
    notifyListeners();
  }

  @override
  Future<void> hardDelete(String entityType, String id) async {
    switch (entityType) {
      case 'item':
      // 🔥 RESTRICT 테이블 먼저 삭제
        await (db.delete(db.orderLines)
          ..where((t) => t.itemId.equals(id)))
            .go();

        await (db.delete(db.purchaseLines)
          ..where((t) => t.itemId.equals(id)))
            .go();

        await (db.delete(db.works)
          ..where((t) => t.itemId.equals(id)))
            .go();


        // 🔥 1. 참조 데이터 먼저 삭제
        await (db.delete(db.txns)
          ..where((t) => t.itemId.equals(id)))
            .go();

        await (db.delete(db.works)
          ..where((t) => t.itemId.equals(id)))
            .go();

        // 🔥 2. 마지막에 item 삭제
        await (db.delete(db.items)
          ..where((t) => t.id.equals(id))).go();
        break;

      case 'folder':
      // 🔥 1. 이 폴더에 속한 item 찾기
        final items = await (db.select(db.itemPaths)
          ..where((t) =>
          t.l1Id.equals(id) |
          t.l2Id.equals(id) |
          t.l3Id.equals(id)))
            .get();

        // 🔥 2. 해당 item 전부 삭제
        for (final p in items) {
          await hardDelete('item', p.itemId);
        }

        // 🔥 3. 마지막에 폴더 삭제
        await (db.delete(db.folders)
          ..where((t) => t.id.equals(id))).go();
        break;

      case 'order':
        await (db.delete(db.orders)
          ..where((t) => t.id.equals(id))).go(); // lines는 CASCADE 가정
        break;
      case 'txn':
        await (db.delete(db.txns)
          ..where((t) => t.id.equals(id))).go();
        break;
      case 'work':
        await (db.delete(db.works)
          ..where((t) => t.id.equals(id))).go();
        break;
      case 'po':
        await (db.delete(db.purchaseOrders)
          ..where((t) => t.id.equals(id))).go(); // lines CASCADE
        break;
    }
    notifyListeners();
  }

  Future<void> _restoreItem(String id) async {
    final item = await (db.select(db.items)
      ..where((t) => t.id.equals(id)))
        .getSingle();

    final extra = jsonDecode(item.extra ?? '{}');

    final l1 = extra['l1Id'];
    final l2 = extra['l2Id'];
    final l3 = extra['l3Id'];

    // 🔥 1. 부모 폴더 자동 복구
    for (final folderId in [l1, l2, l3]) {
      if (folderId == null) continue;

      final folder = await (db.select(db.folders)
        ..where((t) => t.id.equals(folderId)))
          .getSingleOrNull();

      if (folder != null && folder.isDeleted == true) {
        await _restoreFolder(folderId, deep: false);
      }
    }

    // 🔥 2. item 복구
    await (db.update(db.items)
      ..where((t) => t.id.equals(id))).write(
      const ItemsCompanion(
        isDeleted: Value(false),
        deletedAt: Value(null),
      ),
    );

    // 🔥 3. itemPaths 복구
    await db.into(db.itemPaths).insertOnConflictUpdate(
      ItemPathsCompanion(
        itemId: Value(id),
        l1Id: Value(l1),
        l2Id: Value(l2),
        l3Id: Value(l3),
      ),
    );
  }

  Future<void> _restoreFolder(String id, {bool deep = true}) async {
    final folder = await (db.select(db.folders)
      ..where((t) => t.id.equals(id)))
        .getSingle();

    final extra = jsonDecode(folder.extra ?? '{}');
    final parentId = extra['parentId'];

    // 🔥 1. 부모 폴더 먼저 복구
    if (parentId != null) {
      final parent = await (db.select(db.folders)
        ..where((t) => t.id.equals(parentId)))
          .getSingleOrNull();

      if (parent != null && parent.isDeleted == true) {
        await _restoreFolder(parentId);
      }
    }

    // 🔥 2. 폴더 복구
    await (db.update(db.folders)
      ..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        parentId: Value(parentId),
      ),
    );

    if (deep) {
      // 🔥 3. 하위 아이템 전부 복구
      final items = await (db.select(db.items)
        ..where((t) => t.isDeleted.equals(true)))
          .get();

      for (final item in items) {
        final extra = jsonDecode(item.extra ?? '{}');

        if (extra['l1Id'] == id ||
            extra['l2Id'] == id ||
            extra['l3Id'] == id) {
          await _restoreItem(item.id);
        }
      }

      // 🔥 4. 하위 폴더 재귀 복구
      final children = await (db.select(db.folders)
        ..where((t) =>
        t.isDeleted.equals(true) &
        t.parentId.equals(id)))
          .get();

      for (final child in children) {
        await _restoreFolder(child.id, deep: true);
      }
    }
  }

  Future<int> _countDescendants(String folderId) async {
    int count = 0;

    // 🔥 1. 하위 item 개수
    final items = await (db.select(db.items)
      ..where((t) => t.isDeleted.equals(true)))
        .get();

    for (final item in items) {
      final extra = jsonDecode(item.extra ?? '{}');

      if (extra['l1Id'] == folderId ||
          extra['l2Id'] == folderId ||
          extra['l3Id'] == folderId) {
        count++;
      }
    }

    // 🔥 2. 하위 폴더 개수 (재귀)
    final children = await (db.select(db.folders)
      ..where((t) =>
      t.isDeleted.equals(true) &
      t.parentId.equals(folderId)))
        .get();

    for (final child in children) {
      count++; // 폴더 자체
      count += await _countDescendants(child.id);
    }

    return count;
  }
  Future<int> getRestoreImpactCount(String folderId) async {
    return await _countDescendants(folderId);
  }

  Future<String?> getParentFolderName(String itemId) async {
    final item = await (db.select(db.items)
      ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();

    if (item == null) return null;

    final extra = jsonDecode(item.extra ?? '{}');

    final l3 = extra['l3Id'];
    final l2 = extra['l2Id'];
    final l1 = extra['l1Id'];

    // 🔥 가장 깊은 폴더부터 찾기
    final targetId = l3 ?? l2 ?? l1;
    if (targetId == null) return null;

    final folder = await (db.select(db.folders)
      ..where((t) => t.id.equals(targetId)))
        .getSingleOrNull();

    return folder?.name;
  }
  Future<({String? name, bool willRestore})>
  getParentFolderInfo(String itemId) async {
    final item = await (db.select(db.items)
      ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();

    if (item == null) return (name: null, willRestore: false);

    final extra = jsonDecode(item.extra ?? '{}');

    final l3 = extra['l3Id'];
    final l2 = extra['l2Id'];
    final l1 = extra['l1Id'];

    final targetId = l3 ?? l2 ?? l1;
    if (targetId == null) {
      return (name: null, willRestore: false);
    }

    final folder = await (db.select(db.folders)
      ..where((t) => t.id.equals(targetId)))
        .getSingleOrNull();

    if (folder == null) {
      return (name: null, willRestore: false);
    }

    return (
    name: folder.name,
    willRestore: folder.isDeleted == true
    );
  }
}