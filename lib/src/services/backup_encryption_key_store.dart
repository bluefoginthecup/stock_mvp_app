import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupEncryptionKeyStoreException implements Exception {
  final String message;
  final Object? cause;

  const BackupEncryptionKeyStoreException(this.message, {this.cause});

  @override
  String toString() => message;
}

class BackupEncryptionStoredSecret {
  final String passwordSecret;
  final String recoverySecret;

  const BackupEncryptionStoredSecret({
    required this.passwordSecret,
    required this.recoverySecret,
  });
}

class BackupEncryptionKeyStore {
  static const String _passwordSecretKey =
      'stockapp_backup_encryption_password_secret_v1';
  static const String _recoverySecretKey =
      'stockapp_backup_encryption_recovery_secret_v1';

  const BackupEncryptionKeyStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  Future<void> saveSecret({
    required String password,
    required String recoveryKey,
  }) async {
    try {
      await _storage.write(
        key: _passwordSecretKey,
        value: _derivePasswordSecret(password),
      );
      await _storage.write(
        key: _recoverySecretKey,
        value: deriveRecoverySecret(recoveryKey),
      );
    } on MissingPluginException catch (e) {
      throw BackupEncryptionKeyStoreException(
        '기기 보안 저장소 플러그인이 아직 등록되지 않았습니다. 앱을 완전히 종료한 뒤 다시 빌드/실행해주세요.',
        cause: e,
      );
    }
  }

  Future<BackupEncryptionStoredSecret?> readSecret() async {
    late final String? passwordSecret;
    late final String? recoverySecret;
    try {
      passwordSecret = await _storage.read(key: _passwordSecretKey);
      recoverySecret = await _storage.read(key: _recoverySecretKey);
    } on MissingPluginException catch (e) {
      throw BackupEncryptionKeyStoreException(
        '기기 보안 저장소 플러그인이 아직 등록되지 않았습니다. 앱을 완전히 종료한 뒤 다시 빌드/실행해주세요.',
        cause: e,
      );
    }
    if (passwordSecret == null ||
        passwordSecret.isEmpty ||
        recoverySecret == null ||
        recoverySecret.isEmpty) {
      return null;
    }
    return BackupEncryptionStoredSecret(
      passwordSecret: passwordSecret,
      recoverySecret: recoverySecret,
    );
  }

  Future<void> deleteSecret() async {
    try {
      await _storage.delete(key: _passwordSecretKey);
      await _storage.delete(key: _recoverySecretKey);
    } on MissingPluginException catch (e) {
      throw BackupEncryptionKeyStoreException(
        '기기 보안 저장소 플러그인이 아직 등록되지 않았습니다. 앱을 완전히 종료한 뒤 다시 빌드/실행해주세요.',
        cause: e,
      );
    }
  }

  Future<bool> hasSecret() async {
    return await readSecret() != null;
  }

  static String deriveRecoverySecret(String recoveryKey) {
    final normalized = recoveryKey.trim().toUpperCase();
    return sha256
        .convert(utf8.encode('stockapp:recovery-wrap:v1:$normalized'))
        .toString();
  }

  String _derivePasswordSecret(String password) {
    return sha256
        .convert(utf8.encode('stockapp:password-wrap:v1:$password'))
        .toString();
  }
}
