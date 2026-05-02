import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'app_path_service.dart';

class FullBackupResult {
  final File zipFile;
  final Map<String, Object?> manifest;

  const FullBackupResult({
    required this.zipFile,
    required this.manifest,
  });
}

class FullBackupService {
  static const backupFormatVersion = 1;
  static const _uuid = Uuid();
  static const _reportTables = [
    'items',
    'folders',
    'item_paths',
    'txns',
    'bom_rows',
    'orders',
    'order_lines',
    'works',
    'purchase_orders',
    'purchase_lines',
    'suppliers',
    'supplier_contacts',
    'supplier_accounts',
    'lots',
    'memos',
    'quick_action_orders',
    'purchase_receipts',
  ];

  const FullBackupService({
    this.paths = const AppPathService(),
  });

  final AppPathService paths;

  Future<FullBackupResult> createBackup() async {
    final backupId = _uuid.v4();
    final createdAt = DateTime.now().toUtc();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(createdAt.toLocal());
    final appSupportDir = await paths.appSupportDirectory();
    final tempDir = Directory(
      p.join(appSupportDir.path, 'full_backup_tmp', backupId),
    );

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    final dbBackup = File(p.join(tempDir.path, 'stockapp.db'));
    final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
    final reportFile = File(p.join(tempDir.path, 'backup_report.html'));
    final zipFile = File(
      p.join(appSupportDir.path, 'stockapp_full_backup_$stamp.zip'),
    );

    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    try {
      await _writeConsistentDatabaseBackup(dbBackup);

      final includedFolders = <String>[
        AppPathService.purchaseReceiptsRelativeRoot,
      ];
      final receiptFilesSize = await _directorySize(
        await paths.purchaseReceiptsRoot(),
      );
      final receiptFilesCount = await _directoryFileCount(
        await paths.purchaseReceiptsRoot(),
      );
      final dbSize = await dbBackup.length();
      final totalSizeBytes = dbSize + receiptFilesSize;

      final manifest = <String, Object?>{
        'backupId': backupId,
        'backupCreatedAt': createdAt.toIso8601String(),
        'backupFormatVersion': backupFormatVersion,
        'dbSchemaVersion': AppDatabase().schemaVersion,
        'includedFolders': includedFolders,
        'totalSizeBytes': totalSizeBytes,
      };

      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      await _writeHtmlReport(
        reportFile: reportFile,
        manifest: manifest,
        attachmentFileCount: receiptFilesCount,
        attachmentSizeBytes: receiptFilesSize,
      );

      await _writeZip(
        zipFile: zipFile,
        dbBackup: dbBackup,
        manifestFile: manifestFile,
        reportFile: reportFile,
      );

      return FullBackupResult(zipFile: zipFile, manifest: manifest);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> _writeConsistentDatabaseBackup(File dbBackup) async {
    final escapedPath = dbBackup.path.replaceAll("'", "''");
    await AppDatabase().customStatement("VACUUM INTO '$escapedPath'");
  }

  Future<void> _writeZip({
    required File zipFile,
    required File dbBackup,
    required File manifestFile,
    required File reportFile,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path, level: ZipFileEncoder.gzip);

    try {
      await encoder.addFile(dbBackup, 'stockapp.db', ZipFileEncoder.gzip);
      await encoder.addFile(manifestFile, 'manifest.json', ZipFileEncoder.gzip);
      await encoder.addFile(
        reportFile,
        'backup_report.html',
        ZipFileEncoder.gzip,
      );
      encoder.addArchiveFile(
        ArchiveFile.directory(AppPathService.purchaseReceiptsRelativeRoot),
      );

      final receiptsRoot = await paths.purchaseReceiptsRoot();
      if (await receiptsRoot.exists()) {
        await encoder.addDirectory(
          receiptsRoot,
          includeDirName: true,
          level: ZipFileEncoder.gzip,
          followLinks: false,
        );
      }
    } finally {
      await encoder.close();
    }
  }

  Future<void> _writeHtmlReport({
    required File reportFile,
    required Map<String, Object?> manifest,
    required int attachmentFileCount,
    required int attachmentSizeBytes,
  }) async {
    final tables = <_BackupTableReport>[];
    for (final tableName in _reportTables) {
      tables.add(await _loadTableReport(tableName));
    }

    final html = _buildHtmlReport(
      manifest: manifest,
      tables: tables,
      attachmentFileCount: attachmentFileCount,
      attachmentSizeBytes: attachmentSizeBytes,
    );
    await reportFile.writeAsString(html, flush: true);
  }

  Future<_BackupTableReport> _loadTableReport(String tableName) async {
    final exists = await _tableExists(tableName);
    if (!exists) {
      return _BackupTableReport(
        name: tableName,
        exists: false,
        rowCount: 0,
        rows: const [],
      );
    }

    final countRows = await AppDatabase()
        .customSelect(
          'SELECT COUNT(*) AS row_count FROM $tableName',
        )
        .get();
    final rowCount = countRows.first.data['row_count'] as int? ?? 0;
    final rows =
        await AppDatabase().customSelect('SELECT * FROM $tableName').get();

    return _BackupTableReport(
      name: tableName,
      exists: true,
      rowCount: rowCount,
      rows: rows.map((row) => Map<String, Object?>.from(row.data)).toList(),
    );
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await AppDatabase().customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  String _buildHtmlReport({
    required Map<String, Object?> manifest,
    required List<_BackupTableReport> tables,
    required int attachmentFileCount,
    required int attachmentSizeBytes,
  }) {
    final buffer = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="ko">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln('<title>StockApp 전체 백업 검수 리포트</title>')
      ..writeln('<style>')
      ..writeln(_reportCss)
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main>')
      ..writeln('<h1>StockApp 전체 백업 검수 리포트</h1>')
      ..writeln(
          '<p class="notice">이 파일은 검수용입니다. 복원은 반드시 zip 안의 <code>stockapp.db</code> 기준으로만 수행합니다.</p>')
      ..writeln('<section>')
      ..writeln('<h2>백업 정보</h2>')
      ..writeln('<dl class="meta">')
      ..writeln(_metaRow('backupId', manifest['backupId']))
      ..writeln(_metaRow('backupCreatedAt', manifest['backupCreatedAt']))
      ..writeln(
          _metaRow('backupFormatVersion', manifest['backupFormatVersion']))
      ..writeln(_metaRow('dbSchemaVersion', manifest['dbSchemaVersion']))
      ..writeln(_metaRow('includedFolders', manifest['includedFolders']))
      ..writeln(_metaRow('totalSizeBytes', manifest['totalSizeBytes']))
      ..writeln('</dl>')
      ..writeln('</section>')
      ..writeln('<section>')
      ..writeln('<h2>첨부파일 요약</h2>')
      ..writeln('<dl class="meta">')
      ..writeln(_metaRow('첨부파일 총 개수', '$attachmentFileCount개'))
      ..writeln(_metaRow('첨부파일 총 용량', _formatBytes(attachmentSizeBytes)))
      ..writeln('</dl>')
      ..writeln('</section>')
      ..writeln('<section>')
      ..writeln('<h2>DB 테이블 row 수</h2>')
      ..writeln(
          '<table class="counts"><thead><tr><th>테이블</th><th>row 수</th><th>상태</th></tr></thead><tbody>');

    for (final table in tables) {
      buffer.writeln(
        '<tr><td>${_h(table.name)}</td><td>${table.rowCount}</td><td>${table.exists ? 'OK' : '없음'}</td></tr>',
      );
    }

    buffer
      ..writeln('</tbody></table>')
      ..writeln('</section>')
      ..writeln('<section>')
      ..writeln('<h2>DB 테이블 전체 내용</h2>');

    for (final table in tables) {
      buffer.writeln(_tableHtml(table));
    }

    buffer
      ..writeln('</section>')
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');

    return buffer.toString();
  }

  String _tableHtml(_BackupTableReport table) {
    final buffer = StringBuffer()
      ..writeln('<details class="table-block">')
      ..writeln(
        '<summary>${_h(table.name)} <span>${table.rowCount} rows</span></summary>',
      );

    if (!table.exists) {
      buffer
        ..writeln('<p class="empty">테이블이 없습니다.</p>')
        ..writeln('</details>');
      return buffer.toString();
    }

    if (table.rows.isEmpty) {
      buffer
        ..writeln('<p class="empty">row가 없습니다.</p>')
        ..writeln('</details>');
      return buffer.toString();
    }

    final columns = table.rows.first.keys.toList();
    buffer
      ..writeln('<div class="table-scroll">')
      ..writeln('<table>')
      ..writeln('<thead><tr>');
    for (final column in columns) {
      buffer.writeln('<th>${_h(column)}</th>');
    }
    buffer.writeln('</tr></thead><tbody>');

    for (final row in table.rows) {
      buffer.writeln('<tr>');
      for (final column in columns) {
        buffer.writeln('<td>${_h(_stringValue(row[column]))}</td>');
      }
      buffer.writeln('</tr>');
    }

    buffer
      ..writeln('</tbody></table>')
      ..writeln('</div>')
      ..writeln('</details>');
    return buffer.toString();
  }

  Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;

    var size = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      try {
        size += await entity.length();
      } catch (_) {
        // 읽을 수 없는 파일 하나 때문에 전체 백업 생성을 막지 않는다.
      }
    }
    return size;
  }

  Future<int> _directoryFileCount(Directory dir) async {
    if (!await dir.exists()) return 0;

    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) count += 1;
    }
    return count;
  }

  String _metaRow(String label, Object? value) {
    return '<dt>${_h(label)}</dt><dd>${_h(_stringValue(value))}</dd>';
  }

  String _stringValue(Object? value) {
    if (value == null) return '';
    if (value is Iterable) return value.join(', ');
    return value.toString();
  }

  String _h(Object? value) {
    return const HtmlEscape().convert(_stringValue(value));
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 0.1) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _BackupTableReport {
  final String name;
  final bool exists;
  final int rowCount;
  final List<Map<String, Object?>> rows;

  const _BackupTableReport({
    required this.name,
    required this.exists,
    required this.rowCount,
    required this.rows,
  });
}

