part of '../drift_unified_repo.dart';

mixin _StorageLocationRepoMixin on _RepoCore implements StorageLocationRepo {
  @override
  Future<String> createLocation(StorageLocation location) async {
    await db.customStatement(
      '''
      INSERT OR REPLACE INTO storage_locations
        (id, name, parent_id, type, memo, sort_order, is_archived, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        location.id,
        location.name,
        location.parentId,
        location.type,
        location.memo,
        location.sortOrder,
        location.isArchived ? 1 : 0,
        location.createdAt.toIso8601String(),
        location.updatedAt.toIso8601String(),
      ],
    );
    db.notifyUpdates({const TableUpdate('storage_locations')});
    return location.id;
  }

  @override
  Future<void> updateLocation(StorageLocation location) async {
    await db.customStatement(
      '''
      UPDATE storage_locations
      SET name = ?, parent_id = ?, type = ?, memo = ?, sort_order = ?,
          is_archived = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        location.name,
        location.parentId,
        location.type,
        location.memo,
        location.sortOrder,
        location.isArchived ? 1 : 0,
        location.updatedAt.toIso8601String(),
        location.id,
      ],
    );
    db.notifyUpdates({const TableUpdate('storage_locations')});
  }

  @override
  Future<void> archiveLocation(String locationId) async {
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      await db.customStatement(
        '''
        UPDATE storage_locations
        SET is_archived = 1, updated_at = ?
        WHERE id = ?
        ''',
        [now, locationId],
      );
      await db.customStatement(
        '''
        UPDATE item_locations
        SET is_primary = 0, updated_at = ?
        WHERE location_id = ?
        ''',
        [now, locationId],
      );
    });
    db.notifyUpdates({
      const TableUpdate('storage_locations'),
      const TableUpdate('item_locations'),
    });
  }

  @override
  Future<StorageLocation?> getLocation(String locationId) async {
    final row = await db.customSelect(
      '''
      SELECT id, name, parent_id, type, memo, sort_order, is_archived,
             created_at, updated_at
      FROM storage_locations
      WHERE id = ? AND is_archived = 0
      LIMIT 1
      ''',
      variables: [Variable.withString(locationId)],
    ).getSingleOrNull();
    return row == null ? null : _storageLocationFromRow(row);
  }

  @override
  Future<List<StorageLocation>> listRootLocations() async {
    final rows = await db.customSelect(
      '''
      SELECT id, name, parent_id, type, memo, sort_order, is_archived,
             created_at, updated_at
      FROM storage_locations
      WHERE parent_id IS NULL AND is_archived = 0
      ORDER BY sort_order ASC, name COLLATE NOCASE ASC
      ''',
    ).get();
    return rows.map(_storageLocationFromRow).toList();
  }

  @override
  Future<List<StorageLocation>> listChildLocations(String parentId) async {
    final rows = await db.customSelect(
      '''
      SELECT id, name, parent_id, type, memo, sort_order, is_archived,
             created_at, updated_at
      FROM storage_locations
      WHERE parent_id = ? AND is_archived = 0
      ORDER BY sort_order ASC, name COLLATE NOCASE ASC
      ''',
      variables: [Variable.withString(parentId)],
    ).get();
    return rows.map(_storageLocationFromRow).toList();
  }

  @override
  Future<List<StorageLocation>> searchLocations(String query) async {
    final q = query.trim();
    final rows = await db
        .customSelect(
          q.isEmpty
              ? '''
          SELECT id, name, parent_id, type, memo, sort_order, is_archived,
                 created_at, updated_at
          FROM storage_locations
          WHERE is_archived = 0
          ORDER BY sort_order ASC, name COLLATE NOCASE ASC
          '''
              : '''
          SELECT id, name, parent_id, type, memo, sort_order, is_archived,
                 created_at, updated_at
          FROM storage_locations
          WHERE is_archived = 0
            AND (name LIKE ? OR type LIKE ? OR memo LIKE ?)
          ORDER BY sort_order ASC, name COLLATE NOCASE ASC
          ''',
          variables: q.isEmpty
              ? const []
              : [
                  Variable.withString('%$q%'),
                  Variable.withString('%$q%'),
                  Variable.withString('%$q%'),
                ],
        )
        .get();
    return rows.map(_storageLocationFromRow).toList();
  }

  @override
  Future<List<StorageLocation>> listLocationsForItem(String itemId) async {
    final rows = await db.customSelect(
      '''
      SELECT l.id, l.name, l.parent_id, l.type, l.memo, l.sort_order,
             l.is_archived, l.created_at, l.updated_at
      FROM storage_locations l
      INNER JOIN item_locations il ON il.location_id = l.id
      WHERE il.item_id = ? AND l.is_archived = 0
      ORDER BY il.is_primary DESC, l.sort_order ASC, l.name COLLATE NOCASE ASC
      ''',
      variables: [Variable.withString(itemId)],
    ).get();
    return rows.map(_storageLocationFromRow).toList();
  }

  @override
  Future<List<ItemLocation>> listItemLocationLinks(String itemId) async {
    final rows = await db.customSelect(
      '''
      SELECT item_id, location_id, is_primary, memo, updated_at
      FROM item_locations
      WHERE item_id = ?
      ''',
      variables: [Variable.withString(itemId)],
    ).get();
    return rows.map(_itemLocationFromRow).toList();
  }

  @override
  Future<List<Item>> listItemsForLocation(String locationId) async {
    final rows = await (db.select(db.items).join([
      innerJoin(
          db.itemLocations, db.itemLocations.itemId.equalsExp(db.items.id)),
    ])
          ..where(db.items.isDeleted.equals(false))
          ..where(db.itemLocations.locationId.equals(locationId))
          ..orderBy([
            OrderingTerm(
                expression: db.itemLocations.isPrimary,
                mode: OrderingMode.desc),
            OrderingTerm(expression: db.items.name, mode: OrderingMode.asc),
          ]))
        .get();
    final items =
        rows.map((row) => row.readTable(db.items).toDomain()).toList();
    _cacheItems(items);
    return items;
  }

  @override
  Future<List<ItemLocation>> listItemLocationsForLocation(
      String locationId) async {
    final rows = await db.customSelect(
      '''
      SELECT item_id, location_id, is_primary, memo, updated_at
      FROM item_locations
      WHERE location_id = ?
      ORDER BY is_primary DESC, item_id ASC
      ''',
      variables: [Variable.withString(locationId)],
    ).get();
    return rows.map(_itemLocationFromRow).toList();
  }

  @override
  Future<List<StorageLocation>> buildLocationBreadcrumb(
      String locationId) async {
    final all = await searchLocations('');
    final byId = {for (final location in all) location.id: location};
    final chain = <StorageLocation>[];
    var cursor = byId[locationId];
    while (cursor != null) {
      chain.insert(0, cursor);
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
    return chain;
  }

  @override
  Future<int> countChildLocations(String locationId) async {
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) AS c
      FROM storage_locations
      WHERE parent_id = ? AND is_archived = 0
      ''',
      variables: [Variable.withString(locationId)],
    ).getSingle();
    return row.data['c'] as int? ?? 0;
  }

  @override
  Future<int> countItemsForLocation(String locationId) async {
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) AS c
      FROM item_locations il
      INNER JOIN items i ON i.id = il.item_id
      WHERE il.location_id = ? AND i.is_deleted = 0
      ''',
      variables: [Variable.withString(locationId)],
    ).getSingle();
    return row.data['c'] as int? ?? 0;
  }

  @override
  Future<List<ItemWithLocations>> searchItemsWithLocations(String query) async {
    final raw = query.trim();
    if (raw.isEmpty) return const [];

    final itemQuery = db.select(db.items)
      ..where((item) => item.isDeleted.equals(false))
      ..where((item) => _locationItemKeywordExpr(item, raw))
      ..limit(80);
    final items = await itemQuery.get();
    final domainItems = items.map((item) => item.toDomain()).toList();
    _cacheItems(domainItems);
    if (domainItems.isEmpty) return const [];

    final itemIds = domainItems.map((item) => item.id).toList();
    final placeholders = List.filled(itemIds.length, '?').join(', ');
    final locationRows = await db.customSelect(
      '''
      SELECT il.item_id, il.location_id, il.is_primary, il.memo AS link_memo,
             il.updated_at AS link_updated_at,
             l.id, l.name, l.parent_id, l.type, l.memo, l.sort_order,
             l.is_archived, l.created_at, l.updated_at
      FROM item_locations il
      INNER JOIN storage_locations l ON l.id = il.location_id
      WHERE il.item_id IN ($placeholders)
        AND l.is_archived = 0
      ORDER BY il.item_id ASC, il.is_primary DESC, l.sort_order ASC, l.name COLLATE NOCASE ASC
      ''',
      variables: itemIds.map(Variable.withString).toList(),
    ).get();

    final allLocations = await searchLocations('');
    final pathByLocationId = <String, String>{
      for (final location in allLocations)
        location.id: _locationPathLabel(location, allLocations),
    };

    final locationsByItem = <String, List<StorageLocation>>{};
    final primaryByItem = <String, StorageLocation>{};
    for (final row in locationRows) {
      final itemId = row.data['item_id'] as String;
      final location = _storageLocationFromRow(row);
      (locationsByItem[itemId] ??= <StorageLocation>[]).add(location);
      if ((row.data['is_primary'] as int? ?? 0) == 1) {
        primaryByItem[itemId] = location;
      }
    }

    return [
      for (final item in domainItems)
        ItemWithLocations(
          item: item,
          primaryLocation: primaryByItem[item.id],
          locations: locationsByItem[item.id] ?? const [],
          primaryLocationPath: primaryByItem[item.id] == null
              ? null
              : pathByLocationId[primaryByItem[item.id]!.id],
          locationPaths: [
            for (final location in locationsByItem[item.id] ?? const [])
              pathByLocationId[location.id] ?? location.name,
          ],
        ),
    ];
  }

  @override
  Future<Map<String, ItemLocationSummary>> getLocationSummariesForItems(
    List<String> itemIds,
  ) async {
    final uniqueItemIds = <String>[
      for (final id in itemIds)
        if (id.trim().isNotEmpty) id.trim(),
    ].toSet().toList();
    if (uniqueItemIds.isEmpty) return const {};

    final placeholders = List.filled(uniqueItemIds.length, '?').join(', ');
    final rows = await db.customSelect(
      '''
      SELECT il.item_id, il.location_id, il.is_primary,
             l.id, l.name, l.parent_id, l.type, l.memo, l.sort_order,
             l.is_archived, l.created_at, l.updated_at
      FROM item_locations il
      INNER JOIN storage_locations l ON l.id = il.location_id
      WHERE il.item_id IN ($placeholders)
        AND l.is_archived = 0
      ORDER BY il.item_id ASC, il.is_primary DESC, l.sort_order ASC, l.name COLLATE NOCASE ASC
      ''',
      variables: uniqueItemIds.map(Variable.withString).toList(),
    ).get();

    final allLocations = await searchLocations('');
    final pathByLocationId = <String, String>{
      for (final location in allLocations)
        location.id: _locationPathLabel(location, allLocations),
    };

    final locationsByItem = <String, List<StorageLocation>>{};
    final primaryByItem = <String, StorageLocation>{};
    for (final row in rows) {
      final itemId = row.data['item_id'] as String;
      final location = _storageLocationFromRow(row);
      (locationsByItem[itemId] ??= <StorageLocation>[]).add(location);
      if ((row.data['is_primary'] as int? ?? 0) == 1) {
        primaryByItem[itemId] = location;
      }
    }

    final result = <String, ItemLocationSummary>{};
    for (final itemId in uniqueItemIds) {
      final locations = locationsByItem[itemId] ?? const <StorageLocation>[];
      if (locations.isEmpty) continue;
      final primary = primaryByItem[itemId] ?? locations.first;
      result[itemId] = ItemLocationSummary(
        primaryLocation: primary,
        primaryLocationPath: pathByLocationId[primary.id] ?? primary.name,
        locationCount: locations.length,
      );
    }
    return result;
  }

  @override
  Future<void> setPrimaryLocationForItems({
    required List<String> itemIds,
    required String locationId,
  }) async {
    final uniqueItemIds = <String>[
      for (final id in itemIds)
        if (id.trim().isNotEmpty) id.trim(),
    ].toSet().toList();
    if (uniqueItemIds.isEmpty || locationId.trim().isEmpty) return;

    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      for (final itemId in uniqueItemIds) {
        await db.customStatement(
          '''
          UPDATE item_locations
          SET is_primary = 0, updated_at = ?
          WHERE item_id = ?
          ''',
          [now, itemId],
        );
        await db.customStatement(
          '''
          INSERT INTO item_locations
            (item_id, location_id, is_primary, memo, updated_at)
          VALUES (?, ?, 1, NULL, ?)
          ON CONFLICT(item_id, location_id) DO UPDATE SET
            is_primary = 1,
            updated_at = excluded.updated_at
          ''',
          [itemId, locationId, now],
        );
      }
    });

    db.notifyUpdates({const TableUpdate('item_locations')});
  }

  @override
  Future<void> setLocationsForItem({
    required String itemId,
    required List<String> locationIds,
    String? primaryLocationId,
  }) async {
    final uniqueIds = <String>[
      for (final id in locationIds)
        if (id.trim().isNotEmpty) id.trim(),
    ].toSet().toList();
    final primaryId = uniqueIds.contains(primaryLocationId)
        ? primaryLocationId
        : (uniqueIds.isEmpty ? null : uniqueIds.first);
    final now = DateTime.now().toIso8601String();

    await db.transaction(() async {
      if (uniqueIds.isEmpty) {
        await db.customStatement(
          'DELETE FROM item_locations WHERE item_id = ?',
          [itemId],
        );
        return;
      }

      final placeholders = List.filled(uniqueIds.length, '?').join(', ');
      await db.customStatement(
        '''
        DELETE FROM item_locations
        WHERE item_id = ? AND location_id NOT IN ($placeholders)
        ''',
        [itemId, ...uniqueIds],
      );

      await db.customStatement(
        '''
        UPDATE item_locations
        SET is_primary = 0, updated_at = ?
        WHERE item_id = ?
        ''',
        [now, itemId],
      );

      for (final locationId in uniqueIds) {
        await db.customStatement(
          '''
          INSERT INTO item_locations
            (item_id, location_id, is_primary, memo, updated_at)
          VALUES (?, ?, ?, NULL, ?)
          ON CONFLICT(item_id, location_id) DO UPDATE SET
            is_primary = excluded.is_primary,
            updated_at = excluded.updated_at
          ''',
          [itemId, locationId, locationId == primaryId ? 1 : 0, now],
        );
      }
    });

    db.notifyUpdates({const TableUpdate('item_locations')});
  }

  @override
  Future<void> setPrimaryLocationForItem({
    required String itemId,
    required String locationId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      await db.customStatement(
        '''
        UPDATE item_locations
        SET is_primary = 0, updated_at = ?
        WHERE item_id = ?
        ''',
        [now, itemId],
      );
      await db.customStatement(
        '''
        INSERT INTO item_locations
          (item_id, location_id, is_primary, memo, updated_at)
        VALUES (?, ?, 1, NULL, ?)
        ON CONFLICT(item_id, location_id) DO UPDATE SET
          is_primary = 1,
          updated_at = excluded.updated_at
        ''',
        [itemId, locationId, now],
      );
    });
    db.notifyUpdates({const TableUpdate('item_locations')});
  }

  StorageLocation _storageLocationFromRow(QueryRow row) {
    final data = row.data;
    return StorageLocation(
      id: data['id'] as String,
      name: data['name'] as String,
      parentId: data['parent_id'] as String?,
      type: data['type'] as String? ?? StorageLocationType.custom,
      memo: data['memo'] as String?,
      sortOrder: data['sort_order'] as int? ?? 0,
      isArchived: (data['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  ItemLocation _itemLocationFromRow(QueryRow row) {
    final data = row.data;
    return ItemLocation(
      itemId: data['item_id'] as String,
      locationId: data['location_id'] as String,
      isPrimary: (data['is_primary'] as int? ?? 0) == 1,
      memo: data['memo'] as String?,
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  String _storageLocationEscapeLike(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Expression<bool> _locationItemKeywordExpr(Items item, String raw) {
    final q = raw.trim();
    if (q.isEmpty) return const Constant(true);

    final isCho = looksLikeChosungQuery(q);
    if (isCho) {
      final key = q.replaceAll(RegExp(r'\s+'), '');
      final like = '%${_storageLocationEscapeLike(key)}%';
      return item.searchInitials.like(like, escapeChar: '\\');
    }

    final tokens = q
        .split(RegExp(r'[\s,|/]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const Constant(false);

    Expression<bool> expr = const Constant(true);
    for (final token in tokens) {
      final normalized = normalizeForSearch(token);
      if (normalized.isEmpty) continue;
      final like = '%${_storageLocationEscapeLike(normalized)}%';
      final attrLike = '%${_storageLocationEscapeLike(token.toLowerCase())}%';
      expr = expr &
          (item.searchFullNormalized.like(like, escapeChar: '\\') |
              item.attrsJson.lower().like(attrLike, escapeChar: '\\'));
    }
    return expr;
  }

  String _locationPathLabel(
    StorageLocation location,
    List<StorageLocation> allLocations,
  ) {
    final byId = {for (final loc in allLocations) loc.id: loc};
    final names = <String>[location.name];
    var cursor = location.parentId == null ? null : byId[location.parentId];
    while (cursor != null) {
      names.insert(0, cursor.name);
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
    return names.join(' > ');
  }
}
