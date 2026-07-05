import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../db/app_database.dart';
import 'app_path_service.dart';
import 'backup_hash_service.dart';
import 'full_backup_service.dart';
import 'restore_rollback_service.dart';

enum FullRestoreErrorCode {
  general,
  schemaTooNew,
  manifestInvalid,
  checksumMismatch,
  databaseInvalid,
  missingRequiredTables,
  rollbackFailed,
}

class FullRestoreException implements Exception {
  final String message;
  final FullRestoreErrorCode code;

  const FullRestoreException(
    this.message, {
    this.code = FullRestoreErrorCode.general,
  });

  @override
  String toString() => message;
}

class FullRestoreResult {
  final String backupId;
  final int dbSchemaVersion;
  final int missingAttachmentCount;
  final List<String> missingAttachmentPaths;

  const FullRestoreResult({
    required this.backupId,
    required this.dbSchemaVersion,
    this.missingAttachmentCount = 0,
    this.missingAttachmentPaths = const [],
  });
}

class FullRestoreService {
  static const _requiredTables = [
    'items',
    'folders',
    'txns',
    'orders',
    'works',
    'purchase_orders',
    'purchase_lines',
    'suppliers',
    'memos',
    'purchase_receipts',
  ];

  const FullRestoreService({
    this.paths = const AppPathService(),
    this.rollbackService = const RestoreRollbackService(),
    this.hashService = const BackupHashService(),
  });

  final AppPathService paths;
  final RestoreRollbackService rollbackService;
  final BackupHashService hashService;

