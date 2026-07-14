import 'dart:typed_data';

import '../db/app_database.dart';

class StampImageService {
  final AppDatabase db;

  const StampImageService(this.db);

  Future<Uint8List?> load() async {
    await ensureTable();
    final row = await db.customSelect(
      'SELECT image_bytes FROM stamp_settings WHERE id = 1',
    ).getSingleOrNull();
    return row?.read<Uint8List>('image_bytes');
  }

  Future<void> save(Uint8List bytes) async {
    await ensureTable();
    await db.customStatement(
      '''
      INSERT INTO stamp_settings (id, image_bytes, updated_at)
      VALUES (1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        image_bytes = excluded.image_bytes,
        updated_at = excluded.updated_at
      ''',
      [bytes, DateTime.now().toIso8601String()],
    );
  }

  Future<void> delete() async {
    await ensureTable();
    await db.customStatement('DELETE FROM stamp_settings WHERE id = 1');
  }

  Future<void> ensureTable() => db.customStatement('''
        CREATE TABLE IF NOT EXISTS stamp_settings (
          id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
          image_bytes BLOB NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
}
