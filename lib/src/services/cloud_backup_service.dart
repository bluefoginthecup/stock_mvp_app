import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import 'auth_service.dart';
import 'backup_encryption_service.dart';
import 'full_backup_service.dart';

enum CloudBackupErrorCode {
  notSignedIn,
  firebaseNotInitialized,
  firestoreConnection,
  storageUpload,
  storageDelete,
  metadataWrite,
  metadataDelete,
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
  final String contentHash;
  final int totalSizeBytes;
  final String storagePath;
  final String status;
  final bool encrypted;
  final int? encryptionVersion;
  final String? encryptionAlgorithm;
  final DateTime? uploadedAt;
  final DateTime? updatedAt;
  final DateTime? failedAt;
  final int? stockappDbSizeBytes;
  final int? receiptFileCount;
  final int? receiptTotalSizeBytes;
  final int? summaryItemCount;
  final int? summaryTotalStockQty;
  final int? summarySupplierCount;
  final DateTime? summaryLatestTxnAt;
  final DateTime? summaryLatestPurchaseOrderAt;
  final String? summaryLatestPurchaseSupplierName;
  final String? deviceName;
  final String? devicePlatform;
  final String? deviceOsVersion;

  const CloudBackupMetadata({
    required this.docId,
    required this.uid,
    required this.backupId,
    required this.createdAt,
    required this.backupFormatVersion,
    required this.dbSchemaVersion,
    required this.contentHash,
    required this.totalSizeBytes,
    required this.storagePath,
    required this.status,
    required this.encrypted,
    this.encryptionVersion,
    this.encryptionAlgorithm,
    this.uploadedAt,
    this.updatedAt,
    this.failedAt,
    this.stockappDbSizeBytes,
    this.receiptFileCount,
    this.receiptTotalSizeBytes,
    this.summaryItemCount,
    this.summaryTotalStockQty,
    this.summarySupplierCount,
    this.summaryLatestTxnAt,
    this.summaryLatestPurchaseOrderAt,
    this.summaryLatestPurchaseSupplierName,
    this.deviceName,
    this.devicePlatform,
    this.deviceOsVersion,
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
      contentHash: (data['contentHash'] ?? '').toString(),
      totalSizeBytes: _intValue(data['totalSizeBytes']),
      storagePath: (data['storagePath'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      encrypted: data['encrypted'] == true,
      encryptionVersion: _nullableIntValue(data['encryptionVersion']),
      encryptionAlgorithm: data['encryptionAlgorithm']?.toString(),
      uploadedAt: _dateTimeValue(data['uploadedAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
      failedAt: _dateTimeValue(data['failedAt']),
      stockappDbSizeBytes: _nullableIntValue(data['stockappDbSizeBytes']),
      receiptFileCount: _nullableIntValue(data['receiptFileCount']),
      receiptTotalSizeBytes: _nullableIntValue(data['receiptTotalSizeBytes']),
      summaryItemCount: _nullableIntValue(data['summaryItemCount']),
      summaryTotalStockQty: _nullableIntValue(data['summaryTotalStockQty']),
      summarySupplierCount: _nullableIntValue(data['summarySupplierCount']),
      summaryLatestTxnAt: _dateTimeValue(data['summaryLatestTxnAt']),
      summaryLatestPurchaseOrderAt:
          _dateTimeValue(data['summaryLatestPurchaseOrderAt']),
      summaryLatestPurchaseSupplierName:
          data['summaryLatestPurchaseSupplierName']?.toString(),
      deviceName: data['deviceName']?.toString(),
      devicePlatform: data['devicePlatform']?.toString(),
      deviceOsVersion: data['deviceOsVersion']?.toString(),
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

  static int? _nullableIntValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
  final bool uploaded;
  final bool skippedDuplicate;

  const CloudBackupUploadResult({
    required this.metadata,
    required this.localZipFile,
    this.uploaded = true,
    this.skippedDuplicate = false,
  });
}

class CloudBackupEncryptionRequest {
  final String password;
  final String recoveryKey;

  const CloudBackupEncryptionRequest({
    required this.password,
    required this.recoveryKey,
  });
}

class CloudBackupDownloadResult {
  final CloudBackupMetadata metadata;
  final File zipFile;

  const CloudBackupDownloadResult({
    required this.metadata,
    required this.zipFile,
  });
}

class CloudBackupService {
  static const int defaultKeepRecent = 10;
  static const int defaultMaxBackups = 20;
  static const Duration failedRetention = Duration(days: 3);
  static const Duration uploadingStaleAfter = Duration(hours: 1);

  CloudBackupService({
    required this.authService,
    this.fullBackupService = const FullBackupService(),
    this.encryptionService = const BackupEncryptionService(),
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _storage = storage;

  final AuthService authService;
  final FullBackupService fullBackupService;
  final BackupEncryptionService encryptionService;
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  Future<CloudBackupUploadResult> uploadFullBackup({
    int keepRecent = defaultKeepRecent,
    bool skipIfContentUnchanged = false,
    CloudBackupEncryptionRequest? encryption,
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
    final encrypted = encryption != null;
    final storageFileName = encrypted
        ? 'stockapp_full_backup${BackupEncryptionService.encryptedExtension}'
        : 'stockapp_full_backup.zip';
    final storagePath = 'users/$uid/backups/$backupId/$storageFileName';
    final docRef = _backupDoc(uid, backupId);
    final metadata = await _metadataFromManifest(
      uid: uid,
      manifest: manifest,
      status: 'uploading',
      storagePath: storagePath,
      encrypted: encrypted,
    );
    if (skipIfContentUnchanged) {
      final latestReady = await latestReadyBackup();
      final contentHash = metadata['contentHash']?.toString() ?? '';
      if (latestReady != null &&
          contentHash.isNotEmpty &&
          latestReady.contentHash == contentHash) {
        debugPrint(
          '☁️ CloudBackup: content unchanged, skipping upload $backupId',
        );
        return CloudBackupUploadResult(
          metadata: latestReady,
          localZipFile: backup.zipFile,
          uploaded: false,
          skippedDuplicate: true,
        );
      }
    }

    try {
      final uploadFile = encrypted
          ? (await encryptionService.encryptZip(
              zipFile: backup.zipFile,
              password: encryption.password,
              recoveryKey: encryption.recoveryKey,
            ))
              .file
          : backup.zipFile;

      debugPrint('☁️ CloudBackup: writing uploading metadata $backupId');
      await docRef.set(metadata);
      debugPrint('☁️ CloudBackup: uploading backup file to $storagePath');
      await storage.ref(storagePath).putFile(
            uploadFile,
            SettableMetadata(
              contentType:
                  encrypted ? 'application/octet-stream' : 'application/zip',
              customMetadata: {
                'backupId': backupId,
                'createdAt': createdAt.toUtc().toIso8601String(),
                'encrypted': encrypted.toString(),
                if (encrypted)
                  'encryptionVersion':
                      BackupEncryptionService.encryptionVersion.toString(),
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
    } on BackupEncryptionException catch (e, stackTrace) {
      debugPrint('☁️ CloudBackup encryption failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw CloudBackupException(
        '백업 zip 암호화에 실패했습니다.',
        code: CloudBackupErrorCode.general,
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
          throw CloudBackupException(
            'Firebase Storage의 백업 zip 삭제에 실패했습니다. '
            '네트워크 또는 Storage 권한을 확인해주세요.',
            code: CloudBackupErrorCode.storageDelete,
            cause: e,
          );
        }
      }
    }

    try {
      await _backupDoc(resolvedUid, backup.docId).delete();
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        '☁️ CloudBackup metadata delete failed: '
        'docId=${backup.docId}, code=${e.code}, '
        'message=${e.message}, plugin=${e.plugin}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw CloudBackupException(
        'Firestore의 백업 metadata 삭제에 실패했습니다. '
        '네트워크 또는 Firestore 권한을 확인해주세요.',
        code: CloudBackupErrorCode.metadataDelete,
        cause: e,
      );
    }
    return CloudBackupDeleteResult(
      deleted: true,
      storageObjectNotFound: storageObjectNotFound,
    );
  }

  Future<CloudBackupDownloadResult> downloadBackupZip(
    CloudBackupMetadata backup,
  ) async {
    if (backup.status != 'ready') {
      throw const CloudBackupException('ready 상태의 백업만 복원할 수 있습니다.');
    }
    if (backup.storagePath.isEmpty) {
      throw const CloudBackupException('백업 Storage 경로가 비어 있습니다.');
    }

    final tempRoot = await getTemporaryDirectory();
    final backupDir = Directory(
      p.join(tempRoot.path, 'stockapp_cloud_restore', backup.docId),
    );
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
    await backupDir.create(recursive: true);

    final zipFile = File(p.join(backupDir.path, 'stockapp_full_backup.zip'));
    try {
      await storage.ref(backup.storagePath).writeToFile(zipFile);
      return CloudBackupDownloadResult(
        metadata: backup,
        zipFile: zipFile,
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        '☁️ CloudBackup download failed: '
        'path=${backup.storagePath}, code=${e.code}, '
        'message=${e.message}, plugin=${e.plugin}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw CloudBackupException(
        '클라우드 백업 zip 다운로드에 실패했습니다. Firebase Storage 설정 또는 네트워크를 확인해주세요.',
        code: CloudBackupErrorCode.storageUpload,
        cause: e,
      );
    }
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

  Future<Map<String, Object?>> _metadataFromManifest({
    required String uid,
    required Map<String, Object?> manifest,
    required String status,
    required String storagePath,
    required bool encrypted,
  }) async {
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
    final contentSummary = await _buildContentSummaryMetadata();

    return {
      'uid': uid,
      'backupId': _requiredString(manifest, 'backupId'),
      'createdAt': Timestamp.fromDate(
        DateTime.parse(_requiredString(manifest, 'backupCreatedAt')),
      ),
      'backupFormatVersion': _requiredInt(manifest, 'backupFormatVersion'),
      'dbSchemaVersion': _requiredInt(manifest, 'dbSchemaVersion'),
      'contentHash': _requiredString(manifest, 'contentHash'),
      'totalSizeBytes': _requiredInt(manifest, 'totalSizeBytes'),
      'storagePath': storagePath,
      'status': status,
      'encrypted': encrypted,
      'encryptionVersion':
          encrypted ? BackupEncryptionService.encryptionVersion : null,
      'encryptionAlgorithm': encrypted ? 'AES-256-GCM' : null,
      'stockappDbSha256': stockappDbMap['sha256']?.toString() ?? '',
      'stockappDbSizeBytes': _intValue(stockappDbMap['sizeBytes']),
      'receiptFileCount': receiptList.length,
      'receiptTotalSizeBytes': receiptTotalSizeBytes,
      ..._buildDeviceMetadata(),
      ...contentSummary,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, Object?> _buildDeviceMetadata() {
    String? hostname;
    try {
      hostname = Platform.localHostname;
    } catch (_) {
      hostname = null;
    }

    return {
      'deviceName': _emptyToNull(hostname),
      'devicePlatform': Platform.operatingSystem,
      'deviceOsVersion': Platform.operatingSystemVersion,
    };
  }

  Future<Map<String, Object?>> _buildContentSummaryMetadata() async {
    try {
      final db = AppDatabase();

      final itemCount = await _singleInt(
        db,
        'SELECT COUNT(*) AS value FROM items '
        'WHERE COALESCE(is_deleted, 0) = 0',
      );
      final totalStockQty = await _singleInt(
        db,
        'SELECT COALESCE(SUM(qty), 0) AS value FROM items '
        'WHERE COALESCE(is_deleted, 0) = 0',
      );
      final supplierCount = await _singleInt(
        db,
        'SELECT COUNT(*) AS value FROM suppliers '
        'WHERE COALESCE(is_active, 1) = 1',
      );
      final latestTxnAt = await _singleString(
        db,
        'SELECT ts AS value FROM txns '
        'WHERE COALESCE(is_deleted, 0) = 0 '
        'ORDER BY ts DESC LIMIT 1',
      );
      final latestPurchase = await db
          .customSelect(
            'SELECT created_at, supplier_name FROM purchase_orders '
            'WHERE COALESCE(is_deleted, 0) = 0 '
            'ORDER BY created_at DESC LIMIT 1',
          )
          .getSingleOrNull();
      final latestPurchaseAt = latestPurchase?.data['created_at']?.toString();
      final latestPurchaseSupplierName =
          latestPurchase?.data['supplier_name']?.toString();

      return {
        'summaryItemCount': itemCount,
        'summaryTotalStockQty': totalStockQty,
        'summarySupplierCount': supplierCount,
        'summaryLatestTxnAt': _timestampFromIso(latestTxnAt),
        'summaryLatestPurchaseOrderAt': _timestampFromIso(latestPurchaseAt),
        'summaryLatestPurchaseSupplierName': latestPurchaseSupplierName,
      };
    } catch (e, stackTrace) {
      debugPrint('☁️ CloudBackup summary metadata failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return const <String, Object?>{};
    }
  }

  Future<int> _singleInt(AppDatabase db, String sql) async {
    final row = await db.customSelect(sql).getSingle();
    final value = row.data['value'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<String?> _singleString(AppDatabase db, String sql) async {
    final row = await db.customSelect(sql).getSingleOrNull();
    return row?.data['value']?.toString();
  }

  Timestamp? _timestampFromIso(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return Timestamp.fromDate(parsed);
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
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
