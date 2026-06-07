part of '../drift_unified_repo.dart';

mixin FolderRepoMixin on _RepoCore implements FolderTreeRepo {
  @override
  FolderSortMode get sortMode => _sortMode;

  bool isSystemRootFolder(String id) =>
      SystemSeedService.systemRootFolders.containsKey(id);

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
            order: Value(node.order),
            isDeleted: const Value(false),
            deletedAt: const Value(null),
          ),
        );
  }

  @override
  Future<List<FolderNode>> listFolderChildren(String? parentId) async {
    final q = db.select(db.folders)
      ..where((tbl) =>
          (parentId == null
              ? tbl.parentId.isNull()
              : tbl.parentId.equals(parentId)) &
          tbl.isDeleted.equals(false));
    if (_sortMode == FolderSortMode.name) {
      q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    } else {
      q.orderBy([(t) => OrderingTerm.asc(t.order)]);
    }

    final rows = await q.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<List<FolderNode>> getChildren(String parentId) async {
    return await listFolderChildren(parentId);
  }

  Future<FolderNode?> getFolder(String id) async {
    return await folderById(id);
  }

  @override
  Stream<List<FolderNode>> watchFolderSearch(String keyword) {
    final qRaw = keyword.trim();
    if (qRaw.isEmpty) {
      return const Stream.empty();
    }

    final q = db.select(db.folders)
      ..where((t) {
        // ✅ 초성 쿼리면 searchInitials, 아니면 searchNormalized
        if (looksLikeChosungQuery(qRaw)) {
          final key = qRaw.replaceAll(RegExp(r'\s+'), '');
          final like = '%${_escapeLike(key)}%';
          return t.searchInitials.like(like, escapeChar: r'\');
        } else {
          final norm = normalizeForSearch(qRaw);
          final like = '%${_escapeLike(norm)}%';
          return (t.isDeleted.equals(false) &
              (looksLikeChosungQuery(qRaw)
                  ? t.searchInitials.like(like, escapeChar: r'\')
                  : t.searchNormalized.like(like, escapeChar: r'\')));
        }
      });

    // 폴더는 적으니 이름순이 UX상 안정적
    q.orderBy(
        [(t) => OrderingTerm.asc(t.depth), (t) => OrderingTerm.asc(t.name)]);

    return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

// ItemRepoMixin에 이미 있으면 mixin 공용으로 빼도 됨
  String _escapeLike(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  @override
  Future<FolderNode?> folderById(String id) async {
    final row = await (db.select(db.folders)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();

    return row?.toDomain();
  }

  @override
  Future<FolderNode> createFolderNode({
    required String? parentId,
    required String name,
  }) async {
    final parentRow = parentId == null
        ? null
        : await (db.select(db.folders)..where((t) => t.id.equals(parentId)))
            .getSingleOrNull();

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
      id: newId,
      name: name,
      parentId: parentId,
      depth: depth,
      order: 0,
    );
  }

  @override
  Future<void> renameFolderNode(
      {required String id, required String newName}) async {
    await (db.update(db.folders)..where((t) => t.id.equals(id)))
        .write(FoldersCompanion(name: Value(newName)));
  }
//
// @override
// Future<void> deleteFolderNode(String id) async {
//   final hasChildren =
//   await (db.select(db.folders)..where((t) => t.parentId.equals(id))).get();
//   if (hasChildren.isNotEmpty) throw StateError('subfolders exist');
//
//   final containsItems = await (db.select(db.itemPaths)
//     ..where((t) => t.l1Id.equals(id) | t.l2Id.equals(id) | t.l3Id.equals(id)))
//       .get();
//   if (containsItems.isNotEmpty) throw StateError('referenced by items');
//
//   await (db.delete(db.folders)..where((t) => t.id.equals(id))).go();
// }
//

  @override
  Future<void> deleteFolderNode(String id, {bool force = false}) async {
    if (isSystemRootFolder(id)) {
      throw StateError('SYSTEM_FOLDER');
    }

    final now = DateTime.now().toIso8601String();

    final children = await (db.select(db.folders)
          ..where((t) => t.parentId.equals(id)))
        .get();

    final items = await (db.select(db.itemPaths)
          ..where(
              (t) => t.l1Id.equals(id) | t.l2Id.equals(id) | t.l3Id.equals(id)))
        .get();

    for (final p in items) {
      await (this as ItemRepo).moveItemToTrash(p.itemId);
    }

    if (!force) {
      if (children.isNotEmpty) throw StateError('HAS_CHILDREN');
      if (items.isNotEmpty) throw StateError('HAS_ITEMS');
    }

    // 🔥 하위 폴더도 같이 soft delete
    for (final c in children) {
      await deleteFolderNode(c.id, force: true);
    }

    // 🔥 폴더 soft delete
    final folder = await (db.select(db.folders)..where((t) => t.id.equals(id)))
        .getSingle();

    final extra = {
      'parentId': folder.parentId,
    };

    await (db.update(db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        extra: Value(jsonEncode(extra)), // 🔥 추가
      ),
    );
  }

  @override
  Future<(List<FolderNode>, List<Item>)> searchAll({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  }) async {
    final kw = '%${keyword.trim()}%';
    final folderRows = await (db.select(db.folders)
          ..where((t) => t.name.like(kw) & t.isDeleted.equals(false)))
        .get();
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
    final itemsFound =
        itemRows.map((r) => r.readTable(db.items).toDomain()).toList();
    _cacheItems(itemsFound);
    return (folderNodes, itemsFound);
  }

  @override
  Future<int> moveItemsToPath({
    required List<String> itemIds,
    required List<String> pathIds,
  }) async {
    if (itemIds.isEmpty) return 0;
    int moved = 0;
    await db.transaction(() async {
      final target = await _validateMoveTarget(pathIds);
      for (final itemId in itemIds) {
        final didMove = await _moveSingleItem(itemId, target);
        if (didMove) moved++;
      }
    });
    if (moved > 0) notifyListeners();
    return moved;
  }

  Future<_ResolvedFolderPath> _validateMoveTarget(List<String> pathIds) async {
    if (pathIds.isEmpty || pathIds.length > 3) {
      throw StateError('Invalid item path depth: ${pathIds.length}');
    }

    Future<FolderRow> readFolder(String id) async {
      final row = await (db.select(db.folders)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();
      if (row == null) throw StateError('Folder not found: $id');
      return row;
    }

    final l1 = await readFolder(pathIds[0]);
    if (l1.parentId != null) {
      throw StateError('Invalid L1 folder id: ${l1.id}');
    }

    FolderRow? l2;
    if (pathIds.length > 1) {
      l2 = await readFolder(pathIds[1]);
      if (l2.parentId != l1.id) {
        throw StateError('Invalid L2 folder id: ${l2.id}');
      }
    }

    FolderRow? l3;
    if (pathIds.length > 2) {
      if (l2 == null) throw StateError('L3 requires an L2 folder');
      l3 = await readFolder(pathIds[2]);
      if (l3.parentId != l2.id) {
        throw StateError('Invalid L3 folder id: ${l3.id}');
      }
    }

    return _ResolvedFolderPath(l1: l1, l2: l2, l3: l3);
  }

  Future<bool> _moveSingleItem(
      String itemId, _ResolvedFolderPath target) async {
    final item = await (db.select(db.items)
          ..where((t) => t.id.equals(itemId) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    if (item == null) {
      throw StateError('Item not found: $itemId');
    }

    await db.into(db.itemPaths).insertOnConflictUpdate(
          ItemPathsCompanion(
            itemId: Value(itemId),
            l1Id: Value(target.l1.id),
            l2Id: Value(target.l2?.id),
            l3Id: Value(target.l3?.id),
          ),
        );

    final baseName = (item.displayName?.trim().isNotEmpty == true)
        ? item.displayName!.trim()
        : item.name;
    final keys = buildItemSearchKeysRaw(
      name: baseName,
      sku: item.sku,
      folder: target.l1.name,
      subfolder: target.l2?.name,
      subsubfolder: target.l3?.name,
    );

    await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        folder: Value(target.l1.name),
        subfolder: Value(target.l2?.name),
        subsubfolder: Value(target.l3?.name),
        searchFullNormalized: Value(keys.fullNorm),
      ),
    );

    final fresh = await getItem(itemId);
    if (fresh != null) _cacheItem(fresh);
    return true;
  }

  @override
  Future<void> moveEntityToPath(MoveRequest req) async {
    if (req.kind == EntityKind.item) {
      final target = await _validateMoveTarget(req.pathIds);
      await db.transaction(() => _moveSingleItem(req.id, target));
      notifyListeners();
      return;
    }
    if (req.kind == EntityKind.folder) {
      await db.transaction(() => _moveFolderToPath(req.id, req.pathIds));
      notifyListeners();
      return;
    }
    throw UnsupportedError('Unknown entity kind');
  }

  Future<void> _moveFolderToPath(String folderId, List<String> pathIds) async {
    if (isSystemRootFolder(folderId)) {
      throw StateError('SYSTEM_FOLDER');
    }
    if (pathIds.length > 2) {
      throw StateError('Invalid folder target depth: ${pathIds.length}');
    }

    final moving = await _readActiveFolder(folderId);
    final newParentPath = await _validateFolderMoveTarget(pathIds);
    final newParentId = pathIds.isNotEmpty ? pathIds.last : null;
    final newDepth = pathIds.length;

    if (newParentId == moving.id) {
      throw StateError('Cannot move a folder into itself.');
    }
    if (pathIds.contains(moving.id)) {
      throw StateError('Cannot move a folder into its own child.');
    }

    final descendants = await _folderDescendants(moving.id);
    if (descendants.any((f) => pathIds.contains(f.id))) {
      throw StateError('Cannot move a folder into its own child.');
    }

    final depthDelta = newDepth - moving.depth;
    final maxDepthAfterMove = [
      moving,
      ...descendants,
    ].map((f) => f.depth + depthDelta).fold<int>(0, (a, b) => a > b ? a : b);
    if (maxDepthAfterMove > 2) {
      throw StateError('하위 폴더가 있어 이 위치로 이동할 수 없습니다.');
    }

    await (db.update(db.folders)..where((t) => t.id.equals(moving.id))).write(
      FoldersCompanion(parentId: Value(newParentId), depth: Value(newDepth)),
    );

    for (final child in descendants) {
      await (db.update(db.folders)..where((t) => t.id.equals(child.id))).write(
        FoldersCompanion(depth: Value(child.depth + depthDelta)),
      );
    }

    final movedFolderIds = {moving.id, ...descendants.map((f) => f.id)};
    final pathRows = await (db.select(db.itemPaths)
          ..where((t) =>
              t.l1Id.isIn(movedFolderIds) |
              t.l2Id.isIn(movedFolderIds) |
              t.l3Id.isIn(movedFolderIds)))
        .get();

    final newPrefix = [...newParentPath.map((f) => f.id), moving.id];
    for (final row in pathRows) {
      final oldItemPath = [row.l1Id, row.l2Id, row.l3Id]
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      final movingIndex = oldItemPath.indexOf(moving.id);
      if (movingIndex < 0) continue;

      final suffix = oldItemPath.skip(movingIndex + 1);
      final nextPath = [...newPrefix, ...suffix];
      if (nextPath.isEmpty || nextPath.length > 3) {
        throw StateError('Invalid item path after folder move.');
      }

      final target = await _validateMoveTarget(nextPath);
      await _moveSingleItem(row.itemId, target);
    }
  }

  Future<FolderRow> _readActiveFolder(String id) async {
    final row = await (db.select(db.folders)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    if (row == null) throw StateError('Folder not found: $id');
    return row;
  }

  Future<List<FolderRow>> _validateFolderMoveTarget(
      List<String> pathIds) async {
    if (pathIds.isEmpty) return const [];
    final target = await _validateMoveTarget(pathIds);
    return [
      target.l1,
      if (target.l2 != null) target.l2!,
    ];
  }

  Future<List<FolderRow>> _folderDescendants(String folderId) async {
    final result = <FolderRow>[];
    final queue = <String>[folderId];

    while (queue.isNotEmpty) {
      final parentId = queue.removeAt(0);
      final children = await (db.select(db.folders)
            ..where(
                (t) => t.parentId.equals(parentId) & t.isDeleted.equals(false)))
          .get();
      result.addAll(children);
      queue.addAll(children.map((f) => f.id));
    }

    return result;
  }

  Future<void> debugPrintAllFolders() async {}
}

class _ResolvedFolderPath {
  final FolderRow l1;
  final FolderRow? l2;
  final FolderRow? l3;

  const _ResolvedFolderPath({
    required this.l1,
    required this.l2,
    required this.l3,
  });
}
