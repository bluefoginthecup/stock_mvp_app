part of '../drift_unified_repo.dart';

mixin ItemRepoMixin on _RepoCore {
@override
Future<List<Item>> listItems({String? folder, String? keyword}) async {

  final q = db.select(db.items);

  // 휴지통(소프트삭제) 제외
    q.where((t) => t.isDeleted.equals(false));


  if (folder != null && folder.isNotEmpty) {
    q.where((tbl) => tbl.folder.equals(folder));
  }
  if (keyword != null && keyword.trim().isNotEmpty) {
    final like = '%${keyword.trim()}%';
    q.where((tbl) => tbl.name.like(like) | tbl.displayName.like(like));
  }

  final rows = await q.get();
  final list = rows.map((r) => r.toDomain()).toList();
  _cacheItems(list);
  return list;
}

@override
Future<List<Item>> searchItemsGlobal(String keyword) async {
  final kw = '%${keyword.trim()}%';
  final rows = await (db.select(db.items)
      // 휴지통 제외
    ..where((t) => t.isDeleted.equals(false))
    ..where((t) => t.name.like(kw) | t.displayName.like(kw) | t.sku.like(kw) | t.id.like(kw)))
      .get();
  final list = rows.map((e) => e.toDomain()).toList();
  _cacheItems(list);
  return list;
}

@override
Future<List<Item>> searchItemsByPath({
  String? l1,
  String? l2,
  String? l3,
  required String keyword,
  bool recursive = true,
}) async {
  final kw = '%${keyword.trim()}%';
  final joinQuery = db.select(db.items).join([
    innerJoin(db.itemPaths, db.itemPaths.itemId.equalsExp(db.items.id)),
  ]);

  // 휴지통 제외
  joinQuery.where(db.items.isDeleted.equals(false));


  if (l1 != null) joinQuery.where(db.itemPaths.l1Id.equals(l1));
  if (l2 != null) joinQuery.where(db.itemPaths.l2Id.equals(l2));
  if (l3 != null) joinQuery.where(db.itemPaths.l3Id.equals(l3));

  joinQuery.where(
    db.items.name.like(kw) |
    db.items.displayName.like(kw) |
    db.items.sku.like(kw),
  );

  final rows = await joinQuery.get();
  final list = rows.map((r) => r.readTable(db.items).toDomain()).toList();
  _cacheItems(list);
  return list;
}

Future<List<Item>> listItemsByFolderPath({
  String? l1,
  String? l2,
  String? l3,
  bool recursive = true,
}) async {
  final join = db.select(db.items).join([
    innerJoin(db.itemPaths, db.itemPaths.itemId.equalsExp(db.items.id)),
  ]);
  // 휴지통 제외
    join.where(db.items.isDeleted.equals(false));

  if (l1 != null) join.where(db.itemPaths.l1Id.equals(l1));
  if (l2 != null) join.where(db.itemPaths.l2Id.equals(l2));
  if (l3 != null) join.where(db.itemPaths.l3Id.equals(l3));

  if (!recursive) {
    if (l3 != null) {
      // no-op
    } else if (l2 != null) {
      join.where(db.itemPaths.l3Id.isNull());
    } else if (l1 != null) {
      join.where(db.itemPaths.l2Id.isNull() & db.itemPaths.l3Id.isNull());
    } else {
      join.where(db.itemPaths.l1Id.isNull() & db.itemPaths.l2Id.isNull() & db.itemPaths.l3Id.isNull());
    }
  }

  final rows = await join.get();
  final list = rows.map((r) => r.readTable(db.items).toDomain()).toList();
  _cacheItems(list);
  return list;
}

@override
Future<Item?> getItem(String id) async {
  final row = await (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
  final it = row?.toDomain();
  if (it != null) _cacheItem(it);
  return it;
}

@override
Future<void> upsertItem(Item item) async {
  await db.transaction(() async {
    final fav = item.isFavorite;
    await db.into(db.items).insertOnConflictUpdate(
      item.toCompanion().copyWith(isFavorite: Value(fav)),
    );
    await _updateItemPaths(item);
  });
  final fresh = await getItem(item.id);
  if (fresh != null) _cacheItem(fresh);
}

Future<void> upsertItemWithPath(Item item, String? l1, String? l2, String? l3) async {
  await db.transaction(() async {
    final fav = item.isFavorite;
    await db.into(db.items).insertOnConflictUpdate(
      item.toCompanion().copyWith(isFavorite: Value(fav)),
    );

    final effL1 = l1 ?? (item.folder.isNotEmpty ? item.folder : null);
    final effL2 = l2 ?? item.subfolder;
    final effL3 = l3 ?? item.subsubfolder;
    await _ensureFolderPath(l1: effL1 ?? '', l2: effL2, l3: effL3);

    await db.into(db.itemPaths).insertOnConflictUpdate(
      ItemPathsCompanion(
        itemId: Value(item.id),
        l1Id: Value(effL1),
        l2Id: Value(effL2),
        l3Id: Value(effL3),
      ),
    );
  });

  final fresh = await getItem(item.id);
  if (fresh != null) _cacheItem(fresh);
}

Future<void> _updateItemPaths(Item item) async {
  if (item.folder.isEmpty) {
    await db.into(db.itemPaths).insertOnConflictUpdate(
      ItemPathsCompanion(
        itemId: Value(item.id),
        l1Id: const Value(null),
        l2Id: const Value(null),
        l3Id: const Value(null),
      ),
    );
    return;
  }

  final l1Name = item.folder;
  final l2Name = item.subfolder;
  final l3Name = item.subsubfolder;

  final l1Id = l1Name;
  String? l2Id = (l2Name != null && l2Name.isNotEmpty) ? '$l1Id-$l2Name' : null;
  String? l3Id;
  if (l3Name != null && l3Name.isNotEmpty) {
    l3Id = (l2Id != null) ? '$l2Id-$l3Name' : '$l1Id-$l3Name';
  }

  await _ensureFolderPath(l1: l1Name, l2: l2Name, l3: l3Name);

  await db.into(db.itemPaths).insertOnConflictUpdate(
    ItemPathsCompanion(
      itemId: Value(item.id),
      l1Id: Value(l1Id),
      l2Id: Value(l2Id),
      l3Id: Value(l3Id),
    ),
  );
}

@override
Future<Item?> getItemById(String id) async {
  final row = await (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
  return row?.toDomain();
}

@override
Future<void> updateItemMeta(Item item) async {
  final comp = item.toCompanion();
  await (db.update(db.items)..where((t) => t.id.equals(item.id))).write(comp);
}

@override
Future<void> deleteItem(String id) async {
  await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
  await (db.delete(db.itemPaths)..where((t) => t.itemId.equals(id))).go();
  _itemsById.remove(id);
  _stockCache.remove(id);
}

@override
Future<void> setFavorite({required String itemId, required bool value}) async {
  await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
    ItemsCompanion(isFavorite: Value(value)),
  );
  final fresh = await getItem(itemId);
  if (fresh != null) _cacheItem(fresh);
}

Future<void> toggleFavorite(String itemId, bool value) =>
    setFavorite(itemId: itemId, value: value);

@override
Stream<List<Item>> watchItems({
  String? l1,
  String? l2,
  String? l3,
  String? keyword,
  bool recursive = false,
  bool lowOnly = false,
  bool favoritesOnly = false,

}) {
  final i = db.items;
  final p = db.itemPaths;
  final join = db.select(i).join([leftOuterJoin(p, p.itemId.equalsExp(i.id))]);

  // 휴지통 제외
  join.where(i.isDeleted.equals(false));


  if (l1 != null && l1.isNotEmpty) {
    join.where(p.l1Id.equals(l1));
    if (l2 != null && l2.isNotEmpty) {
      join.where(p.l2Id.equals(l2));
      if (l3 != null && l3.isNotEmpty) {
        join.where(p.l3Id.equals(l3));
      } else if (!recursive) {
        join.where(p.l3Id.isNull());
      }
    } else if (!recursive) {
      join.where(p.l2Id.isNull());
    }
  }

  if (keyword != null && keyword.isNotEmpty) {
    final like = '%${keyword.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    join.where(i.name.like(like) | i.displayName.like(like) | i.sku.like(like));
  }

  if (lowOnly) {
    join.where(i.minQty.isBiggerThanValue(0) & i.qty.isSmallerOrEqual(i.minQty));
  }
  if (favoritesOnly) {
    join.where(i.isFavorite.equals(true));
  }

  join.orderBy([OrderingTerm.asc(i.name)]);

  return join.watch().map((rows) {
    final list = rows.map((r) => r.readTable(i).toDomain()).toList();
    _cacheItems(list);
    return list;
  });
}

Stream<({int low, int fav})> watchCounts({
  String? l1,
  String? l2,
  String? l3,
  String? keyword,
  bool recursive = false,
}) {
  return watchItems(
    l1: l1, l2: l2, l3: l3, keyword: keyword, recursive: recursive,
    lowOnly: false, favoritesOnly: false,
  ).map((all) {
    final low = all.where((e) => e.minQty > 0 && e.qty <= e.minQty).length;
    final fav = all.where((e) => e.isFavorite == true).length;
    return (low: low, fav: fav);
  });
}

@override
Future<List<String>> itemPathNames(String itemId) async {
  final pathRow = await (db.select(db.itemPaths)..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
  if (pathRow == null) return [];

  Future<String?> getFolderName(String? id) async {
    if (id == null) return null;
    final row = await (db.select(db.folders)..where((f) => f.id.equals(id))).getSingleOrNull();
    return row?.name;
  }

  final names = <String>[];
  final l1 = await getFolderName(pathRow.l1Id);
  final l2 = await getFolderName(pathRow.l2Id);
  final l3 = await getFolderName(pathRow.l3Id);
  if (l1 != null) names.add(l1);
  if (l2 != null) names.add(l2);
  if (l3 != null) names.add(l3);
  return names;
}

@override
Future<String?> nameOf(String itemId) async {
  final row = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
  return row?.name;
}

String? hintUnitOut(String id) {
  final it = _cachedItemOrNull(id);
  if (it == null) return null;
  final uo = it.unitOut.trim();
  if (uo.isNotEmpty) return uo;
  final u = it.unit.trim();
  return u.isNotEmpty ? u : null;
}

double? hintQtyOut(String id) {
  final it = _cachedItemOrNull(id);
  final h = it?.stockHints;
  if (h == null) return null;
  final v = h.qty;
  if (v != null && v > 0) return v.toDouble();
  return null;
}

double? hintUsableMeters(String id) {
  final it = _cachedItemOrNull(id);
  final h = it?.stockHints;
  if (h == null) return null;
  final v = h.usableQtyM;
  if (v != null && v > 0) return v.toDouble();
  return null;
}

@override
int stockOf(String itemId) {
  final v = _stockCache[itemId];
  return v ?? 0;
}

  @override
  Future<void> moveItemToTrash(String id, {String? reason}) async {
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        isDeleted: const Value(true),
        // deletedAt을 TextColumn(ISO8601)로 통일했으니 문자열 저장
        deletedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> restoreItemFromTrash(String id) async {
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(
      const ItemsCompanion(
        isDeleted: Value(false),
        deletedAt: Value(null),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> purgeItem(String id) async {
    // 자식 테이블(FK) 정리 필요 시 여기서 먼저 처리하거나 FK를 CASCADE로
    await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
    notifyListeners();
  }
}
