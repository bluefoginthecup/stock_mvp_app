part of '../drift_unified_repo.dart';

enum ItemSearchScope {
  nameOnly, // 주문상세 등: 아이템명 기준
  full, // 재고브라우저: 아이템명 + SKU + 폴더명
}

mixin ItemRepoMixin on _RepoCore implements ItemRepo {
  // ---------- Search helpers ----------
  String _escapeLike(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Expression<bool> _keywordExpr(
    Items i,
    String raw, {
    ItemSearchScope scope = ItemSearchScope.nameOnly,
  }) {
    final splitter = RegExp(r'[\s,|/]+');
    final q = raw.trim();
    if (q.isEmpty) return const Constant(true);

    final hasSpace = q.contains(RegExp(r'\s'));
    final qNoSpace = q.replaceAll(RegExp(r'\s+'), '');

// ✅ 공백 포함한 원문으로 판정해야 "공백 있을 때만 fuzzy"가 가능
    final isCho = looksLikeChosungQuery(q);

    List<String> parts(String s) => s
        .split(splitter)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

// ── 1) 초성 검색 (항상 "이름 초성"만 사용)
    if (isCho) {
      if (!hasSpace) {
        // ✅ 공백 없으면: 연속 포함(건너뛰기 금지)
        final key = qNoSpace;
        final like = '%${_escapeLike(key)}%';
        return i.searchInitials.like(like, escapeChar: '\\');
      } else {
        // ✅ 공백 있으면: 토큰 단위 fuzzy(건너뛰기 허용)
        final ps = parts(q);
        if (ps.isEmpty) return const Constant(false);

        final tokenPatterns = ps.map((tok) {
          final chars = tok.replaceAll(RegExp(r'\s+'), '').split('');
          return chars.map(_escapeLike).join('%'); // ㄹ%ㅇ%ㄱ...
        }).toList();

        final like = '%${tokenPatterns.join('%')}%';
        return i.searchInitials.like(like, escapeChar: '\\');
      }
    }

    // ── 2) 일반 검색 (scope에 따라 컬럼 선택)
    final tokens = parts(q);
    if (tokens.isEmpty) return const Constant(false);

    final col = (scope == ItemSearchScope.full)
        ? i.searchFullNormalized
        : i.searchNormalized;

    Expression<bool> expr = const Constant(true);
    for (final t in tokens) {
      final key = normalizeForSearch(t);
      if (key.isEmpty) return const Constant(false);
      expr = expr & col.like('%${_escapeLike(key)}%', escapeChar: '\\');
    }
    return expr;
  }

  @override
  Future<List<Item>> listItems({String? folder, String? keyword}) async {
    final q = db.select(db.items);

    // 휴지통(소프트삭제) 제외
    q.where((t) => t.isDeleted.equals(false));

    if (folder != null && folder.isNotEmpty) {
      q.where((tbl) => tbl.folder.equals(folder));
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      q.where(
        (t) => _keywordExpr(t, keyword, scope: ItemSearchScope.nameOnly),
      );
    }

    final rows = await q.get();
    final list = rows.map((r) => r.toDomain()).toList();
    _cacheItems(list);
    return list;
  }

  @override
  Future<List<Item>> searchItemsGlobal(String keyword) async {
    final raw = keyword.trim();
    if (raw.isEmpty) return [];

    final q = db.select(db.items)
      ..where((t) => t.isDeleted.equals(false))
      ..where(
        (t) => _keywordExpr(t, raw, scope: ItemSearchScope.nameOnly),
      )
      ..limit(80);

    final rows = await q.get();
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
    final joinQuery = db.select(db.items).join([
      innerJoin(db.itemPaths, db.itemPaths.itemId.equalsExp(db.items.id)),
    ]);

    // 휴지통 제외
    joinQuery.where(db.items.isDeleted.equals(false));

    if (l1 != null) joinQuery.where(db.itemPaths.l1Id.equals(l1));
    if (l2 != null) joinQuery.where(db.itemPaths.l2Id.equals(l2));
    if (l3 != null) joinQuery.where(db.itemPaths.l3Id.equals(l3));

    // ✅ searchNormalized/searchInitials 기반 검색으로 교체
    joinQuery.where(
      _keywordExpr(db.items, keyword, scope: ItemSearchScope.nameOnly),
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
        join.where(db.itemPaths.l1Id.isNull() &
            db.itemPaths.l2Id.isNull() &
            db.itemPaths.l3Id.isNull());
      }
    }

    final rows = await join.get();
    final list = rows.map((r) => r.readTable(db.items).toDomain()).toList();
    _cacheItems(list);
    return list;
  }

  Future<List<Item>> getItemsByFolderId(String folderId) async {
    final join = db.select(db.items).join([
      innerJoin(db.itemPaths, db.itemPaths.itemId.equalsExp(db.items.id)),
    ]);

    join.where(db.items.isDeleted.equals(false));

    // 🔥 핵심: 어느 depth든 포함
    join.where(
      db.itemPaths.l1Id.equals(folderId) |
          db.itemPaths.l2Id.equals(folderId) |
          db.itemPaths.l3Id.equals(folderId),
    );

    final rows = await join.get();
    final list = rows.map((r) => r.readTable(db.items).toDomain()).toList();
    _cacheItems(list);
    return list;
  }

  @override
  Future<Item?> getItem(String id) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final it = row?.toDomain();
    if (it != null) _cacheItem(it);
    return it;
  }

  Item? getCachedItem(String id) {
    return _itemsById[id];
  }

  bool _priceChanged(double? oldPrice, double? newPrice) {
    if (oldPrice == null && newPrice == null) return false;
    if (oldPrice == null || newPrice == null) return true;
    return (oldPrice - newPrice).abs() > 0.0001;
  }

  Future<void> _insertItemPriceHistory({
    required String itemId,
    required String kind,
    required double? oldPrice,
    required double? newPrice,
    String source = 'manual',
    String? note,
  }) async {
    if (!_priceChanged(oldPrice, newPrice)) return;
    final now = DateTime.now();
    await db.into(db.itemPriceHistories).insert(
          ItemPriceHistoriesCompanion(
            id: Value(
              'iph_${now.microsecondsSinceEpoch}_${kind}_$itemId',
            ),
            itemId: Value(itemId),
            kind: Value(kind),
            changedAt: Value(now.toIso8601String()),
            oldPrice: Value(oldPrice),
            newPrice: Value(newPrice),
            source: Value(source),
            note: Value(note),
          ),
        );
  }

  Future<void> _recordItemPriceChanges({
    required Item? before,
    required Item after,
    String source = 'manual',
  }) async {
    await _insertItemPriceHistory(
      itemId: after.id,
      kind: 'purchase',
      oldPrice: before?.defaultPurchasePrice,
      newPrice: after.defaultPurchasePrice,
      source: source,
      note: '입고가 변경',
    );
    await _insertItemPriceHistory(
      itemId: after.id,
      kind: 'sale',
      oldPrice: before?.defaultSalePrice,
      newPrice: after.defaultSalePrice,
      source: source,
      note: '출고가 변경',
    );
  }

  @override
  Future<void> upsertItem(Item item) async {
    await db.transaction(() async {
      final beforeRow = await (db.select(db.items)
            ..where((t) => t.id.equals(item.id)))
          .getSingleOrNull();
      final before = beforeRow?.toDomain();
      final keys = buildItemSearchKeys(item);

      await db.into(db.items).insertOnConflictUpdate(
            item.toCompanion().copyWith(
                  searchNormalized: Value(keys.nameNorm),
                  searchInitials: Value(keys.initials),
                  searchFullNormalized: Value(keys.fullNorm),
                  defaultPurchasePrice:
                      Value(item.defaultPurchasePrice), // ⭐ 여기
                  defaultSalePrice: Value(item.defaultSalePrice), // ⭐ 여기
                ),
          );
      await _recordItemPriceChanges(
        before: before,
        after: item,
        source: before == null ? 'initial' : 'manual',
      );
    });

    final fresh = await getItem(item.id);
    if (fresh != null) _cacheItem(fresh);
    await ReorderReminderService.rescheduleForItem(fresh ?? item);
  }

  @override
  Future<void> markItemOrderedNow(String itemId) async {
    await markItemsOrderedNow([itemId]);
  }

  @override
  Future<DateTime?> latestPurchaseOrderedAtForItem(String itemId) async {
    final rows = await db.customSelect(
      '''
      SELECT po.created_at AS ordered_at
      FROM purchase_lines pl
      JOIN purchase_orders po ON po.id = pl.order_id
      WHERE pl.item_id = ?
        AND po.is_deleted = 0
        AND po.status IN (?, ?)
      ORDER BY po.created_at DESC
      LIMIT 1
      ''',
      variables: [
        Variable.withString(itemId),
        Variable.withString(PurchaseOrderStatus.ordered.name),
        Variable.withString(PurchaseOrderStatus.received.name),
      ],
    ).get();
    if (rows.isEmpty) return null;
    final value = rows.first.data['ordered_at'] as String?;
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  @override
  Future<void> markItemsOrderedNow(Iterable<String> itemIds) async {
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;
    final today = ReorderScheduleUtils.dateOnly(DateTime.now());

    for (final itemId in ids) {
      final item = await getItem(itemId);
      if (item == null || item.reorderIntervalDays == null) continue;

      final next = ReorderScheduleUtils.calculateNextReorderDate(
        lastOrderedAt: today,
        intervalDays: item.reorderIntervalDays,
      );
      await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(
          lastOrderedAt: Value(today.toIso8601String()),
          nextReorderDate: Value(next?.toIso8601String()),
        ),
      );
      final fresh = await getItem(itemId);
      if (fresh != null) {
        _cacheItem(fresh);
        await ReorderReminderService.rescheduleForItem(fresh);
      }
    }
  }

  Future<void> upsertItemWithPath(
      Item item, String? l1, String? l2, String? l3) async {
    await db.transaction(() async {
      // 1) 경로는 오직 인자로 받은 ID만 사용 (UI 플레이스홀더/문자열 경로 무시)
      final effL1 = (l1 != null && l1.isNotEmpty) ? l1 : null;
      final effL2 = (l2 != null && l2.isNotEmpty) ? l2 : null;
      final effL3 = (l3 != null && l3.isNotEmpty) ? l3 : null;

      // L1은 반드시 존재해야 한다(루트 자동 생성 금지)
      if (effL1 == null) {
        throw StateError(
            'upsertItemWithPath: l1 (root folder id) is required.');
      }

      // 2) 폴더 존재 검증 (필요 시 더 엄격히: 없으면 throw)
      final l1Node = await (db.select(db.folders)
            ..where((t) => t.id.equals(effL1)))
          .getSingleOrNull();
      if (l1Node == null || l1Node.parentId != null) {
        throw StateError('Invalid root folder id: $effL1');
      }
      FolderRow? l2Node, l3Node;
      if (effL2 != null) {
        l2Node = await (db.select(db.folders)..where((t) => t.id.equals(effL2)))
            .getSingleOrNull();
        if (l2Node == null || l2Node.parentId != l1Node.id) {
          throw StateError('Invalid L2 folder id: $effL2 (parent mismatch)');
        }
      }
      if (effL3 != null) {
        l3Node = await (db.select(db.folders)..where((t) => t.id.equals(effL3)))
            .getSingleOrNull();
        if (l3Node == null || l2Node == null || l3Node.parentId != l2Node.id) {
          throw StateError('Invalid L3 folder id: $effL3 (parent mismatch)');
        }
      }
      final baseName = (item.displayName?.trim().isNotEmpty == true)
          ? item.displayName!.trim()
          : item.name;
      final keys = buildItemSearchKeysRaw(
        name: baseName,
        sku: item.sku,
        folder: l1Node.name,
        subfolder: l2Node?.name,
        subsubfolder: l3Node?.name,
      );

      final base = item.toCompanion();
      final comp = base.copyWith(
        isFavorite: Value(item.isFavorite),
        folder: Value(l1Node.name),
        subfolder: Value(l2Node?.name),
        subsubfolder: Value(l3Node?.name),
        searchNormalized: Value(keys.nameNorm),
        searchInitials: Value(keys.initials),
        searchFullNormalized: Value(keys.fullNorm),
        defaultPurchasePrice: Value(item.defaultPurchasePrice), // ⭐ 추가
        defaultSalePrice: Value(item.defaultSalePrice), // ⭐ 추가
      );

      await db.into(db.items).insertOnConflictUpdate(comp);

      // 4) item_paths 싱크
      await db.into(db.itemPaths).insertOnConflictUpdate(
            ItemPathsCompanion(
              itemId: Value(item.id),
              l1Id: Value(effL1),
              l2Id: Value(effL2),
              l3Id: Value(effL3),
            ),
          );
    });

    // 5) 캐시 리프레시
    final fresh = await getItem(item.id);
    if (fresh != null) _cacheItem(fresh);
    await ReorderReminderService.rescheduleForItem(fresh ?? item);
  }

  @override
  Future<Item?> getItemById(String id) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> updateItemMeta(Item item) async {
    final keys = buildItemSearchKeys(item);
    print('DB 저장 직전: ${item.defaultPurchasePrice} / ${item.defaultSalePrice}');
    final before = await getItem(item.id);

    final updated = item.toCompanion().copyWith(
          searchNormalized: Value(keys.nameNorm),
          searchInitials: Value(keys.initials),
          searchFullNormalized: Value(keys.fullNorm),
          defaultPurchasePrice: Value(item.defaultPurchasePrice),
          defaultSalePrice: Value(item.defaultSalePrice),
        );

    await db.transaction(() async {
      await db.update(db.items).replace(updated);
      await _recordItemPriceChanges(
        before: before,
        after: item,
      );
    });

    final check = await getItem(item.id);
    if (check != null) {
      _cacheItem(check);
      await ReorderReminderService.rescheduleForItem(check);
    }
    print(
        'DB 저장 후: ${check?.defaultPurchasePrice} / ${check?.defaultSalePrice}');
  }

  @override
  Future<List<String>> registrationMissingFields(String itemId) async {
    final item = await getItem(itemId);
    if (item == null || !isNeedsRegistrationItem(item)) return const [];

    final missing = <String>[];
    final displayOrName = (item.displayName?.trim().isNotEmpty == true)
        ? item.displayName!.trim()
        : item.name.trim();
    if (displayOrName.isEmpty) {
      missing.add('아이템명 필요');
    }
    if (item.unit.trim().isEmpty) {
      missing.add('단위 필요');
    }

    final path = await (db.select(db.itemPaths)
          ..where((t) => t.itemId.equals(itemId)))
        .getSingleOrNull();
    final l1Id = path?.l1Id;
    FolderRow? l1;
    if (l1Id != null && l1Id.trim().isNotEmpty) {
      l1 = await (db.select(db.folders)
            ..where((t) => t.id.equals(l1Id) & t.isDeleted.equals(false)))
          .getSingleOrNull();
    }

    if (l1 == null ||
        isTemporaryFolderToken(l1.id) ||
        isTemporaryFolderToken(l1.name)) {
      missing.add('폴더 경로 필요');
    }

    return missing;
  }

  @override
  Future<bool> tryFinalizeRegistration(String itemId) async {
    final item = await getItem(itemId);
    if (item == null || !isNeedsRegistrationItem(item)) return false;

    final missing = await registrationMissingFields(itemId);
    if (missing.isNotEmpty) return false;

    final cleanedAttrs = cleanupRegistrationAttrs(item.attrs);
    await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        attrsJson: Value(
          cleanedAttrs == null ? null : jsonEncode(cleanedAttrs),
        ),
      ),
    );
    final fresh = await getItem(itemId);
    if (fresh != null) _cacheItem(fresh);
    notifyListeners();
    return true;
  }

  @override
  Future<void> deleteItem(String id) async {
    await _deleteItemImageFiles(id);
    await db.customStatement(
      'DELETE FROM item_images WHERE item_id = ?',
      [id],
    );
    await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
    await (db.delete(db.itemPaths)..where((t) => t.itemId.equals(id))).go();
    _itemsById.remove(id);
    _stockCache.remove(id);
  }

  @override
  Future<void> setFavorite(
      {required String itemId, required bool value}) async {
    await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(isFavorite: Value(value)),
    );
    final fresh = await getItem(itemId);
    if (fresh != null) _cacheItem(fresh);
  }

  @override
  Future<void> setFavoritesBulk(
      {required List<String> ids, required bool value}) async {
    if (ids.isEmpty) return;
    await db.transaction(() async {
      for (final id in ids) {
        await (db.update(db.items)..where((t) => t.id.equals(id)))
            .write(ItemsCompanion(isFavorite: Value(value)));
      }
    });
    notifyListeners();
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
    final join =
        db.select(i).join([leftOuterJoin(p, p.itemId.equalsExp(i.id))]);

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

    // ✅ 검색 교체
    if (keyword != null && keyword.trim().isNotEmpty) {
      join.where(
        _keywordExpr(i, keyword, scope: ItemSearchScope.full),
      );
    }

    if (lowOnly) {
      join.where(
          i.minQty.isBiggerThanValue(0) & i.qty.isSmallerOrEqual(i.minQty));
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
      l1: l1,
      l2: l2,
      l3: l3,
      keyword: keyword,
      recursive: recursive,
      lowOnly: false,
      favoritesOnly: false,
    ).map((all) {
      final low = all.where((e) => e.minQty > 0 && e.qty <= e.minQty).length;
      final fav = all.where((e) => e.isFavorite == true).length;
      return (low: low, fav: fav);
    });
  }

  @override
  Future<List<String>> itemPathNames(String itemId) async {
    final pathRow = await (db.select(db.itemPaths)
          ..where((t) => t.itemId.equals(itemId)))
        .getSingleOrNull();
    if (pathRow == null) return [];

    Future<String?> getFolderName(String? id) async {
      if (id == null) return null;
      final row = await (db.select(db.folders)..where((f) => f.id.equals(id)))
          .getSingleOrNull();
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
    final row = await (db.select(db.items)..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
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

  Future<void> moveItemToTrash(String id, {String? reason}) async {
    final path = await (db.select(db.itemPaths)
          ..where((t) => t.itemId.equals(id)))
        .getSingleOrNull();

    final extra = {
      'l1Id': path?.l1Id,
      'l2Id': path?.l2Id,
      'l3Id': path?.l3Id,
    };

    await (db.update(db.items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now().toIso8601String()),
        extra: Value(jsonEncode(extra)), // 🔥 이거 추가
      ),
    );

    notifyListeners();
  }
  //
  // @override
  // Future<void> moveItemsToTrash(List<String> ids, {String? reason}) async {
  //   if (ids.isEmpty) return;
  //
  //   await db.transaction(() async {
  //     final now = DateTime.now().toIso8601String();
  //     for (final id in ids) {
  //       await (db.update(db.items)
  //         ..where((t) => t.id.equals(id))).write(
  //         ItemsCompanion(
  //           isDeleted: const Value(true),
  //           deletedAt: Value(now),
  //         ),
  //       );
  //     }
  //   });
  //
  //   notifyListeners();
  // }

  Future<void> moveItemsToTrash(List<String> ids, {String? reason}) async {
    final now = DateTime.now().toIso8601String();

    for (final id in ids) {
      final path = await (db.select(db.itemPaths)
            ..where((t) => t.itemId.equals(id)))
          .getSingleOrNull();

      final extra = {
        'l1Id': path?.l1Id,
        'l2Id': path?.l2Id,
        'l3Id': path?.l3Id,
      };

      await (db.update(db.items)..where((t) => t.id.equals(id))).write(
        ItemsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          extra: Value(jsonEncode(extra)),
        ),
      );
    }

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
    await _deleteItemImageFiles(id);
    await db.customStatement(
      'DELETE FROM item_images WHERE item_id = ?',
      [id],
    );
    // 자식 테이블(FK) 정리 필요 시 여기서 먼저 처리하거나 FK를 CASCADE로
    await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
    notifyListeners();
  }

  Future<void> _deleteItemImageFiles(String itemId) async {
    final images = await getItemImages(itemId);
    const paths = AppPathService();
    for (final image in images) {
      try {
        final file = await paths.resolveAppFile(image.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    try {
      final dir = await paths.itemImageDirectory(itemId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  @override
  Future<void> addItemImage(ItemImage image) async {
    final filePath =
        await const AppPathService().normalizeToRelativePath(image.filePath);
    await db.customStatement(
      '''
      INSERT OR REPLACE INTO item_images
        (id, item_id, file_name, file_path, mime_type, created_at, sort_order, is_primary)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        image.id,
        image.itemId,
        image.fileName,
        filePath,
        image.mimeType,
        image.createdAt.toIso8601String(),
        image.sortOrder,
        image.isPrimary ? 1 : 0,
      ],
    );
    db.notifyUpdates({const TableUpdate('item_images')});
    notifyListeners();
  }

  @override
  Future<List<ItemImage>> getItemImages(String itemId) async {
    final rows = await db.customSelect(
      '''
      SELECT id, item_id, file_name, file_path, mime_type, created_at, sort_order, is_primary
      FROM item_images
      WHERE item_id = ?
      ORDER BY is_primary DESC, sort_order ASC, created_at DESC
      ''',
      variables: [Variable.withString(itemId)],
    ).get();
    return rows.map(_itemImageFromRow).toList();
  }

  @override
  Stream<List<ItemImage>> watchItemImages(String itemId) async* {
    yield await getItemImages(itemId);

    final updates = db
        .tableUpdates(const TableUpdateQuery.onTableName('item_images'))
        .map((_) => null);
    await for (final _ in updates) {
      yield await getItemImages(itemId);
    }
  }

  @override
  Future<void> deleteItemImage(String id) async {
    final rows = await db.customSelect(
      'SELECT file_path FROM item_images WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();

    if (rows.isNotEmpty) {
      final filePath = rows.first.data['file_path'] as String;
      try {
        final file = await const AppPathService().resolveAppFile(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    await db.customStatement('DELETE FROM item_images WHERE id = ?', [id]);
    db.notifyUpdates({const TableUpdate('item_images')});
    notifyListeners();
  }

  @override
  Future<int> countItemsWithImages() async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(DISTINCT item_id) AS count FROM item_images',
        )
        .get();
    return (rows.first.data['count'] as int?) ?? 0;
  }

  ItemImage _itemImageFromRow(QueryRow row) {
    final data = row.data;
    return ItemImage(
      id: data['id'] as String,
      itemId: data['item_id'] as String,
      fileName: data['file_name'] as String,
      filePath: data['file_path'] as String,
      mimeType: data['mime_type'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      sortOrder: data['sort_order'] as int? ?? 0,
      isPrimary: (data['is_primary'] as int? ?? 1) != 0,
    );
  }

  @override
  Future<int> getCurrentQty(String itemId) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    final qty = row?.qty ?? 0;
    // 캐시도 갱신해 두면 UI가 즉시 반영되기 쉬움
    _stockCache[itemId] = qty;
    return qty;
  }

  @override
  Future<bool> addToCurrentQty(String itemId, int delta) async {
    // 음수 방지까지 한 번에 처리하려면 "조건부 UPDATE"가 가장 안전(경쟁조건 방지)
    // qty + :delta >= 0 인 경우에만 업데이트
    final updatedCount = await db.customUpdate(
      'UPDATE items SET qty = qty + ? '
      'WHERE id = ? AND is_deleted = 0 AND (qty + ?) >= 0',
      variables: [
        Variable.withInt(delta),
        Variable.withString(itemId),
        Variable.withInt(delta),
      ],
      updates: {db.items},
    );

    final ok = updatedCount == 1;

    // 캐시 반영
    if (ok) {
      final cur = _stockCache[itemId] ?? 0;
      _stockCache[itemId] = cur + delta;
      notifyListeners(); // 사용 중이면
    }
    return ok;
  }

  /// ✅ 전체 수량(= qty 합계)을 실시간 스트림으로 제공
  /// - watchItems 와 동일한 필터(l1/l2/l3/keyword/recursive/favoritesOnly) 지원
  Stream<int> watchTotalQty({
    String? l1,
    String? l2,
    String? l3,
    String? keyword,
    bool recursive = false,
    bool favoritesOnly = false,
  }) {
    final i = db.items;
    final p = db.itemPaths;

    final join = db.selectOnly(i).join([
      leftOuterJoin(p, p.itemId.equalsExp(i.id)),
    ]);

    // 컬럼: qty 합계
    final qtySum = i.qty.sum();
    join.addColumns([qtySum]);

    // 휴지통 제외
    join.where(i.isDeleted.equals(false));

    // 경로 필터
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

    // ✅ 키워드 필터(목록과 동일 조건)
    if (keyword != null && keyword.trim().isNotEmpty) {
      join.where(
        _keywordExpr(i, keyword, scope: ItemSearchScope.full),
      );
    }

    // 즐겨찾기만
    if (favoritesOnly) {
      join.where(i.isFavorite.equals(true));
    }

    return join.watchSingle().map((row) {
      final v = row.read(qtySum);
      return v ?? 0;
    });
  }

  /// (옵션) 한 번만 읽는 버전
  Future<int> getTotalQty({
    String? l1,
    String? l2,
    String? l3,
    String? keyword,
    bool recursive = false,
    bool favoritesOnly = false,
  }) async {
    return await watchTotalQty(
      l1: l1,
      l2: l2,
      l3: l3,
      keyword: keyword,
      recursive: recursive,
      favoritesOnly: favoritesOnly,
    ).first;
  }
}
