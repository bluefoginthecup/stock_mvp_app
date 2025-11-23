part of '../drift_unified_repo.dart';

mixin FolderRepoMixin on _RepoCore{

@override
FolderSortMode get sortMode => _sortMode;

@override
Future<void> setSortMode(FolderSortMode mode) async {
  _sortMode = mode;
  notifyListeners();
}

Future<void> upsertFolderNode(FolderNode node) async {
  await db.into(db.folders).insertOnConflictUpdate(
    FoldersCompanion(
      id: Value(node.id),
      name: Value(node.name),
      parentId: Value(node.parentId),
      depth: Value(node.depth),
    ),
  );
}

@override
Future<List<FolderNode>> listFolderChildren(String? parentId) async {
  final q = db.select(db.folders)
    ..where((tbl) => parentId == null ? tbl.parentId.isNull() : tbl.parentId.equals(parentId));

  if (_sortMode == FolderSortMode.name) {
    q.orderBy([(t) => OrderingTerm.asc(t.name)]);
  } else {
    q.orderBy([(t) => OrderingTerm.asc(t.order)]);
  }

  final rows = await q.get();
  return rows.map((r) => r.toDomain()).toList();
}

@override
Future<FolderNode?> folderById(String id) async {
  final row = await (db.select(db.folders)..where((t) => t.id.equals(id))).getSingleOrNull();
  return row?.toDomain();
}

@override
Future<FolderNode> createFolderNode({
  required String? parentId,
  required String name,
}) async {
  final parentRow = parentId == null
      ? null
      : await (db.select(db.folders)..where((t) => t.id.equals(parentId))).getSingleOrNull();

  final depth = parentRow != null ? parentRow.depth + 1 : 0;
  final newId = 'fo_${DateTime.now().microsecondsSinceEpoch}';

  final row = FoldersCompanion(
    id: Value(newId),
    name: Value(name),
    parentId: Value(parentId),
    depth: Value(depth),
    order: const Value(0),
  );

  await db.into(db.folders).insert(row);

  return FolderNode(
    id: newId, name: name, parentId: parentId, depth: depth, order: 0,
  );
}

@override
Future<void> renameFolderNode({required String id, required String newName}) async {
  await (db.update(db.folders)..where((t) => t.id.equals(id)))
      .write(FoldersCompanion(name: Value(newName)));
}

@override
Future<void> deleteFolderNode(String id) async {
  final hasChildren =
  await (db.select(db.folders)..where((t) => t.parentId.equals(id))).get();
  if (hasChildren.isNotEmpty) throw StateError('subfolders exist');

  final containsItems = await (db.select(db.itemPaths)
    ..where((t) => t.l1Id.equals(id) | t.l2Id.equals(id) | t.l3Id.equals(id)))
      .get();
  if (containsItems.isNotEmpty) throw StateError('referenced by items');

  await (db.delete(db.folders)..where((t) => t.id.equals(id))).go();
}

Future<void> _ensureFolderPath({
  required String l1,
  String? l2,
  String? l3,
}) async {
  final l1Id = l1;
  final String? l2Id = (l2 != null && l2.isNotEmpty) ? '$l1Id-$l2' : null;
  final String? l3Id = (l3 != null && l3.isNotEmpty && l2Id != null) ? '$l2Id-$l3' : null;

  await db.into(db.folders).insertOnConflictUpdate(
    FoldersCompanion(
      id: Value(l1Id), name: Value(l1), parentId: const Value(null), depth: const Value(0),
    ),
  );

  if (l2Id != null) {
    await db.into(db.folders).insertOnConflictUpdate(
      FoldersCompanion(
        id: Value(l2Id), name: Value(l2!), parentId: Value(l1Id), depth: const Value(1),
      ),
    );
  }

  if (l3Id != null) {
    await db.into(db.folders).insertOnConflictUpdate(
      FoldersCompanion(
        id: Value(l3Id), name: Value(l3!), parentId: Value(l2Id), depth: const Value(2),
      ),
    );
  }
}

@override
Future<(List<FolderNode>, List<Item>)> searchAll({
  String? l1, String? l2, String? l3,
  required String keyword,
  bool recursive = true,
}) async {
  final kw = '%${keyword.trim()}%';
  final folderRows = await (db.select(db.folders)..where((t) => t.name.like(kw))).get();
  final folderNodes = folderRows.map((r) => r.toDomain()).toList();

  final join = db.select(db.items).join([
    innerJoin(db.itemPaths, db.itemPaths.itemId.equalsExp(db.items.id)),
  ]);
  if (l1 != null) join.where(db.itemPaths.l1Id.equals(l1));
  if (l2 != null) join.where(db.itemPaths.l2Id.equals(l2));
  if (l3 != null) join.where(db.itemPaths.l3Id.equals(l3));

  join.where(
    db.items.name.like(kw) |
    db.items.displayName.like(kw) |
    db.items.sku.like(kw),
  );

  final itemRows = await join.get();
  final itemsFound = itemRows.map((r) => r.readTable(db.items).toDomain()).toList();
  _cacheItems(itemsFound);
  return (folderNodes, itemsFound);
}

@override
Future<int> moveItemsToPath({
  required List<String> itemIds,
  required List<String> pathIds,
}) async {
  int moved = 0;
  for (final itemId in itemIds) {
    await _moveSingleItem(itemId, pathIds);
    moved++;
  }
  return moved;
}

Future<void> _moveSingleItem(String itemId, List<String> pathIds) async {
  final l1 = pathIds.isNotEmpty ? pathIds[0] : null;
  final l2 = pathIds.length > 1 ? pathIds[1] : null;
  final l3 = pathIds.length > 2 ? pathIds[2] : null;

  await (db.update(db.itemPaths)..where((t) => t.itemId.equals(itemId))).write(
    ItemPathsCompanion(l1Id: Value(l1), l2Id: Value(l2), l3Id: Value(l3)),
  );
}

@override
Future<void> moveEntityToPath(MoveRequest req) async {
  if (req.kind == EntityKind.item) {
    return _moveSingleItem(req.id, req.pathIds);
  }
  if (req.kind == EntityKind.folder) {
    final newParentId = req.pathIds.isNotEmpty ? req.pathIds.last : null;
    final newDepth = req.pathIds.length;
    await (db.update(db.folders)..where((t) => t.id.equals(req.id))).write(
      FoldersCompanion(parentId: Value(newParentId), depth: Value(newDepth)),
    );
    return;
  }
  throw UnsupportedError('Unknown entity kind');
}

Future<void> debugPrintAllFolders() async {
  final rows = await (db.select(db.folders)
    ..orderBy([(t) => OrderingTerm.asc(t.depth), (t) => OrderingTerm.asc(t.name)]))
      .get();
  debugPrint('===== FOLDERS TABLE DUMP =====');
  for (final r in rows) {
    debugPrint('[Folder] id=${r.id}, name=${r.name}, parentId=${r.parentId}, depth=${r.depth}, order=${r.order}');
  }

  final roots = await (db.select(db.folders)
    ..where((t) => t.parentId.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();
  debugPrint('===== ROOT FOLDERS (parentId IS NULL) =====');
  for (final r in roots) {
    debugPrint('[Root] id=${r.id}, name=${r.name}, depth=${r.depth}');
  }
}
}
