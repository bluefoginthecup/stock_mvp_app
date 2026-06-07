import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'backup_encryption_key_store.dart';
import 'cloud_backup_service.dart';
import 'entitlement_service.dart';

enum CloudAutoBackupFrequency {
  daily,
  weekly,
  monthly,
}

class CloudAutoBackupSettings {
  final bool enabled;
  final CloudAutoBackupFrequency frequency;

  const CloudAutoBackupSettings({
    required this.enabled,
    required this.frequency,
  });

  static const defaults = CloudAutoBackupSettings(
    enabled: false,
    frequency: CloudAutoBackupFrequency.daily,
  );

  Duration get interval {
    switch (frequency) {
      case CloudAutoBackupFrequency.daily:
        return const Duration(days: 1);
      case CloudAutoBackupFrequency.weekly:
        return const Duration(days: 7);
      case CloudAutoBackupFrequency.monthly:
        return const Duration(days: 30);
    }
  }

  String get label {
    switch (frequency) {
      case CloudAutoBackupFrequency.daily:
        return '매일';
      case CloudAutoBackupFrequency.weekly:
        return '매주';
      case CloudAutoBackupFrequency.monthly:
        return '매달';
    }
  }
}

class CloudAutoBackupRunResult {
  final bool attempted;
  final bool uploaded;
  final String message;
  final CloudBackupMetadata? backup;

  const CloudAutoBackupRunResult({
    required this.attempted,
    required this.uploaded,
    required this.message,
    this.backup,
  });
}

class CloudAutoBackupService {
  static const Duration minimumAttemptCooldown = Duration(hours: 12);
  static const String _enabledKey = 'cloud_auto_backup_enabled';
  static const String _frequencyKey = 'cloud_auto_backup_frequency';
  static const String _lastAttemptPrefix = 'cloud_auto_backup_last_attempt_';
  static const String _lastSuccessPrefix = 'cloud_auto_backup_last_success_';

  const CloudAutoBackupService({
    required this.authService,
    CloudBackupService? cloudBackupService,
    EntitlementService? entitlementService,
    this.keyStore = const BackupEncryptionKeyStore(),
  })  : _cloudBackupService = cloudBackupService,
        _entitlementService = entitlementService;

  final AuthService authService;
  final CloudBackupService? _cloudBackupService;
  final EntitlementService? _entitlementService;
  final BackupEncryptionKeyStore keyStore;

  CloudBackupService get cloudBackupService =>
      _cloudBackupService ?? CloudBackupService(authService: authService);

  Future<CloudAutoBackupSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final frequencyName = prefs.getString(_frequencyKey) ??
        CloudAutoBackupSettings.defaults.frequency.name;
    return CloudAutoBackupSettings(
      enabled: prefs.getBool(_enabledKey) ??
          CloudAutoBackupSettings.defaults.enabled,
      frequency: CloudAutoBackupFrequency.values.firstWhere(
        (item) => item.name == frequencyName,
        orElse: () => CloudAutoBackupSettings.defaults.frequency,
      ),
    );
  }

  Future<void> saveSettings(CloudAutoBackupSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setString(_frequencyKey, settings.frequency.name);
  }

  Future<DateTime?> lastAttemptAt({String? uid}) async {
    final resolvedUid = uid ?? authService.uid;
    if (resolvedUid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(
        prefs.getString('$_lastAttemptPrefix$resolvedUid') ?? '');
  }

  Future<DateTime?> lastSuccessAt({String? uid}) async {
    final resolvedUid = uid ?? authService.uid;
    if (resolvedUid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(
        prefs.getString('$_lastSuccessPrefix$resolvedUid') ?? '');
  }

  Future<CloudAutoBackupRunResult> runIfDue() async {
    final uid = authService.uid;
    if (uid == null) {
      return const CloudAutoBackupRunResult(
        attempted: false,
        uploaded: false,
        message: '로그인 전이라 자동 백업을 건너뜁니다.',
      );
    }

    final settings = await loadSettings();
    if (!settings.enabled) {
      return const CloudAutoBackupRunResult(
        attempted: false,
        uploaded: false,
        message: '자동 백업이 꺼져 있습니다.',
      );
    }

    final entitlementService =
        _entitlementService ?? EntitlementService(authService: authService);
    final entitlement = await entitlementService.loadEntitlement();
    if (!entitlement.canCreateCloudBackup) {
      return const CloudAutoBackupRunResult(
        attempted: false,
        uploaded: false,
        message: 'Cloud Backup 권한이 없어 자동 백업을 건너뜁니다.',
      );
    }

    final now = DateTime.now();
    final lastAttempt = await lastAttemptAt(uid: uid);
    if (lastAttempt != null &&
        now.difference(lastAttempt) < minimumAttemptCooldown) {
      return const CloudAutoBackupRunResult(
        attempted: false,
        uploaded: false,
        message: '최근 자동 백업 시도가 있어 건너뜁니다.',
      );
    }

    try {
      final latestReady = await cloudBackupService.latestReadyBackup();
      if (latestReady != null &&
          now.difference(latestReady.createdAt) < settings.interval) {
        return CloudAutoBackupRunResult(
          attempted: false,
          uploaded: false,
          message: '최근 클라우드 백업이 있어 건너뜁니다.',
          backup: latestReady,
        );
      }

      final secret = await keyStore.readSecret();
      if (secret == null) {
        return const CloudAutoBackupRunResult(
          attempted: false,
          uploaded: false,
          message: '백업 암호화 secret이 없어 자동 백업을 건너뜁니다.',
        );
      }

      await _saveLastAttempt(uid, now);
      debugPrint('☁️ CloudAutoBackup: upload start');
      final result = await cloudBackupService.uploadFullBackup(
        skipIfContentUnchanged: true,
        encryption: CloudBackupEncryptionRequest(
          passwordSecret: secret.passwordSecret,
          recoverySecret: secret.recoverySecret,
        ),
      );
      if (result.skippedDuplicate) {
        return CloudAutoBackupRunResult(
          attempted: true,
          uploaded: false,
          message: '이전 백업과 내용이 같아 새 백업을 만들지 않습니다.',
          backup: result.metadata,
        );
      }
      await _saveLastSuccess(uid, DateTime.now());
      debugPrint('☁️ CloudAutoBackup: upload done ${result.metadata.backupId}');
      return CloudAutoBackupRunResult(
        attempted: true,
        uploaded: true,
        message: '자동 백업 완료',
        backup: result.metadata,
      );
    } catch (e, stackTrace) {
      debugPrint('☁️ CloudAutoBackup failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return CloudAutoBackupRunResult(
        attempted: true,
        uploaded: false,
        message: '자동 백업 실패: $e',
      );
    }
  }

  Future<void> _saveLastAttempt(String uid, DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_lastAttemptPrefix$uid',
      value.toUtc().toIso8601String(),
    );
  }

  Future<void> _saveLastSuccess(String uid, DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_lastSuccessPrefix$uid',
      value.toUtc().toIso8601String(),
    );
  }
}