  Future<FullRestoreResult> restoreFromZip(File zipFile) async {
    if (!await zipFile.exists()) {
      throw const FullRestoreException('선택한 백업 zip 파일을 찾을 수 없습니다.');
    }

    final appSupportDir = await paths.appSupportDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final workDir = Directory(
      p.join(appSupportDir.path, 'full_restore_tmp', stamp),
    );

    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
    await workDir.create(recursive: true);

    Directory? rollbackDir;

    try {
      final extracted = await _extractAndValidate(zipFile, workDir);
      final manifest = extracted.manifest;
      final backupSchemaVersion = _intValue(manifest['dbSchemaVersion']);
      final currentSchemaVersion = AppDatabase().schemaVersion;

      if (backupSchemaVersion > currentSchemaVersion) {
        throw FullRestoreException(
          '앱 업데이트 후 복원 필요: 백업 DB schemaVersion($backupSchemaVersion)이 '
          '현재 앱 schemaVersion($currentSchemaVersion)보다 높습니다.',
          code: FullRestoreErrorCode.schemaTooNew,
        );
      }

      await _validateExtractedSize(
        manifest,
        extracted.databaseFile,
        extracted.purchaseReceiptsDir,
        extracted.scheduleAttachmentsDir,
        extracted.itemImagesDir,
        extracted.productionGuidesDir,
      );
      await _validateChecksums(
        manifest,
        extracted.databaseFile,
        extracted.purchaseReceiptsDir,
        extracted.scheduleAttachmentsDir,
        extracted.itemImagesDir,
        extracted.productionGuidesDir,
      );
      _validateBackupDatabase(extracted.databaseFile);

      rollbackDir = await _createRollback(stamp);
      await _applyRestore(extracted);
      await _normalizeReceiptPaths();
      await _normalizeScheduleAttachmentPaths();
      await _normalizeItemImagePaths();
      final missingAttachmentPaths = await _findMissingReceiptFiles();
      await rollbackService.cleanupOldRollbacks();

      return FullRestoreResult(
        backupId: _stringValue(manifest['backupId']),
        dbSchemaVersion: backupSchemaVersion,
        missingAttachmentCount: missingAttachmentPaths.length,
        missingAttachmentPaths: missingAttachmentPaths,
      );
    } on FullRestoreException {
      rethrow;
    } catch (e) {
      if (rollbackDir != null) {
        try {
          await _rollback(rollbackDir);
        } catch (rollbackError) {
          throw FullRestoreException(
            '복원 실패 후 rollback도 실패했습니다. 앱 데이터 확인이 필요합니다: '
            '$rollbackError',
            code: FullRestoreErrorCode.rollbackFailed,
          );
        }
        throw FullRestoreException('복원 실패로 기존 데이터를 복구했습니다: $e');
      }
      throw FullRestoreException('전체 백업 zip 복원에 실패했습니다: $e');
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  Future<_ExtractedFullBackup> _extractAndValidate(
    File zipFile,
    Directory workDir,
  ) async {
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final manifestEntry = _entryByName(archive, 'manifest.json');
    final dbEntry = _entryByName(archive, 'stockapp.db');

    if (manifestEntry == null || !manifestEntry.isFile) {
      throw const FullRestoreException('manifest.json이 없는 전체 백업 zip입니다.');
    }
    if (dbEntry == null || !dbEntry.isFile) {
      throw const FullRestoreException('stockapp.db가 없는 전체 백업 zip입니다.');
    }

    final manifest = _readManifest(manifestEntry);
    _validateManifestShape(manifest);

    final dbFile = File(p.join(workDir.path, 'stockapp.db'));
    await dbFile.writeAsBytes(dbEntry.content, flush: true);

    final receiptsDir = Directory(
      p.join(workDir.path, AppPathService.purchaseReceiptsRelativeRoot),
    );
    await receiptsDir.create(recursive: true);
    final scheduleAttachmentsDir = Directory(
      p.join(workDir.path, AppPathService.scheduleAttachmentsRelativeRoot),
    );
    await scheduleAttachmentsDir.create(recursive: true);
    final itemImagesDir = Directory(
      p.join(workDir.path, AppPathService.itemImagesRelativeRoot),
    );
    await itemImagesDir.create(recursive: true);
    final productionGuidesDir = Directory(
      p.join(workDir.path, AppPathService.productionGuidesRelativeRoot),
    );
    await productionGuidesDir.create(recursive: true);

    for (final entry in archive.files) {
      if (entry.name
          .startsWith('${AppPathService.purchaseReceiptsRelativeRoot}/')) {
        await _extractBackupDirectoryEntry(
          entry,
          receiptsDir,
          AppPathService.purchaseReceiptsRelativeRoot,
        );
      } else if (entry.name
          .startsWith('${AppPathService.scheduleAttachmentsRelativeRoot}/')) {
        await _extractBackupDirectoryEntry(
          entry,
          scheduleAttachmentsDir,
          AppPathService.scheduleAttachmentsRelativeRoot,
        );
      } else if (entry.name
          .startsWith('${AppPathService.itemImagesRelativeRoot}/')) {
        await _extractBackupDirectoryEntry(
          entry,
          itemImagesDir,
          AppPathService.itemImagesRelativeRoot,
        );
      } else if (entry.name
          .startsWith('${AppPathService.productionGuidesRelativeRoot}/')) {
        await _extractBackupDirectoryEntry(
          entry,
          productionGuidesDir,
          AppPathService.productionGuidesRelativeRoot,
        );
      }
    }

    return _ExtractedFullBackup(
      manifest: manifest,
      databaseFile: dbFile,
      purchaseReceiptsDir: receiptsDir,
      scheduleAttachmentsDir: scheduleAttachmentsDir,
      itemImagesDir: itemImagesDir,
      productionGuidesDir: productionGuidesDir,
    );
  }

  ArchiveFile? _entryByName(Archive archive, String name) {
    for (final entry in archive.files) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  Map<String, Object?> _readManifest(ArchiveFile entry) {
    try {
      final decoded = jsonDecode(utf8.decode(entry.content));
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {
      // 아래의 명확한 메시지로 실패시킨다.
    }
    throw const FullRestoreException(
      'manifest.json 형식이 올바르지 않습니다.',
      code: FullRestoreErrorCode.manifestInvalid,
    );
  }

  void _validateManifestShape(Map<String, Object?> manifest) {
    final backupId = _stringValue(manifest['backupId']).trim();
    if (backupId.isEmpty) {
      throw const FullRestoreException(
        'manifest.json에 backupId가 없습니다.',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }

    final backupCreatedAt = _stringValue(manifest['backupCreatedAt']).trim();
    if (backupCreatedAt.isEmpty || DateTime.tryParse(backupCreatedAt) == null) {
      throw const FullRestoreException(
        'manifest.json의 backupCreatedAt 날짜 형식이 올바르지 않습니다.',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }

    final formatVersion = _intValue(manifest['backupFormatVersion']);
    if (formatVersion != FullBackupService.backupFormatVersion) {
      throw FullRestoreException(
        '지원하지 않는 백업 포맷입니다: $formatVersion',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }

    _intValue(manifest['dbSchemaVersion']);
    final totalSizeBytes = _intValue(manifest['totalSizeBytes']);
    if (totalSizeBytes < 0) {
      throw const FullRestoreException(
        'manifest.json의 totalSizeBytes 값이 올바르지 않습니다.',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }

    final includedFolders = manifest['includedFolders'];
    if (includedFolders is! List ||
        !includedFolders
            .map((value) => value.toString())
            .contains(AppPathService.purchaseReceiptsRelativeRoot)) {
      throw const FullRestoreException(
        'manifest.json의 includedFolders에 purchase_receipts가 없습니다.',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }
  }

  Future<void> _validateExtractedSize(
    Map<String, Object?> manifest,
    File dbFile,
    Directory receiptsDir,
    Directory scheduleAttachmentsDir,
    Directory itemImagesDir,
    Directory productionGuidesDir,
  ) async {
    final expectedSize = _intValue(manifest['totalSizeBytes']);
    final actualSize = await dbFile.length() +
        await _directorySize(receiptsDir) +
        await _directorySize(scheduleAttachmentsDir) +
        await _directorySize(itemImagesDir) +
        await _directorySize(productionGuidesDir);
    if (actualSize != expectedSize) {
      throw FullRestoreException(
        '백업 파일 크기 검증 실패: manifest totalSizeBytes=$expectedSize, '
        '실제 복원 대상 크기=$actualSize',
        code: FullRestoreErrorCode.checksumMismatch,
      );
    }
  }

  Future<void> _validateChecksums(
    Map<String, Object?> manifest,
    File dbFile,
    Directory receiptsDir,
    Directory scheduleAttachmentsDir,
    Directory itemImagesDir,
    Directory productionGuidesDir,
  ) async {
    final stockappDb = manifest['stockappDb'];
    if (stockappDb != null) {
      if (stockappDb is! Map) {
        throw const FullRestoreException(
          'manifest.json의 stockappDb 형식이 올바르지 않습니다.',
          code: FullRestoreErrorCode.manifestInvalid,
        );
      }
      await _validateFileHash(
        file: dbFile,
        expected: stockappDb,
        relativePath: 'stockapp.db',
      );
    }

    final receiptFiles = manifest['purchaseReceiptFiles'];
    if (receiptFiles == null) return;
    if (receiptFiles is! List) {
      throw const FullRestoreException(
        'manifest.json의 purchaseReceiptFiles 형식이 올바르지 않습니다.',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }

    final seen = <String>{};
    for (final entry in receiptFiles) {
      if (entry is! Map) {
        throw const FullRestoreException(
          'manifest.json의 첨부파일 checksum 항목 형식이 올바르지 않습니다.',
          code: FullRestoreErrorCode.manifestInvalid,
        );
      }
      final relativePath = _stringValue(entry['relativePath']);
      final normalized = _normalizeManifestReceiptPath(relativePath);
      if (!seen.add(normalized)) {
        throw FullRestoreException(
          'manifest.json에 중복 첨부파일 경로가 있습니다: $normalized',
          code: FullRestoreErrorCode.manifestInvalid,
        );
      }

      final file = File(
        p.joinAll([
          receiptsDir.path,
          ...p.posix.split(
            normalized.substring(
              AppPathService.purchaseReceiptsRelativeRoot.length + 1,
            ),
          ),
        ]),
      );
      if (!await file.exists()) {
        throw FullRestoreException(
          '백업 zip에 manifest 첨부파일이 없습니다: $normalized',
          code: FullRestoreErrorCode.checksumMismatch,
        );
      }
      await _validateFileHash(
        file: file,
        expected: entry,
        relativePath: normalized,
      );
    }

    await _validateManifestDirectoryHashes(
      manifestKey: 'scheduleAttachmentFiles',
      manifest: manifest,
      extractedRoot: scheduleAttachmentsDir,
      relativeRoot: AppPathService.scheduleAttachmentsRelativeRoot,
    );
    await _validateManifestDirectoryHashes(
      manifestKey: 'itemImageFiles',
      manifest: manifest,
      extractedRoot: itemImagesDir,
      relativeRoot: AppPathService.itemImagesRelativeRoot,
    );
    await _validateManifestDirectoryHashes(
      manifestKey: 'productionGuideFiles',
      manifest: manifest,
      extractedRoot: productionGuidesDir,
      relativeRoot: AppPathService.productionGuidesRelativeRoot,
    );
  }

  Future<void> _validateManifestDirectoryHashes({
    required String manifestKey,
    required Map<String, Object?> manifest,
    required Directory extractedRoot,
    required String relativeRoot,
  }) async {
    final entries = manifest[manifestKey];
    if (entries == null) return;
    if (entries is! List) {
      throw FullRestoreException(
        'manifest.json의 $manifestKey 형식이 올바르지 않습니다.',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }

    final seen = <String>{};
    for (final entry in entries) {
      if (entry is! Map) {
        throw FullRestoreException(
          'manifest.json의 $manifestKey 항목 형식이 올바르지 않습니다.',
          code: FullRestoreErrorCode.manifestInvalid,
        );
      }
      final relativePath = _stringValue(entry['relativePath']);
      final normalized = _normalizeManifestPath(relativePath, relativeRoot);
      if (!seen.add(normalized)) {
        throw FullRestoreException(
          'manifest.json에 중복 파일 경로가 있습니다: $normalized',
          code: FullRestoreErrorCode.manifestInvalid,
        );
      }

      final file = File(
        p.joinAll([
          extractedRoot.path,
          ...p.posix.split(normalized.substring(relativeRoot.length + 1)),
        ]),
      );
      if (!await file.exists()) {
        throw FullRestoreException(
          '백업 zip에 manifest 파일이 없습니다: $normalized',
          code: FullRestoreErrorCode.checksumMismatch,
        );
      }
      await _validateFileHash(
        file: file,
        expected: entry,
        relativePath: normalized,
      );
    }
  }

  Future<void> _validateFileHash({
    required File file,
    required Map expected,
    required String relativePath,
  }) async {
    final expectedSize = _intValue(expected['sizeBytes']);
    final expectedSha256 = _stringValue(expected['sha256']).trim();
    if (expectedSha256.isEmpty) {
      throw FullRestoreException(
        'manifest.json에 sha256 값이 없습니다: $relativePath',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }

    final actualHash = await hashService.hashFile(
      file: file,
      relativePath: relativePath,
    );
    if (actualHash.sizeBytes != expectedSize ||
        actualHash.sha256 != expectedSha256) {
      throw FullRestoreException(
        '백업 파일 checksum 검증 실패: $relativePath',
        code: FullRestoreErrorCode.checksumMismatch,
      );
    }
  }

  String _normalizeManifestReceiptPath(String relativePath) {
    return _normalizeManifestPath(
      relativePath,
      AppPathService.purchaseReceiptsRelativeRoot,
    );
  }

  String _normalizeManifestPath(String relativePath, String relativeRoot) {
    final normalized = p.posix.normalize(relativePath.replaceAll('\\', '/'));
    if (!normalized.startsWith('$relativeRoot/') ||
        normalized.contains('../') ||
        p.posix.isAbsolute(normalized)) {
      throw FullRestoreException(
        'manifest.json에 안전하지 않은 파일 경로가 있습니다: $relativePath',
        code: FullRestoreErrorCode.manifestInvalid,
      );
    }
    return normalized;
  }

  void _validateBackupDatabase(File dbFile) {
    sqlite.Database? database;
    try {
      database = sqlite.sqlite3.open(dbFile.path);

      final integrityRows = database.select('PRAGMA integrity_check');
      final integrityResult = integrityRows.isEmpty
          ? ''
          : integrityRows.first.values.first?.toString() ?? '';
      if (integrityResult.toLowerCase() != 'ok') {
        throw FullRestoreException(
          '백업 DB integrity_check 실패: $integrityResult',
          code: FullRestoreErrorCode.databaseInvalid,
        );
      }

      final tableRows = database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tableRows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();
      final missingTables = _requiredTables
          .where((tableName) => !tableNames.contains(tableName))
          .toList();
      if (missingTables.isNotEmpty) {
        throw FullRestoreException(
          '백업 DB에 필수 테이블이 없습니다: ${missingTables.join(', ')}',
          code: FullRestoreErrorCode.missingRequiredTables,
        );
      }
    } on FullRestoreException {
      rethrow;
    } catch (e) {
      throw FullRestoreException(
        '백업 DB 검증에 실패했습니다: $e',
        code: FullRestoreErrorCode.databaseInvalid,
      );
    } finally {
      database?.dispose();
    }
  }

  Future<void> _extractBackupDirectoryEntry(
    ArchiveFile entry,
    Directory targetRoot,
    String relativeRoot,
  ) async {
    final relativePath = _backupDirectoryEntryRelativePath(
      entry.name,
      relativeRoot,
    );
    if (relativePath == null) return;

    final target =
        File(p.joinAll([targetRoot.path, ...p.posix.split(relativePath)]));
    if (!_isWithin(targetRoot.path, target.path)) {
      throw FullRestoreException('안전하지 않은 zip 경로가 포함되어 있습니다: ${entry.name}');
    }

    if (entry.isDirectory) {
      await Directory(target.path).create(recursive: true);
      return;
    }

    await target.parent.create(recursive: true);
    await target.writeAsBytes(entry.content, flush: true);
  }

  String? _backupDirectoryEntryRelativePath(
    String entryName,
    String relativeRoot,
  ) {
    if (entryName == relativeRoot || entryName == '$relativeRoot/') return '';
    if (!entryName.startsWith('$relativeRoot/')) return null;

    final relativePath = entryName.substring(relativeRoot.length + 1);
    final normalized = p.posix.normalize(relativePath);
    if (normalized == '.' ||
        normalized.startsWith('../') ||
        p.posix.isAbsolute(normalized)) {
      throw FullRestoreException('안전하지 않은 zip 경로가 포함되어 있습니다: $entryName');
    }
    return normalized;
  }

  Future<Directory> _createRollback(String stamp) async {
    final appSupportDir = await paths.userSupportDirectory();
    final rollbackDir = Directory(
      p.join(appSupportDir.path, 'full_restore_rollback_$stamp'),
    );
    if (await rollbackDir.exists()) {
      await rollbackDir.delete(recursive: true);
    }
    await rollbackDir.create(recursive: true);

    final currentDb = await paths.stockDatabaseFile();
    if (await currentDb.exists()) {
      final rollbackDb = File(p.join(rollbackDir.path, 'stockapp.db'));
      final escapedPath = rollbackDb.path.replaceAll("'", "''");
      await AppDatabase().customStatement("VACUUM INTO '$escapedPath'");
    }

    final receiptsRoot = await paths.purchaseReceiptsRoot();
    if (await receiptsRoot.exists()) {
      await _copyDirectory(
        receiptsRoot,
        Directory(
          p.join(rollbackDir.path, AppPathService.purchaseReceiptsRelativeRoot),
        ),
      );
    }

    final scheduleAttachmentsRoot = await paths.scheduleAttachmentsRoot();
    if (await scheduleAttachmentsRoot.exists()) {
      await _copyDirectory(
        scheduleAttachmentsRoot,
        Directory(
          p.join(
            rollbackDir.path,
            AppPathService.scheduleAttachmentsRelativeRoot,
          ),
        ),
      );
    }

    final itemImagesRoot = await paths.itemImagesRoot();
    if (await itemImagesRoot.exists()) {
      await _copyDirectory(
        itemImagesRoot,
        Directory(
          p.join(rollbackDir.path, AppPathService.itemImagesRelativeRoot),
        ),
      );
    }

    final productionGuidesRoot = await paths.productionGuidesRoot();
    if (await productionGuidesRoot.exists()) {
      await _copyDirectory(
        productionGuidesRoot,
        Directory(
          p.join(
            rollbackDir.path,
            AppPathService.productionGuidesRelativeRoot,
          ),
        ),
      );
    }

    return rollbackDir;
  }

  Future<void> _applyRestore(_ExtractedFullBackup backup) async {
    await AppDatabase.closeInstance();

    final currentDb = await paths.stockDatabaseFile();
    await _deleteDbFiles(currentDb);
    await backup.databaseFile.copy(currentDb.path);

    final receiptsRoot = await paths.purchaseReceiptsRoot();
    if (await receiptsRoot.exists()) {
      await receiptsRoot.delete(recursive: true);
    }
    await _copyDirectory(backup.purchaseReceiptsDir, receiptsRoot);

    final scheduleAttachmentsRoot = await paths.scheduleAttachmentsRoot();
    if (await scheduleAttachmentsRoot.exists()) {
      await scheduleAttachmentsRoot.delete(recursive: true);
    }
    await _copyDirectory(
      backup.scheduleAttachmentsDir,
      scheduleAttachmentsRoot,
    );

    final itemImagesRoot = await paths.itemImagesRoot();
    if (await itemImagesRoot.exists()) {
      await itemImagesRoot.delete(recursive: true);
    }
    await _copyDirectory(backup.itemImagesDir, itemImagesRoot);

    final productionGuidesRoot = await paths.productionGuidesRoot();
    if (await productionGuidesRoot.exists()) {
      await productionGuidesRoot.delete(recursive: true);
    }
    await _copyDirectory(backup.productionGuidesDir, productionGuidesRoot);
  }

  Future<void> _rollback(Directory rollbackDir) async {
    await AppDatabase.closeInstance();

    final currentDb = await paths.stockDatabaseFile();
    await _deleteDbFiles(currentDb);

    final rollbackDb = File(p.join(rollbackDir.path, 'stockapp.db'));
    if (await rollbackDb.exists()) {
      await rollbackDb.copy(currentDb.path);
    }

    final receiptsRoot = await paths.purchaseReceiptsRoot();
    if (await receiptsRoot.exists()) {
      await receiptsRoot.delete(recursive: true);
    }

    final rollbackReceipts = Directory(
      p.join(rollbackDir.path, AppPathService.purchaseReceiptsRelativeRoot),
    );
    if (await rollbackReceipts.exists()) {
      await _copyDirectory(rollbackReceipts, receiptsRoot);
    }

    final scheduleAttachmentsRoot = await paths.scheduleAttachmentsRoot();
    if (await scheduleAttachmentsRoot.exists()) {
      await scheduleAttachmentsRoot.delete(recursive: true);
    }

    final rollbackScheduleAttachments = Directory(
      p.join(
        rollbackDir.path,
        AppPathService.scheduleAttachmentsRelativeRoot,
      ),
    );
    if (await rollbackScheduleAttachments.exists()) {
      await _copyDirectory(
          rollbackScheduleAttachments, scheduleAttachmentsRoot);
    }

    final itemImagesRoot = await paths.itemImagesRoot();
    if (await itemImagesRoot.exists()) {
      await itemImagesRoot.delete(recursive: true);
    }

    final rollbackItemImages = Directory(
      p.join(rollbackDir.path, AppPathService.itemImagesRelativeRoot),
    );
    if (await rollbackItemImages.exists()) {
      await _copyDirectory(rollbackItemImages, itemImagesRoot);
    }

    final productionGuidesRoot = await paths.productionGuidesRoot();
    if (await productionGuidesRoot.exists()) {
      await productionGuidesRoot.delete(recursive: true);
    }

    final rollbackProductionGuides = Directory(
      p.join(rollbackDir.path, AppPathService.productionGuidesRelativeRoot),
    );
    if (await rollbackProductionGuides.exists()) {
      await _copyDirectory(rollbackProductionGuides, productionGuidesRoot);
    }
  }

  Future<void> _normalizeReceiptPaths() async {
    final db = AppDatabase();
    final tableRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'purchase_receipts'",
        )
        .get();
    if (tableRows.isEmpty) return;

    final rows = await db
        .customSelect(
          'SELECT id, file_path FROM purchase_receipts',
        )
        .get();
    for (final row in rows) {
      final id = row.data['id'] as String;
      final filePath = row.data['file_path'] as String;
      final normalized = await paths.normalizeToRelativePath(filePath);
      if (normalized == filePath) continue;

      await db.customStatement(
        'UPDATE purchase_receipts SET file_path = ? WHERE id = ?',
        [normalized, id],
      );
    }
  }

  Future<void> _normalizeScheduleAttachmentPaths() async {
    final db = AppDatabase();
    final tableRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'schedule_attachments'",
        )
        .get();
    if (tableRows.isEmpty) return;

    final rows = await db
        .customSelect(
          'SELECT id, file_path FROM schedule_attachments',
        )
        .get();
    for (final row in rows) {
      final id = row.data['id'] as String;
      final filePath = row.data['file_path'] as String;
      final normalized = await paths.normalizeToRelativePath(filePath);
      if (normalized == filePath) continue;

      await db.customStatement(
        'UPDATE schedule_attachments SET file_path = ? WHERE id = ?',
        [normalized, id],
      );
    }
  }

  Future<void> _normalizeItemImagePaths() async {
    final db = AppDatabase();
    final tableRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'item_images'",
        )
        .get();
    if (tableRows.isEmpty) return;

    final rows = await db
        .customSelect(
          'SELECT id, file_path FROM item_images',
        )
        .get();
    for (final row in rows) {
      final id = row.data['id'] as String;
      final filePath = row.data['file_path'] as String;
      final normalized = await paths.normalizeToRelativePath(filePath);
      if (normalized == filePath) continue;

      await db.customStatement(
        'UPDATE item_images SET file_path = ? WHERE id = ?',
        [normalized, id],
      );
    }
  }

  Future<List<String>> _findMissingReceiptFiles() async {
    final db = AppDatabase();
    final tableRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'purchase_receipts'",
        )
        .get();
    if (tableRows.isEmpty) return const [];

    final rows = await db
        .customSelect(
          'SELECT purchase_order_id, file_name, file_path FROM purchase_receipts',
        )
        .get();

    final missing = <String>[];
    for (final row in rows) {
      final purchaseOrderId = row.data['purchase_order_id'] as String;
      final fileName = row.data['file_name'] as String;
      final filePath = row.data['file_path'] as String;
      final file = await paths.resolveExistingPurchaseReceiptFile(
        purchaseOrderId: purchaseOrderId,
        storedPath: filePath,
      );
      if (file == null || !await file.exists()) {
        missing.add('$fileName ($filePath)');
      }
    }

    return missing;
  }

  Future<void> _deleteDbFiles(File dbFile) async {
    final files = [
      dbFile,
      File('${dbFile.path}-wal'),
      File('${dbFile.path}-shm'),
    ];
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);

    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      final relativePath = p.relative(entity.path, from: source.path);
      final targetPath = p.join(destination.path, relativePath);
      if (!_isWithin(destination.path, targetPath)) {
        throw FullRestoreException('안전하지 않은 파일 경로입니다: $targetPath');
      }

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        final target = File(targetPath);
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
      }
    }
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;

    var total = 0;
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      total += await entity.length();
    }
    return total;
  }

  bool _isWithin(String parent, String child) {
    return p.equals(parent, child) || p.isWithin(parent, child);
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const FullRestoreException(
      'manifest.json의 schema/version 값이 올바르지 않습니다.',
      code: FullRestoreErrorCode.manifestInvalid,
    );
  }

  String _stringValue(Object? value) => value?.toString() ?? '';
}

class _ExtractedFullBackup {
  final Map<String, Object?> manifest;
  final File databaseFile;
  final Directory purchaseReceiptsDir;
  final Directory scheduleAttachmentsDir;
  final Directory itemImagesDir;
  final Directory productionGuidesDir;

  const _ExtractedFullBackup({
    required this.manifest,
    required this.databaseFile,
    required this.purchaseReceiptsDir,
    required this.scheduleAttachmentsDir,
    required this.itemImagesDir,
    required this.productionGuidesDir,
  });
}
