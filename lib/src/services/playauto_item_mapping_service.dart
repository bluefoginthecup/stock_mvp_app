import 'package:drift/drift.dart';

import '../db/app_database.dart';

class PlayAutoItemMapping {
  const PlayAutoItemMapping({
    required this.externalKey,
    required this.productName,
    required this.optionName,
    required this.sku,
    required this.shopName,
    required this.itemId,
    required this.status,
    required this.updatedAt,
  });

  final String externalKey;
  final String productName;
  final String optionName;
  final String sku;
  final String shopName;
  final String? itemId;
  final String status;
  final DateTime updatedAt;

  bool get isConfirmed => status == 'confirmed' && itemId != null;
  bool get isIgnored => status == 'ignored';
}

class PlayAutoItemMappingService {
  PlayAutoItemMappingService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  var _ready = false;

  Future<Map<String, PlayAutoItemMapping>> listByKeys(
    Iterable<String> externalKeys,
  ) async {
    await _ensureTable();
    final keys = externalKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet()
        .toList();
    if (keys.isEmpty) return const {};

    final placeholders = List.filled(keys.length, '?').join(', ');
    final rows = await _db.customSelect(
      '''
      SELECT *
      FROM playauto_item_mappings
      WHERE external_key IN ($placeholders)
      ''',
      variables: keys.map((key) => Variable<String>(key)).toList(),
    ).get();

    return {
      for (final row in rows) row.read<String>('external_key'): _fromRow(row),
    };
  }

  Future<void> saveConfirmed({
    required String externalKey,
    required String productName,
    required String optionName,
    required String sku,
    required String shopName,
    required String itemId,
  }) async {
    await _upsert(
      externalKey: externalKey,
      productName: productName,
      optionName: optionName,
      sku: sku,
      shopName: shopName,
      itemId: itemId,
      status: 'confirmed',
    );
  }

  Future<void> saveIgnored({
    required String externalKey,
    required String productName,
    required String optionName,
    required String sku,
    required String shopName,
  }) async {
    await _upsert(
      externalKey: externalKey,
      productName: productName,
      optionName: optionName,
      sku: sku,
      shopName: shopName,
      itemId: null,
      status: 'ignored',
    );
  }

  Future<void> delete(String externalKey) async {
    await _ensureTable();
    await _db.customStatement(
      'DELETE FROM playauto_item_mappings WHERE external_key = ?',
      [externalKey],
    );
  }

  Future<void> _upsert({
    required String externalKey,
    required String productName,
    required String optionName,
    required String sku,
    required String shopName,
    required String? itemId,
    required String status,
  }) async {
    await _ensureTable();
    final now = DateTime.now().toIso8601String();
    await _db.customStatement(
      '''
      INSERT INTO playauto_item_mappings (
        external_key, product_name, option_name, sku, shop_name, item_id,
        status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(external_key) DO UPDATE SET
        product_name = excluded.product_name,
        option_name = excluded.option_name,
        sku = excluded.sku,
        shop_name = excluded.shop_name,
        item_id = excluded.item_id,
        status = excluded.status,
        updated_at = excluded.updated_at
      ''',
      [
        externalKey,
        productName,
        optionName,
        sku,
        shopName,
        itemId,
        status,
        now,
        now,
      ],
    );
  }

  Future<void> _ensureTable() async {
    if (_ready) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS playauto_item_mappings (
        external_key TEXT PRIMARY KEY,
        provider TEXT NOT NULL DEFAULT 'playauto',
        product_name TEXT NOT NULL,
        option_name TEXT NOT NULL DEFAULT '',
        sku TEXT NOT NULL DEFAULT '',
        shop_name TEXT NOT NULL DEFAULT '',
        item_id TEXT NULL REFERENCES items(id) ON DELETE SET NULL,
        status TEXT NOT NULL DEFAULT 'confirmed',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_playauto_item_mappings_item_id '
      'ON playauto_item_mappings(item_id)',
    );
    _ready = true;
  }

  PlayAutoItemMapping _fromRow(QueryRow row) {
    return PlayAutoItemMapping(
      externalKey: row.read<String>('external_key'),
      productName: row.read<String>('product_name'),
      optionName: row.read<String>('option_name'),
      sku: row.read<String>('sku'),
      shopName: row.read<String>('shop_name'),
      itemId: row.data['item_id'] as String?,
      status: row.read<String>('status'),
      updatedAt: DateTime.tryParse(row.read<String>('updated_at')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
