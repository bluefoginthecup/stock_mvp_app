import '../../db/app_database.dart';
import 'package:drift/drift.dart';

class MemoRepo {
  final db = AppDatabase.instance;

  Future<MemoRow?> loadRow() async {
    return db.select(db.memos).getSingleOrNull();
  }

  Future<String> load() async {
    final memo = await db.select(db.memos).getSingleOrNull();
    return memo?.content ?? '';
  }

  Future<int> saveAndReturnId(String text) async {
    final existing = await db.select(db.memos).getSingleOrNull();

    if (existing == null) {
      return db.into(db.memos).insert(
            MemosCompanion(
              content: Value(text),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (db.update(db.memos)..where((t) => t.id.equals(existing.id))).write(
        MemosCompanion(
          content: Value(text),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return existing.id;
    }
  }

  Future<void> save(String text) async {
    await saveAndReturnId(text);
  }
}
