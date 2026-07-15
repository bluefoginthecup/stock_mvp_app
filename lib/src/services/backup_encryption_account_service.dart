import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'backup_encryption_key_store.dart';

class AccountBackupEncryptionSettings {
  final bool configured;
  final DateTime? configuredAt;
  final String? encryptionSecret;
  final String? passwordSecret;
  final String? passwordCheckHash;
  final String? recoverySecret;
  final String? recoveryKeyHash;
  final DateTime? updatedAt;

  const AccountBackupEncryptionSettings({
    required this.configured,
    this.configuredAt,
    this.encryptionSecret,
    this.passwordSecret,
    this.passwordCheckHash,
    this.recoverySecret,
    this.recoveryKeyHash,
    this.updatedAt,
  });

  String? get effectiveEncryptionSecret {
    final stableSecret = encryptionSecret;
    if (stableSecret?.isNotEmpty == true) return stableSecret;
    final legacySecret = passwordSecret;
    if (legacySecret?.isNotEmpty == true) return legacySecret;
    return null;
  }

  bool get hasSecrets =>
      configured && effectiveEncryptionSecret?.isNotEmpty == true;

  BackupEncryptionStoredSecret? toStoredSecret() {
    final secret = effectiveEncryptionSecret;
    if (!hasSecrets || secret == null) return null;
    return BackupEncryptionStoredSecret(
      passwordSecret: secret,
      recoverySecret: secret,
    );
  }

  bool passwordMatches(String password) {
    final expected = passwordCheckHash;
    if (expected == null || expected.isEmpty) return false;
    return expected == BackupEncryptionAccountService.hashPassword(password);
  }

  bool recoveryKeyMatches(String recoveryKey) {
    final expected = recoveryKeyHash;
    if (expected == null || expected.isEmpty) return false;
    return expected ==
        BackupEncryptionAccountService.hashRecoveryKey(recoveryKey);
  }
}

class BackupEncryptionAccountService {
  const BackupEncryptionAccountService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<AccountBackupEncryptionSettings?> load(String uid) async {
    final snapshot = await _settingsDoc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return AccountBackupEncryptionSettings(
      configured: data['configured'] == true,
      configuredAt: _dateTimeFrom(data['configuredAt']),
      encryptionSecret: data['encryptionSecret'] as String?,
      passwordSecret: data['passwordSecret'] as String?,
      passwordCheckHash: data['passwordCheckHash'] as String?,
      recoverySecret: data['recoverySecret'] as String?,
      recoveryKeyHash: data['recoveryKeyHash'] as String?,
      updatedAt: _dateTimeFrom(data['updatedAt']),
    );
  }

  Future<void> save({
    required String uid,
    required BackupEncryptionStoredSecret secret,
    required String recoveryKeyHash,
    String? passwordCheckHash,
    DateTime? configuredAt,
  }) async {
    final now = DateTime.now().toUtc();
    await _settingsDoc(uid).set(
      {
        'configured': true,
        'configuredAt': Timestamp.fromDate(configuredAt?.toUtc() ?? now),
        'encryptionSecret': secret.passwordSecret,
        'passwordSecret': secret.passwordSecret,
        if (passwordCheckHash != null) 'passwordCheckHash': passwordCheckHash,
        'recoverySecret': secret.recoverySecret,
        'recoveryKeyHash': recoveryKeyHash,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 1,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> clear(String uid) async {
    await _settingsDoc(uid).set(
      {
        'configured': false,
        'encryptionSecret': FieldValue.delete(),
        'passwordSecret': FieldValue.delete(),
        'passwordCheckHash': FieldValue.delete(),
        'recoverySecret': FieldValue.delete(),
        'recoveryKeyHash': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('backupEncryption');
  }

  static String hashPassword(String password) {
    return sha256
        .convert(utf8.encode('stockapp:backup-password-check:v1:$password'))
        .toString();
  }

  static String hashRecoveryKey(String recoveryKey) {
    final normalized = recoveryKey.trim().toUpperCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static BackupEncryptionStoredSecret generateStoredSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final secret = base64UrlEncode(bytes);
    return BackupEncryptionStoredSecret(
      passwordSecret: secret,
      recoverySecret: secret,
    );
  }

  DateTime? _dateTimeFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
