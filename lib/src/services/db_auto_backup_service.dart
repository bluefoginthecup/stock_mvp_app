import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../db/app_database.dart';

class DbAutoBackupService {

  static const int maxBackups = 10;

  /// 앱 시작 시 실행
  static Future<void> run() async {

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');

    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      return;
    }

    await _backupOncePerDay(dbFile, dir);
    await _cleanupOldBackups(dir);
  }

  /// migration 전에 실행 (Crash-safe)
  static Future<void> createPreMigrationBackup() async {

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');

    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      return;
    }

    final backupPath = p.join(dir.path, 'stockapp_pre_migration_backup.db');

    await dbFile.copy(backupPath);
  }

  /// 하루 1회 백업
  static Future<void> _backupOncePerDay(File dbFile, Directory dir) async {

    final backupDir = Directory(p.join(dir.path, 'db_backups'));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final today = DateFormat('yyyyMMdd').format(DateTime.now());

    final existing = backupDir.listSync().whereType<File>().where((f) {
      return f.path.contains(today);
    });

    if (existing.isNotEmpty) {
      return;
    }

    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());

    final backupPath = p.join(
      backupDir.path,
      'stockapp_backup_$stamp.db',
    );

    // 🔥 SQLite 공식 백업
    final db = AppDatabase();
    await db.customStatement("VACUUM INTO '$backupPath'");
  }

  /// 오래된 백업 삭제
  static Future<void> _cleanupOldBackups(Directory dir) async {

    final backupDir = Directory(p.join(dir.path, 'db_backups'));

    if (!await backupDir.exists()) return;

    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    files.sort((a, b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    if (files.length <= maxBackups) return;

    for (final f in files.skip(maxBackups)) {
      await f.delete();
    }
  }
}