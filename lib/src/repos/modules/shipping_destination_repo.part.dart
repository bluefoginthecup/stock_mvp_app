part of '../drift_unified_repo.dart';

mixin _ShippingDestinationRepoMixin on _RepoCore
    implements ShippingDestinationRepo {
  Future<void> _ensureShippingDestinationTables() async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS shipping_destinations (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        contact_name TEXT NULL,
        phone TEXT NULL,
        memo TEXT NULL,
        map_image_path TEXT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS supplier_shipping_destinations (
        supplier_id TEXT NOT NULL,
        shipping_destination_id TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (supplier_id, shipping_destination_id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
        FOREIGN KEY (shipping_destination_id) REFERENCES shipping_destinations(id) ON DELETE CASCADE
      )
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_supplier_shipping_supplier
      ON supplier_shipping_destinations(supplier_id)
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_supplier_shipping_destination
      ON supplier_shipping_destinations(shipping_destination_id)
    ''');
  }

  @override
  Future<String> createShippingDestination(
      ShippingDestination destination) async {
    await _ensureShippingDestinationTables();
    await db.customStatement(
      '''
      INSERT OR REPLACE INTO shipping_destinations
        (id, name, address, contact_name, phone, memo, map_image_path,
         is_archived, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        destination.id,
        destination.name,
        destination.address,
        destination.contactName,
        destination.phone,
        destination.memo,
        destination.mapImagePath,
        destination.isArchived ? 1 : 0,
        destination.createdAt.toIso8601String(),
        destination.updatedAt.toIso8601String(),
      ],
    );
    db.notifyUpdates({const TableUpdate('shipping_destinations')});
    return destination.id;
  }

  @override
  Future<void> updateShippingDestination(
      ShippingDestination destination) async {
    await _ensureShippingDestinationTables();
    await db.customStatement(
      '''
      UPDATE shipping_destinations
      SET name = ?, address = ?, contact_name = ?, phone = ?, memo = ?,
          map_image_path = ?, is_archived = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        destination.name,
        destination.address,
        destination.contactName,
        destination.phone,
        destination.memo,
        destination.mapImagePath,
        destination.isArchived ? 1 : 0,
        destination.updatedAt.toIso8601String(),
        destination.id,
      ],
    );
    db.notifyUpdates({const TableUpdate('shipping_destinations')});
  }

  @override
  Future<void> archiveShippingDestination(String id) async {
    await _ensureShippingDestinationTables();
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      await db.customStatement(
        '''
        UPDATE shipping_destinations
        SET is_archived = 1, updated_at = ?
        WHERE id = ?
        ''',
        [now, id],
      );
      await db.customStatement(
        '''
        UPDATE supplier_shipping_destinations
        SET is_default = 0, updated_at = ?
        WHERE shipping_destination_id = ?
        ''',
        [now, id],
      );
    });
    db.notifyUpdates({
      const TableUpdate('shipping_destinations'),
      const TableUpdate('supplier_shipping_destinations'),
    });
  }

  @override
  Future<List<ShippingDestination>> listActiveShippingDestinations() async {
    await _ensureShippingDestinationTables();
    final rows = await db.customSelect(
      '''
      SELECT id, name, address, contact_name, phone, memo, map_image_path,
             is_archived, created_at, updated_at
      FROM shipping_destinations
      WHERE is_archived = 0
      ORDER BY name COLLATE NOCASE ASC, created_at ASC
      ''',
    ).get();
    return rows.map(_shippingDestinationFromRow).toList();
  }

  @override
  Future<List<ShippingDestination>> listDestinationsForSupplier(
      String supplierId) async {
    await _ensureShippingDestinationTables();
    final rows = await db.customSelect(
      '''
      SELECT d.id, d.name, d.address, d.contact_name, d.phone, d.memo,
             d.map_image_path, d.is_archived, d.created_at, d.updated_at
      FROM shipping_destinations d
      INNER JOIN supplier_shipping_destinations l
        ON l.shipping_destination_id = d.id
      WHERE l.supplier_id = ? AND d.is_archived = 0
      ORDER BY l.is_default DESC, d.name COLLATE NOCASE ASC
      ''',
      variables: [Variable.withString(supplierId)],
    ).get();
    return rows.map(_shippingDestinationFromRow).toList();
  }

  @override
  Future<ShippingDestination?> getDefaultDestinationForSupplier(
      String supplierId) async {
    await _ensureShippingDestinationTables();
    final row = await db.customSelect(
      '''
      SELECT d.id, d.name, d.address, d.contact_name, d.phone, d.memo,
             d.map_image_path, d.is_archived, d.created_at, d.updated_at
      FROM shipping_destinations d
      INNER JOIN supplier_shipping_destinations l
        ON l.shipping_destination_id = d.id
      WHERE l.supplier_id = ?
        AND l.is_default = 1
        AND d.is_archived = 0
      LIMIT 1
      ''',
      variables: [Variable.withString(supplierId)],
    ).getSingleOrNull();
    return row == null ? null : _shippingDestinationFromRow(row);
  }

  @override
  Future<List<Supplier>> listDefaultSuppliersForDestination(
      String destinationId) async {
    await _ensureShippingDestinationTables();
    final rows = await db.customSelect(
      '''
      SELECT s.*
      FROM suppliers s
      INNER JOIN supplier_shipping_destinations l
        ON l.supplier_id = s.id
      WHERE l.shipping_destination_id = ?
        AND l.is_default = 1
        AND s.is_active = 1
      ORDER BY s.name COLLATE NOCASE ASC
      ''',
      variables: [Variable.withString(destinationId)],
      readsFrom: {db.suppliers},
    ).get();
    return rows.map((row) => _supplierFromData(row.data)).toList();
  }

  @override
  Future<void> setDefaultDestinationForSupplier({
    required String supplierId,
    required String destinationId,
  }) async {
    await _ensureShippingDestinationTables();
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      await db.customStatement(
        '''
        UPDATE supplier_shipping_destinations
        SET is_default = 0, updated_at = ?
        WHERE supplier_id = ?
        ''',
        [now, supplierId],
      );
      await db.customStatement(
        '''
        INSERT INTO supplier_shipping_destinations
          (supplier_id, shipping_destination_id, is_default, created_at, updated_at)
        VALUES (?, ?, 1, ?, ?)
        ON CONFLICT(supplier_id, shipping_destination_id) DO UPDATE SET
          is_default = 1,
          updated_at = excluded.updated_at
        ''',
        [supplierId, destinationId, now, now],
      );
    });
    db.notifyUpdates({const TableUpdate('supplier_shipping_destinations')});
  }

  @override
  Future<void> setDefaultDestinationForSuppliers({
    required String destinationId,
    required Set<String> supplierIds,
  }) async {
    await _ensureShippingDestinationTables();
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      await db.customStatement(
        '''
        UPDATE supplier_shipping_destinations
        SET is_default = 0, updated_at = ?
        WHERE shipping_destination_id = ?
          AND is_default = 1
        ''',
        [now, destinationId],
      );

      for (final supplierId in supplierIds) {
        await db.customStatement(
          '''
          UPDATE supplier_shipping_destinations
          SET is_default = 0, updated_at = ?
          WHERE supplier_id = ?
          ''',
          [now, supplierId],
        );
        await db.customStatement(
          '''
          INSERT INTO supplier_shipping_destinations
            (supplier_id, shipping_destination_id, is_default, created_at, updated_at)
          VALUES (?, ?, 1, ?, ?)
          ON CONFLICT(supplier_id, shipping_destination_id) DO UPDATE SET
            is_default = 1,
            updated_at = excluded.updated_at
          ''',
          [supplierId, destinationId, now, now],
        );
      }
    });
    db.notifyUpdates({const TableUpdate('supplier_shipping_destinations')});
  }

  ShippingDestination _shippingDestinationFromRow(QueryRow row) {
    final data = row.data;
    return ShippingDestination(
      id: data['id'] as String,
      name: data['name'] as String,
      address: data['address'] as String? ?? '',
      contactName: data['contact_name'] as String?,
      phone: data['phone'] as String?,
      memo: data['memo'] as String?,
      mapImagePath: data['map_image_path'] as String?,
      isArchived: (data['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  Supplier _supplierFromData(Map<String, Object?> data) {
    return Supplier(
      id: data['id'] as String,
      name: data['name'] as String,
      contactName: data['contact_name'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      addr: data['addr'] as String?,
      fax: data['fax'] as String?,
      memo: data['memo'] as String?,
      businessNumber: data['business_number'] as String?,
      representative: data['representative'] as String?,
      businessType: data['business_type'] as String?,
      businessItem: data['business_item'] as String?,
      isActive: (data['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }
}
