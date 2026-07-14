import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

enum BusinessDocumentKind { stamp, registration, bankAccount }

extension BusinessDocumentKindX on BusinessDocumentKind {
  String get dbValue => switch (this) {
        BusinessDocumentKind.stamp => 'stamp',
        BusinessDocumentKind.registration => 'registration',
        BusinessDocumentKind.bankAccount => 'bank_account',
      };

  String get label => switch (this) {
        BusinessDocumentKind.stamp => '직인',
        BusinessDocumentKind.registration => '사업자등록증',
        BusinessDocumentKind.bankAccount => '통장사본',
      };
}

class BusinessDocument {
  final int profileId;
  final BusinessDocumentKind kind;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const BusinessDocument({
    required this.profileId,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

class BusinessDocumentService {
  final AppDatabase db;

  const BusinessDocumentService(this.db);

  Future<Map<BusinessDocumentKind, BusinessDocument>> loadForProfile(
      int profileId) async {
    await ensureTable();
    final rows = await db.customSelect(
      'SELECT * FROM business_profile_documents WHERE profile_id = ?',
      variables: [Variable.withInt(profileId)],
    ).get();
    final result = <BusinessDocumentKind, BusinessDocument>{};
    for (final row in rows) {
      final kind = _kindFromDb(row.read<String>('kind'));
      if (kind == null) continue;
      result[kind] = BusinessDocument(
        profileId: profileId,
        kind: kind,
        fileName: row.read<String>('file_name'),
        mimeType: row.read<String>('mime_type'),
        bytes: row.read<Uint8List>('file_bytes'),
      );
    }
    return result;
  }

  Future<void> save(BusinessDocument document) async {
    await ensureTable();
    await db.customStatement('''
      INSERT INTO business_profile_documents (
        profile_id, kind, file_name, mime_type, file_bytes, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(profile_id, kind) DO UPDATE SET
        file_name = excluded.file_name,
        mime_type = excluded.mime_type,
        file_bytes = excluded.file_bytes,
        updated_at = excluded.updated_at
    ''', [
      document.profileId,
      document.kind.dbValue,
      document.fileName,
      document.mimeType,
      document.bytes,
      DateTime.now().toIso8601String(),
    ]);
  }

  Future<void> delete(int profileId, BusinessDocumentKind kind) async {
    await ensureTable();
    await db.customStatement(
      'DELETE FROM business_profile_documents WHERE profile_id = ? AND kind = ?',
      [profileId, kind.dbValue],
    );
  }

  Future<void> ensureTable() => db.customStatement('''
    CREATE TABLE IF NOT EXISTS business_profile_documents (
      profile_id INTEGER NOT NULL,
      kind TEXT NOT NULL,
      file_name TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      file_bytes BLOB NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, kind)
    )
  ''');

  BusinessDocumentKind? _kindFromDb(String value) {
    for (final kind in BusinessDocumentKind.values) {
      if (kind.dbValue == value) return kind;
    }
    return null;
  }
}
