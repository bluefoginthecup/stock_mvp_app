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
        business_type, business_item
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        business_item = excluded.business_item
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
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
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
