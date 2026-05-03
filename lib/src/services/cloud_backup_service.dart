import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'full_backup_service.dart';

enum CloudBackupErrorCode {
  notSignedIn,
  firebaseNotInitialized,
  firestoreConnection,
  storageUpload,
  metadataWrite,
  general,
}

class CloudBackupException implements Exception {
  final String message;
  final CloudBackupErrorCode code;
  final Object? cause;

  const CloudBackupException(
    this.message, {
    this.code = CloudBackupErrorCode.general,
    this.cause,
  });

  @override
  String toString() => message;
}

class CloudBackupMetadata {
  final String docId;
  final String uid;
  final String backupId;
  final DateTime createdAt;
  final int backupFormatVersion;
  final int dbSchemaVersion;
  final int totalSizeBytes;
  final String storagePath;
  final String status;
  final DateTime? uploadedAt;
  final DateTime? updatedAt;
  final DateTime? failedAt;

  const CloudBackupMetadata({
    required this.docId,
    required this.uid,
    required this.backupId,
    required this.createdAt,
    required this.backupFormatVersion,
    required this.dbSchemaVersion,
    required this.totalSizeBytes,
    required this.storagePath,
    required this.status,
    this.uploadedAt,
    this.updatedAt,
    this.failedAt,
  });

  factory CloudBackupMetadata.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CloudBackupMetadata(
      docId: doc.id,
      uid: (data['uid'] ?? '').toString(),
      backupId: (data['backupId'] ?? doc.id).toString(),
      createdAt: _dateTimeValue(data['createdAt']) ?? DateTime(1970),
      backupFormatVersion: _intValue(data['backupFormatVersion']),
      dbSchemaVersion: _intValue(data['dbSchemaVersion']),
      totalSizeBytes: _intValue(data['totalSizeBytes']),
      storagePath: (data['storagePath'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      uploadedAt: _dateTimeValue(data['uploadedAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
      failedAt: _dateTimeValue(data['failedAt']),
    );
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class CloudBackupCleanupResult {
  final int deletedCount;
  final int markedFailedCount;
  final int storageObjectNotFoundCount;

  const CloudBackupCleanupResult({
    required this.deletedCount,
    required this.markedFailedCount,
    required this.storageObjectNotFoundCount,
  });
}

class CloudBackupDeleteResult {
  final bool deleted;
  final bool storageObjectNotFound;

  const CloudBackupDeleteResult({
    required this.deleted,
    required this.storageObjectNotFound,
  });
}

class CloudBackupUploadResult {
  final CloudBackupMetadata metadata;
  final File localZipFile;

  const CloudBackupUploadResult({
    required this.metadata,
    required this.localZipFile,
  });
}

class CloudBackupService {
  static const int defaultKeepRecent = 5;
  static const int defaultMaxBackups = 20;
  static const Duration failedRetention = Duration(days: 3);
  static const Duration uploadingStaleAfter = Duration(hours: 1);

  CloudBackupService({
    required this.authService,
    this.fullBackupService = const FullBackupService(),
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _storage = storage;

  final AuthService authService;
  final FullBackupService fullBackupService;
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  Future<CloudBackupUploadResult> uploadFullBackup({
    int keepRecent = defaultKeepRecent,
  }) async {
    final uid = authService.uid;
    if (uid == null) {
      throw const CloudBackupException(
        '로그인 후 클라우드 백업을 사용할 수 있습니다.',
        code: CloudBackupErrorCode.notSignedIn,
      );
    }

    _assertFirebaseInitialized();
    await _verifyFirestoreConnection(uid);

    final backup = await fullBackupService.createBackup();
    final manifest = backup.manifest;
    final backupId = _requiredString(manifest, 'backupId');
    final createdAt =
        DateTime.parse(_requiredString(manifest, 'backupCreatedAt'));
    final storagePath = 'users/$uid/backups/$backupId/stockapp_full_backup.zip';
    final docRef = _backupDoc(uid, backupId);
    final metadata = _metadataFromManifest(
      uid: uid,
      manifest: manifest,
      status: 'uploading',
      storagePath: storagePath,
    );

    try {
      debugPrint('☁️ CloudBackup: writing uploading metadata $backupId');
      await docRef.set(metadata);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        '☁️ CloudBackup metadata write failed: '
        'code=${e.code}, message=${e.message}, plugin=${e.plugin}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw CloudBackupException(
        'Firestore metadata 저장에 실패했습니다.',
        code: CloudBackupErrorCode.metadataWrite,
        cause: e,
      );
    }

    try {
      debugPrint('☁️ CloudBackup: uploading zip to $storagePath');
      await storage.ref(storagePath).putFile(
            backup.zipFile,
            SettableMetadata(
              contentType: 'application/zip',
              customMetadata: {
                'backupId': backupId,
                'createdAt': createdAt.toUtc().toIso8601String(),
              },
            ),
          );

      debugPrint('☁️ CloudBackup: marking backup ready $backupId');
      await docRef.set({
        ...metadata,
        'status': 'ready',
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await cleanupBackups(uid: uid, keepReady: keepRecent);

      final readyDoc = await docRef.get();
      return CloudBackupUploadResult(
        metadata: CloudBackupMetadata.fromDoc(readyDoc),
        localZipFile: backup.zipFile,
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        '☁️ CloudBackup upload/ready failed: '
        'code=${e.code}, message=${e.message}, plugin=${e.plugin}',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _markBackupFailed(docRef, metadata, e);
      throw CloudBackupException(
        e.plugin == 'firebase_storage'
            ? 'Firebase Storage 업로드에 실패했습니다.'
            : 'Firestore metadata 저장에 실패했습니다.',
        code: e.plugin == 'firebase_storage'
            ? CloudBackupErrorCode.storageUpload
            : CloudBackupErrorCode.metadataWrite,
        cause: e,
      );
    } catch (e, stackTrace) {
      debugPrint('☁️ CloudBackup upload failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      await _markBackupFailed(docRef, metadata, e);
      rethrow;
    }
  }

  void _assertFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw const CloudBackupException(
        'Firebase 초기화가 완료되지 않았습니다.',
        code: CloudBackupErrorCode.firebaseNotInitialized,
      );
    }

    final app = Firebase.app();
    debugPrint(
      '☁️ CloudBackup Firebase app ready: '
      'name=${app.name}, projectId=${app.options.projectId}, '
      'storageBucket=${app.options.storageBucket}',
    );
  }

  Future<void> _verifyFirestoreConnection(String uid) async {
    final testDoc = _backupsCollection(uid).doc('_connection_test');
    try {
      debugPrint('☁️ CloudBackup: Firestore connection test write start');
      await testDoc.set({
        'status': 'diagnostic',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('☁️ CloudBackup: Firestore connection test write ok');
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        '☁️ CloudBackup Firestore connection test failed: '
        'code=${e.code}, message=${e.message}, plugin=${e.plugin}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw CloudBackupException(
        'Firestore 연결에 실패했습니다. Firebase 설정 또는 네트워크를 확인해주세요.',
        code: CloudBackupErrorCode.firestoreConnection,
        cause: e,
      );
    } catch (e, stackTrace) {
      debugPrint('☁️ CloudBackup Firestore connection test failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw CloudBackupException(
        'Firestore 연결에 실패했습니다. Firebase 설정 또는 네트워크를 확인해주세요.',
        code: CloudBackupErrorCode.firestoreConnection,
        cause: e,
      );
    }
  }

  Future<void> _markBackupFailed(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, Object?> metadata,
    Object error,
  ) async {
    try {
      await docRef.set({
        ...metadata,
        'status': 'failed',
        'failedAt': FieldValue.serverTimestamp(),
        'errorMessage': error.toString(),
      });
    } catch (e) {
      debugPrint('☁️ CloudBackup failed metadata write also failed: $e');
    }
  }

  Future<CloudBackupMetadata?> latestReadyBackup() async {
    final uid = authService.uid;
    if (uid == null) return null;

    final query = await _backupsCollection(uid)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    for (final doc in query.docs) {
      final backup = CloudBackupMetadata.fromDoc(doc);
      if (backup.status == 'ready') return backup;
    }
    return null;
  }

  Future<List<CloudBackupMetadata>> listBackups({
    String? uid,
    int limit = 50,
  }) async {
    final resolvedUid = uid ?? authService.uid;
    if (resolvedUid == null) {
      throw const CloudBackupException(
        '로그인 후 클라우드 백업을 사용할 수 있습니다.',
        code: CloudBackupErrorCode.notSignedIn,
      );
    }

    try {
      final query = await _backupsCollection(resolvedUid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return query.docs
          .map(CloudBackupMetadata.fromDoc)
          .where((backup) => !_isDiagnosticBackup(backup))
          .toList();
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        '☁️ CloudBackup list failed: '
        'code=${e.code}, message=${e.message}, plugin=${e.plugin}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw CloudBackupException(
        '클라우드 백업 목록을 불러오지 못했습니다. Firebase 설정 또는 네트워크를 확인해주세요.',
        code: CloudBackupErrorCode.firestoreConnection,
        cause: e,
      );
    }
  }

  Future<CloudBackupCleanupResult> cleanupBackups({
    String? uid,
    int keepRecent = defaultKeepRecent,
    int keepReady = defaultKeepRecent,
    int maxBackups = defaultMaxBackups,
  }) async {
    final resolvedUid = uid ?? authService.uid;
    if (resolvedUid == null) {
      throw const CloudBackupException(
        '로그인 후 클라우드 백업을 사용할 수 있습니다.',
        code: CloudBackupErrorCode.notSignedIn,
      );
    }

    final now = DateTime.now();
    var deletedCount = 0;
    var markedFailedCount = 0;
    var storageObjectNotFoundCount = 0;

    final query = await _backupsCollection(resolvedUid)
        .orderBy('createdAt', descending: true)
        .get();

    var backups = query.docs.map(CloudBackupMetadata.fromDoc).toList();

    for (final backup in backups.where(_isDiagnosticBackup).toList()) {
      final result = await deleteBackup(backup, uid: resolvedUid);
      deletedCount += result.deleted ? 1 : 0;
      storageObjectNotFoundCount += result.storageObjectNotFound ? 1 : 0;
    }

    backups = backups.where((backup) => !_isDiagnosticBackup(backup)).toList();

    for (final backup in backups.where((backup) {
      if (backup.status != 'uploading') return false;
      final referenceTime = backup.updatedAt ?? backup.createdAt;
      return now.difference(referenceTime) > uploadingStaleAfter;
    }).toList()) {
      await _backupDoc(resolvedUid, backup.docId).set({
        'status': 'failed',
        'failedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'errorMessage': '업로드가 1시간 이상 완료되지 않아 실패로 표시했습니다.',
      }, SetOptions(merge: true));
      markedFailedCount += 1;
    }

    final refreshedQuery = await _backupsCollection(resolvedUid)
        .orderBy('createdAt', descending: true)
        .get();
    backups = refreshedQuery.docs
        .map(CloudBackupMetadata.fromDoc)
        .where((backup) => !_isDiagnosticBackup(backup))
        .toList();

    final protectedReadyDocIds = backups
        .where((backup) => backup.status == 'ready')
        .take(keepReady)
        .map((backup) => backup.docId)
        .toSet();

    final readyToDelete =
        backups.where((backup) => backup.status == 'ready').skip(keepReady);
    for (final backup in readyToDelete.toList()) {
      final result = await deleteBackup(backup, uid: resolvedUid);
      deletedCount += result.deleted ? 1 : 0;
      storageObjectNotFoundCount += result.storageObjectNotFound ? 1 : 0;
    }

    final failedToDelete = backups.where((backup) {
      if (backup.status != 'failed') return false;
      final referenceTime = backup.failedAt ?? backup.createdAt;
      return now.difference(referenceTime) > failedRetention;
    });
    for (final backup in failedToDelete.toList()) {
      final result = await deleteBackup(backup, uid: resolvedUid);
      deletedCount += result.deleted ? 1 : 0;
      storageObjectNotFoundCount += result.storageObjectNotFound ? 1 : 0;
    }

    final afterPolicyQuery = await _backupsCollection(resolvedUid)
        .orderBy('createdAt', descending: true)
        .get();
    backups = afterPolicyQuery.docs
        .map(CloudBackupMetadata.fromDoc)
        .where((backup) => !_isDiagnosticBackup(backup))
        .toList();

    var overflow = backups.length - maxBackups;
    if (overflow > 0) {
      final overflowCandidates = backups.reversed
          .where((backup) => !protectedReadyDocIds.contains(backup.docId))
          .toList();
      overflowCandidates.sort((a, b) {
        final priorityCompare =
            _deletePriority(a.status).compareTo(_deletePriority(b.status));
        if (priorityCompare != 0) return priorityCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

      for (final backup in overflowCandidates) {
        if (overflow <= 0) break;
        final result = await deleteBackup(backup, uid: resolvedUid);
        deletedCount += result.deleted ? 1 : 0;
        storageObjectNotFoundCount += result.storageObjectNotFound ? 1 : 0;
        if (result.deleted) overflow -= 1;
      }
    }

    return CloudBackupCleanupResult(
      deletedCount: deletedCount,
      markedFailedCount: markedFailedCount,
      storageObjectNotFoundCount: storageObjectNotFoundCount,
    );
  }

  Future<void> cleanupOldReadyBackups({
    required String uid,
    int keepRecent = defaultKeepRecent,
  }) async {
    await cleanupBackups(uid: uid, keepReady: keepRecent);
  }

  Future<CloudBackupDeleteResult> deleteBackup(
    CloudBackupMetadata backup, {
    String? uid,
  }) async {
    final resolvedUid =
        uid ?? (backup.uid.isNotEmpty ? backup.uid : authService.uid);
    if (resolvedUid == null) {
      throw const CloudBackupException(
        '로그인 후 클라우드 백업을 사용할 수 있습니다.',
        code: CloudBackupErrorCode.notSignedIn,
      );
    }

    var storageObjectNotFound = false;
    if (backup.storagePath.isNotEmpty) {
      try {
        await storage.ref(backup.storagePath).delete();
      } on FirebaseException catch (e) {
        if (e.plugin == 'firebase_storage' && e.code == 'object-not-found') {
          storageObjectNotFound = true;
        } else {
          debugPrint(
            '☁️ CloudBackup storage delete failed: '
            'path=${backup.storagePath}, code=${e.code}, '
            'message=${e.message}, plugin=${e.plugin}',
          );
          rethrow;
        }
      }
    }

    await _backupDoc(resolvedUid, backup.docId).delete();
    return CloudBackupDeleteResult(
      deleted: true,
      storageObjectNotFound: storageObjectNotFound,
    );
  }

  CollectionReference<Map<String, dynamic>> _backupsCollection(String uid) {
    return firestore.collection('users').doc(uid).collection('backups');
  }

  DocumentReference<Map<String, dynamic>> _backupDoc(
    String uid,
    String backupId,
  ) {
    return _backupsCollection(uid).doc(backupId);
  }

  bool _isDiagnosticBackup(CloudBackupMetadata backup) {
    return backup.status == 'diagnostic' ||
        backup.docId == '_connection_test' ||
        backup.backupId == '_connection_test';
  }

  int _deletePriority(String status) {
    switch (status) {
      case 'diagnostic':
        return 0;
      case 'failed':
        return 1;
      case 'uploading':
        return 2;
      case 'ready':
        return 3;
      default:
        return 1;
    }
  }

  Map<String, Object?> _metadataFromManifest({
    required String uid,
    required Map<String, Object?> manifest,
    required String status,
    required String storagePath,
  }) {
    final receiptFiles = manifest['purchaseReceiptFiles'];
    final receiptList = receiptFiles is List ? receiptFiles : const [];
    final receiptTotalSizeBytes = receiptList.fold<int>(
      0,
      (total, item) {
        if (item is! Map) return total;
        final value = item['sizeBytes'];
        if (value is num) return total + value.toInt();
        if (value is String) return total + (int.tryParse(value) ?? 0);
        return total;
      },
    );
    final stockappDb = manifest['stockappDb'];
    final stockappDbMap = stockappDb is Map ? stockappDb : const {};

    return {
      'uid': uid,
      'backupId': _requiredString(manifest, 'backupId'),
      'createdAt': Timestamp.fromDate(
        DateTime.parse(_requiredString(manifest, 'backupCreatedAt')),
      ),
      'backupFormatVersion': _requiredInt(manifest, 'backupFormatVersion'),
      'dbSchemaVersion': _requiredInt(manifest, 'dbSchemaVersion'),
      'totalSizeBytes': _requiredInt(manifest, 'totalSizeBytes'),
      'storagePath': storagePath,
      'status': status,
      'stockappDbSha256': stockappDbMap['sha256']?.toString() ?? '',
      'stockappDbSizeBytes': _intValue(stockappDbMap['sizeBytes']),
      'receiptFileCount': receiptList.length,
      'receiptTotalSizeBytes': receiptTotalSizeBytes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String _requiredString(Map<String, Object?> manifest, String key) {
    final value = manifest[key]?.toString() ?? '';
    if (value.isEmpty) {
      throw CloudBackupException('백업 manifest에 $key 값이 없습니다.');
    }
    return value;
  }

  int _requiredInt(Map<String, Object?> manifest, String key) {
    final value = _intValue(manifest[key]);
    if (value == null) {
      throw CloudBackupException('백업 manifest의 $key 값이 올바르지 않습니다.');
    }
    return value;
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
