import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupEncryptionSettings {
  final bool configured;
  final DateTime? configuredAt;
  final String? recoveryKeyHash;

  const BackupEncryptionSettings({
    required this.configured,
    this.configuredAt,
    this.recoveryKeyHash,
  });
}

class BackupEncryptionSetupDraft {
  final String recoveryKey;
  final String recoveryKeyHash;

  const BackupEncryptionSetupDraft({
    required this.recoveryKey,
    required this.recoveryKeyHash,
  });
}

class BackupEncryptionSettingsService {
  static const String _configuredKey = 'backup_encryption_configured';
  static const String _configuredAtKey = 'backup_encryption_configured_at';
  static const String _recoveryKeyHashKey =
      'backup_encryption_recovery_key_hash';

  const BackupEncryptionSettingsService();

  Future<BackupEncryptionSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configured = prefs.getBool(_configuredKey) ?? false;
    final configuredAtRaw = prefs.getString(_configuredAtKey);
    return BackupEncryptionSettings(
      configured: configured,
      configuredAt:
          configuredAtRaw == null ? null : DateTime.tryParse(configuredAtRaw),
      recoveryKeyHash: prefs.getString(_recoveryKeyHashKey),
    );
  }

  BackupEncryptionSetupDraft createSetupDraft() {
    final recoveryKey = _generateRecoveryKey();
    return BackupEncryptionSetupDraft(
      recoveryKey: recoveryKey,
      recoveryKeyHash: _hashRecoveryKey(recoveryKey),
    );
  }

  Future<void> completeSetup(BackupEncryptionSetupDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_configuredKey, true);
    await prefs.setString(
      _configuredAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await prefs.setString(_recoveryKeyHashKey, draft.recoveryKeyHash);

    // TODO: Store the password-derived encryption secret in Keychain/Keystore.
    // Do not store the raw password or raw recovery key in SharedPreferences.
  }

  bool verifyRecoveryKey({
    required BackupEncryptionSettings settings,
    required String recoveryKey,
  }) {
    final expectedHash = settings.recoveryKeyHash;
    if (expectedHash == null || expectedHash.isEmpty) return false;
    return _hashRecoveryKey(recoveryKey) == expectedHash;
  }

  String _generateRecoveryKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(
      24,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    final groups = <String>[];
    for (var i = 0; i < code.length; i += 4) {
      groups.add(code.substring(i, i + 4));
    }
    return 'STOCK-${groups.join('-')}';
  }

  String _hashRecoveryKey(String recoveryKey) {
    final normalized = recoveryKey.trim().toUpperCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}
