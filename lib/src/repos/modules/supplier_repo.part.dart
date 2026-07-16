part of '../drift_unified_repo.dart';

mixin SupplierRepoMixin on _RepoCore implements SupplierRepo {
  @override
  Future<List<Supplier>> list({String? q, bool onlyActive = true}) async {
    final where = <String>[];
    final vars = <Variable>[];

    if (onlyActive) {
      where.add('is_active = ?');
      vars.add(const Variable<int>(1));
    }

    if (q != null && q.trim().isNotEmpty) {
      final k = '%${q.trim()}%';
      where.add(
        '(name LIKE ? OR contact_name LIKE ? OR phone LIKE ? OR email LIKE ? '
        'OR fax LIKE ? OR business_number LIKE ? OR representative LIKE ?)',
      );
      vars.addAll(List.generate(7, (_) => Variable<String>(k)));
    }

    final sql = StringBuffer('SELECT * FROM suppliers');
    if (where.isNotEmpty) {
      sql.write(' WHERE ${where.join(' AND ')}');
    }
    sql.write(' ORDER BY name ASC');

    final rows = await db.customSelect(sql.toString(), variables: vars).get();
    return rows.map(_supplierFromRow).toList();
  }

  @override
  Future<Supplier?> get(String id) async {
    final rows = await db.customSelect(
      'SELECT * FROM suppliers WHERE id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    if (rows.isEmpty) return null;
    return _supplierFromRow(rows.first);
  }

  @override
  Future<String> upsert(Supplier s) async {
    await db.customStatement(
      '''
      INSERT INTO suppliers (
        id, name, contact_name, phone, email, addr, memo, is_active,
        created_at, updated_at, fax, business_number, representative,
        business_type, business_item, is_purchase_supplier, is_customer
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        contact_name = excluded.contact_name,
        phone = excluded.phone,
        email = excluded.email,
        addr = excluded.addr,
        memo = excluded.memo,
        is_active = excluded.is_active,
        updated_at = excluded.updated_at,
        fax = excluded.fax,
        business_number = excluded.business_number,
        representative = excluded.representative,
        business_type = excluded.business_type,
        business_item = excluded.business_item,
        is_purchase_supplier = excluded.is_purchase_supplier,
        is_customer = excluded.is_customer
      ''',
      [
        s.id,
        s.name,
        s.contactName,
        s.phone,
        s.email,
        s.addr,
        s.memo,
        s.isActive ? 1 : 0,
        s.createdAt.toIso8601String(),
        s.updatedAt.toIso8601String(),
        s.fax,
        s.businessNumber,
        s.representative,
        s.businessType,
        s.businessItem,
        s.isPurchaseSupplier ? 1 : 0,
        s.isCustomer ? 1 : 0,
      ],
    );
    return s.id;
  }

  @override
  Future<void> softDelete(String id) async {
    await db.customStatement(
      'UPDATE suppliers SET is_active = 0, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  @override
  Future<void> toggleActive(String id, bool isActive) async {
    await db.customStatement(
      'UPDATE suppliers SET is_active = ?, updated_at = ? WHERE id = ?',
      [isActive ? 1 : 0, DateTime.now().toIso8601String(), id],
    );
  }

  @override
  Future<void> setRoles(
    Set<String> ids, {
    bool? isPurchaseSupplier,
    bool? isCustomer,
  }) async {
    if (ids.isEmpty || (isPurchaseSupplier == null && isCustomer == null)) {
      return;
    }
    final assignments = <String>[];
    final values = <Object?>[];
    if (isPurchaseSupplier != null) {
      assignments.add('is_purchase_supplier = ?');
      values.add(isPurchaseSupplier ? 1 : 0);
    }
    if (isCustomer != null) {
      assignments.add('is_customer = ?');
      values.add(isCustomer ? 1 : 0);
    }
    assignments.add('updated_at = ?');
    values.add(DateTime.now().toIso8601String());
    final placeholders = List.filled(ids.length, '?').join(', ');
    values.addAll(ids);
    await db.customStatement(
      'UPDATE suppliers SET ${assignments.join(', ')} '
      'WHERE id IN ($placeholders)',
      values,
    );
  }

  @override
  Future<SupplierMergePreview> previewMerge({
    required String targetId,
    required Set<String> sourceIds,
  }) async {
    final normalizedSourceIds = sourceIds.where((id) => id != targetId).toSet();
    final target = await get(targetId);
    if (target == null) {
      throw ArgumentError('병합할 대표 거래처를 찾을 수 없습니다.');
    }
    final sources = <Supplier>[];
    for (final id in normalizedSourceIds) {
      final supplier = await get(id);
      if (supplier != null) sources.add(supplier);
    }
    if (sources.length != normalizedSourceIds.length) {
      throw ArgumentError('병합할 거래처 중 찾을 수 없는 항목이 있습니다.');
    }

    return SupplierMergePreview(
      target: target,
      sources: sources,
      purchaseOrders: await _countSupplierReferences(
        'purchase_orders',
        'supplier_id',
        normalizedSourceIds,
      ),
      quotes: await _countSupplierReferences(
        'quotes',
        'customer_id',
        normalizedSourceIds,
      ),
      items: await _countSupplierReferences(
        'items',
        'default_supplier_uid',
        normalizedSourceIds,
      ),
      contacts: await _countSupplierReferences(
        'supplier_contacts',
        'supplier_id',
        normalizedSourceIds,
      ),
      accounts: await _countSupplierReferences(
        'supplier_accounts',
        'supplier_id',
        normalizedSourceIds,
      ),
      shippingDestinations: await _countSupplierReferences(
        'supplier_shipping_destinations',
        'supplier_id',
        normalizedSourceIds,
      ),
    );
  }

  @override
  Future<void> mergeInto({
    required String targetId,
    required Set<String> sourceIds,
  }) async {
    final normalizedSourceIds = sourceIds.where((id) => id != targetId).toSet();
    if (normalizedSourceIds.isEmpty) return;

    await db.transaction(() async {
      final preview = await previewMerge(
        targetId: targetId,
        sourceIds: normalizedSourceIds,
      );
      final now = DateTime.now();
      final target = _mergeSupplierFields(preview.target, preview.sources, now);
      await upsert(target);

      final placeholders =
          List.filled(normalizedSourceIds.length, '?').join(', ');
      final values = normalizedSourceIds.toList();

      await db.customStatement(
        '''
        UPDATE purchase_orders
        SET supplier_id = ?, supplier_name = ?, updated_at = ?
        WHERE supplier_id IN ($placeholders)
        ''',
        [targetId, target.name, now.toIso8601String(), ...values],
      );
      await db.customStatement(
        '''
        UPDATE quotes
        SET customer_id = ?, customer_name = ?, updated_at = ?
        WHERE customer_id IN ($placeholders)
        ''',
        [targetId, target.name, now.toIso8601String(), ...values],
      );
      await db.customStatement(
        '''
        UPDATE items
        SET default_supplier_uid = ?, supplier_name = ?
        WHERE default_supplier_uid IN ($placeholders)
        ''',
        [targetId, target.name, ...values],
      );
      await db.customStatement(
        '''
        UPDATE supplier_contacts
        SET supplier_id = ?
        WHERE supplier_id IN ($placeholders)
        ''',
        [targetId, ...values],
      );
      await db.customStatement(
        '''
        UPDATE supplier_accounts
        SET supplier_id = ?
        WHERE supplier_id IN ($placeholders)
        ''',
        [targetId, ...values],
      );
      await db.customStatement(
        '''
        INSERT OR IGNORE INTO supplier_shipping_destinations (
          supplier_id, shipping_destination_id, is_default, created_at, updated_at
        )
        SELECT ?, shipping_destination_id, 0, created_at, ?
        FROM supplier_shipping_destinations
        WHERE supplier_id IN ($placeholders)
        ''',
        [targetId, now.toIso8601String(), ...values],
      );
      await db.customStatement(
        '''
        DELETE FROM supplier_shipping_destinations
        WHERE supplier_id IN ($placeholders)
        ''',
        values,
      );

      for (final source in preview.sources) {
        await db.customStatement(
          '''
          UPDATE suppliers
          SET is_active = 0, updated_at = ?, memo = ?
          WHERE id = ?
          ''',
          [
            now.toIso8601String(),
            _appendMemo(
              source.memo,
              '병합됨: ${target.name} (${target.id})로 이동',
            ),
            source.id,
          ],
        );
      }
    });
  }

  @override
  Future<List<SupplierContact>> listContacts(String supplierId) async {
    final rows = await db.customSelect(
      '''
      SELECT * FROM supplier_contacts
      WHERE supplier_id = ?
      ORDER BY is_primary DESC, sort_order ASC, name ASC
      ''',
      variables: [Variable<String>(supplierId)],
    ).get();

    return rows.map(_supplierContactFromRow).toList();
  }

  @override
  Future<void> replaceContacts(
    String supplierId,
    List<SupplierContact> contacts,
  ) async {
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM supplier_contacts WHERE supplier_id = ?',
        [supplierId],
      );

      for (final c in contacts) {
        await db.customStatement(
          '''
          INSERT INTO supplier_contacts (
            id, supplier_id, name, role_or_memo, phone, fax, email, address,
            is_primary, sort_order
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            c.id,
            supplierId,
            c.name,
            c.roleOrMemo,
            c.phone,
            c.fax,
            c.email,
            c.address,
            c.isPrimary ? 1 : 0,
            c.sortOrder,
          ],
        );
      }
    });
  }

  @override
  Future<List<SupplierAccount>> listAccounts(String supplierId) async {
    final rows = await db.customSelect(
      '''
      SELECT * FROM supplier_accounts
      WHERE supplier_id = ?
      ORDER BY is_primary DESC, sort_order ASC, bank_name ASC
      ''',
      variables: [Variable<String>(supplierId)],
    ).get();

    return rows.map(_supplierAccountFromRow).toList();
  }

  @override
  Future<void> replaceAccounts(
    String supplierId,
    List<SupplierAccount> accounts,
  ) async {
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM supplier_accounts WHERE supplier_id = ?',
        [supplierId],
      );

      for (final a in accounts) {
        await db.customStatement(
          '''
          INSERT INTO supplier_accounts (
            id, supplier_id, bank_name, account_number, account_holder, memo,
            is_primary, sort_order
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            a.id,
            supplierId,
            a.bankName,
            a.accountNumber,
            a.accountHolder,
            a.memo,
            a.isPrimary ? 1 : 0,
            a.sortOrder,
          ],
        );
      }
    });
  }

  Supplier _supplierFromRow(QueryRow row) {
    final data = row.data;
    return Supplier(
      id: data['id'] as String,
      name: data['name'] as String,
      contactName: data['contact_name'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      addr: data['addr'] as String?,
      memo: data['memo'] as String?,
      fax: data['fax'] as String?,
      businessNumber: data['business_number'] as String?,
      representative: data['representative'] as String?,
      businessType: data['business_type'] as String?,
      businessItem: data['business_item'] as String?,
      isActive: (data['is_active'] as int? ?? 1) == 1,
      isPurchaseSupplier: (data['is_purchase_supplier'] as int? ?? 0) == 1,
      isCustomer: (data['is_customer'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  Future<int> _countSupplierReferences(
    String table,
    String column,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return 0;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM $table WHERE $column IN ($placeholders)',
          variables: ids.map((id) => Variable<String>(id)).toList(),
        )
        .getSingle();
    return row.data['c'] as int? ?? 0;
  }

  Supplier _mergeSupplierFields(
    Supplier target,
    List<Supplier> sources,
    DateTime now,
  ) {
    String? firstValue(String? Function(Supplier supplier) pick) {
      for (final source in sources) {
        final value = pick(source)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    String? fill(String? current, String? fallback) {
      final trimmed = current?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return current;
      return fallback;
    }

    final mergeLines =
        sources.map((source) => '- ${source.name} (${source.id})').join('\n');
    final mergedMemo = _appendMemo(
      target.memo,
      '거래처 병합 이력\n$mergeLines',
    );

    return target.copyWith(
      contactName: fill(target.contactName, firstValue((s) => s.contactName)),
      phone: fill(target.phone, firstValue((s) => s.phone)),
      email: fill(target.email, firstValue((s) => s.email)),
      addr: fill(target.addr, firstValue((s) => s.addr)),
      memo: mergedMemo,
      fax: fill(target.fax, firstValue((s) => s.fax)),
      businessNumber:
          fill(target.businessNumber, firstValue((s) => s.businessNumber)),
      representative:
          fill(target.representative, firstValue((s) => s.representative)),
      businessType:
          fill(target.businessType, firstValue((s) => s.businessType)),
      businessItem:
          fill(target.businessItem, firstValue((s) => s.businessItem)),
      isActive: true,
      isPurchaseSupplier:
          target.isPurchaseSupplier || sources.any((s) => s.isPurchaseSupplier),
      isCustomer: target.isCustomer || sources.any((s) => s.isCustomer),
      updatedAt: now,
    );
  }

  String _appendMemo(String? memo, String addition) {
    final base = memo?.trim();
    if (base == null || base.isEmpty) return addition;
    return '$base\n\n$addition';
  }

  SupplierContact _supplierContactFromRow(QueryRow row) {
    final data = row.data;
    return SupplierContact(
      id: data['id'] as String,
      supplierId: data['supplier_id'] as String,
      name: data['name'] as String,
      roleOrMemo: data['role_or_memo'] as String?,
      phone: data['phone'] as String?,
      fax: data['fax'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      isPrimary: (data['is_primary'] as int? ?? 0) == 1,
      sortOrder: data['sort_order'] as int? ?? 0,
    );
  }

  SupplierAccount _supplierAccountFromRow(QueryRow row) {
    final data = row.data;
    return SupplierAccount(
      id: data['id'] as String,
      supplierId: data['supplier_id'] as String,
      bankName: data['bank_name'] as String,
      accountNumber: data['account_number'] as String,
      accountHolder: data['account_holder'] as String?,
      memo: data['memo'] as String?,
      isPrimary: (data['is_primary'] as int? ?? 0) == 1,
      sortOrder: data['sort_order'] as int? ?? 0,
    );
  }
}