const _reportCss = '''
:root {
  color-scheme: light;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: #f6f7f9;
  color: #20242a;
}
body {
  margin: 0;
}
main {
  max-width: 1180px;
  margin: 0 auto;
  padding: 28px 18px 56px;
}
h1 {
  margin: 0 0 12px;
  font-size: 28px;
}
h2 {
  margin: 28px 0 12px;
  font-size: 18px;
}
.notice {
  padding: 12px 14px;
  border: 1px solid #d8dee8;
  background: #fff;
  border-radius: 8px;
}
.meta {
  display: grid;
  grid-template-columns: minmax(160px, 240px) 1fr;
  margin: 0;
  border: 1px solid #d8dee8;
  background: #fff;
}
.meta dt,
.meta dd {
  margin: 0;
  padding: 10px 12px;
  border-bottom: 1px solid #edf0f4;
}
.meta dt {
  font-weight: 700;
  background: #f1f4f8;
}
.meta dd {
  overflow-wrap: anywhere;
}
table {
  width: 100%;
  border-collapse: collapse;
  background: #fff;
}
th,
td {
  padding: 8px 10px;
  border: 1px solid #d8dee8;
  text-align: left;
  vertical-align: top;
  font-size: 13px;
  white-space: nowrap;
  overflow-wrap: normal;
  word-break: normal;
}
th {
  position: sticky;
  top: 0;
  background: #eef3f8;
  z-index: 1;
}
td {
  max-width: 420px;
  overflow: hidden;
  text-overflow: ellipsis;
}
.counts td:nth-child(2) {
  text-align: right;
}
.table-block {
  margin: 10px 0;
  border: 1px solid #d8dee8;
  border-radius: 8px;
  background: #fff;
  overflow: hidden;
}
.table-block summary {
  cursor: pointer;
  padding: 12px 14px;
  font-weight: 700;
  background: #f1f4f8;
}
.table-block summary span {
  margin-left: 8px;
  color: #5d6876;
  font-weight: 500;
}
.table-scroll {
  max-height: 560px;
  overflow-x: auto;
  overflow-y: auto;
}
.table-scroll table {
  width: max-content;
  min-width: 100%;
}
.empty {
  margin: 0;
  padding: 14px;
  color: #667085;
}
code {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}
''';
