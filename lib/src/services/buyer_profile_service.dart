import '../db/app_database.dart';
import '../models/buyer_profile.dart';

class BuyerProfileService {
  final AppDatabase db;

  const BuyerProfileService(this.db);

  Future<List<BuyerProfile>> listProfiles() async {
    await ensureTable();
    final rows = await db
        .customSelect(
          'SELECT * FROM buyer_profiles ORDER BY id ASC',
        )
        .get();
    return rows.map((row) => _fromRow(row.data)).toList();
  }

  Future<BuyerProfile> defaultProfile() async {
    final profiles = await listProfiles();
    final configured = profiles.where((profile) => profile.isConfigured);
    final defaultProfile = configured.where((profile) => profile.isDefault);
    if (defaultProfile.isNotEmpty) return defaultProfile.first;
    if (configured.isNotEmpty) return configured.first;
    return BuyerProfile.fallback();
  }

  Future<void> saveProfile(BuyerProfile profile) async {
    if (profile.id < 1 || profile.id > 2) {
      throw ArgumentError.value(
          profile.id, 'id', '공급받는자 정보는 2개까지만 저장할 수 있습니다.');
    }

    await ensureTable();
    await db.transaction(() async {
      if (profile.isDefault) {
        await db.customStatement(
          'UPDATE buyer_profiles SET is_default = 0 WHERE id != ?',
          [profile.id],
        );
      }
      await db.customStatement(
        '''
        INSERT INTO buyer_profiles (
          id, profile_name, business_number, company_name, representative,
          address, business_type, business_item, phone_fax, is_default, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          profile_name = excluded.profile_name,
          business_number = excluded.business_number,
          company_name = excluded.company_name,
          representative = excluded.representative,
          address = excluded.address,
          business_type = excluded.business_type,
          business_item = excluded.business_item,
          phone_fax = excluded.phone_fax,
          is_default = excluded.is_default,
          updated_at = excluded.updated_at
        ''',
        [
          profile.id,
          profile.profileName.trim(),
          profile.businessNumber.trim(),
          profile.companyName.trim(),
          profile.representative.trim(),
          profile.address.trim(),
          profile.businessType.trim(),
          profile.businessItem.trim(),
          profile.phoneFax.trim(),
          profile.isDefault ? 1 : 0,
          profile.updatedAt.toIso8601String(),
        ],
      );
    });
  }

  Future<void> ensureTable() {
    return db.customStatement('''
      CREATE TABLE IF NOT EXISTS buyer_profiles (
        id INTEGER PRIMARY KEY NOT NULL,
        profile_name TEXT NOT NULL DEFAULT '',
        business_number TEXT NOT NULL DEFAULT '',
        company_name TEXT NOT NULL DEFAULT '',
        representative TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        business_type TEXT NOT NULL DEFAULT '',
        business_item TEXT NOT NULL DEFAULT '',
        phone_fax TEXT NOT NULL DEFAULT '',
        is_default INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  BuyerProfile _fromRow(Map<String, Object?> data) {
    return BuyerProfile(
      id: (data['id'] as num).toInt(),
      profileName: data['profile_name'] as String? ?? '',
      businessNumber: data['business_number'] as String? ?? '',
      companyName: data['company_name'] as String? ?? '',
      representative: data['representative'] as String? ?? '',
      address: data['address'] as String? ?? '',
      businessType: data['business_type'] as String? ?? '',
      businessItem: data['business_item'] as String? ?? '',
      phoneFax: data['phone_fax'] as String? ?? '',
      isDefault: (data['is_default'] as num? ?? 0) != 0,
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
