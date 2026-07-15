import 'package:drift/drift.dart';

import '../db/app_database.dart';

class PlayAutoOrderLink {
  const PlayAutoOrderLink({
    required this.externalOrderNo,
    required this.orderId,
    required this.shopName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String externalOrderNo;
  final String orderId;
  final String shopName;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PlayAutoOrderLinkService {
  PlayAutoOrderLinkService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  var _ready = false;

  Future<Map<String, PlayAutoOrderLink>> listByOrderNos(
    Iterable<String> orderNos,
  ) async {
    await _ensureTable();
    final keys = orderNos
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty && key != '-')
        .toSet()
        .toList();
    if (keys.isEmpty) return const {};

    final placeholders = List.filled(keys.length, '?').join(', ');
    final rows = await _db.customSelect(
      '''
      SELECT *
      FROM playauto_order_links
      WHERE external_order_no IN ($placeholders)
      ''',
      variables: keys.map((key) => Variable<String>(key)).toList(),
    ).get();

    return {
      for (final row in rows)
        row.read<String>('external_order_no'): _fromRow(row),
    };
  }

  Future<void> save({
    required String externalOrderNo,
    required String orderId,
    required String shopName,
  }) async {
    await _ensureTable();
    final now = DateTime.now().toIso8601String();
    await _db.customStatement(
      '''
      INSERT INTO playauto_order_links (
        external_order_no, order_id, shop_name, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(external_order_no) DO UPDATE SET
        order_id = excluded.order_id,
        shop_name = excluded.shop_name,
        updated_at = excluded.updated_at
      ''',
      [externalOrderNo, orderId, shopName, now, now],
    );
  }

  Future<void> _ensureTable() async {
    if (_ready) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS playauto_order_links (
        external_order_no TEXT PRIMARY KEY,
        provider TEXT NOT NULL DEFAULT 'playauto',
        order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        shop_name TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_playauto_order_links_order_id '
      'ON playauto_order_links(order_id)',
    );
    _ready = true;
  }

  PlayAutoOrderLink _fromRow(QueryRow row) {
    return PlayAutoOrderLink(
      externalOrderNo: row.read<String>('external_order_no'),
      orderId: row.read<String>('order_id'),
      shopName: row.read<String>('shop_name'),
      createdAt: DateTime.tryParse(row.read<String>('created_at')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(row.read<String>('updated_at')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
