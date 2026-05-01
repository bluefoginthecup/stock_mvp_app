import '../../db/app_database.dart';
import 'package:drift/drift.dart';

class MemoRepo {
  final db = AppDatabase.instance;

  Future<String> load() async {
    final memo = await db.select(db.memos).getSingleOrNull();
    return memo?.content ?? '';
  }

  Future<void> save(String text) async {
    final existing = await db.select(db.memos).getSingleOrNull();

    if (existing == null) {
      await db.into(db.memos).insert(
        MemosCompanion(
          content: Value(text),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await (db.update(db.memos)
        ..where((t) => t.id.equals(existing.id)))
          .write(
        MemosCompanion(
          content: Value(text),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}