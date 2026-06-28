import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '/src/services/auth_service.dart';
import '/src/services/backup_encryption_service.dart';
import '/src/services/cloud_backup_service.dart';
import '/src/services/full_restore_service.dart';
import '/src/services/storage_usage_service.dart';

class CloudBackupListScreen extends StatefulWidget {
  const CloudBackupListScreen({super.key});

  @override
  State<CloudBackupListScreen> createState() => _CloudBackupListScreenState();
}

class _CloudBackupListScreenState extends State<CloudBackupListScreen> {
  CloudBackupService? _service;
  List<CloudBackupMetadata> _backups = const [];
  Object? _error;
  bool _loading = true;
  bool _restoring = false;
  bool _deleting = false;
  CloudBackupCleanupResult? _cleanupResult;
  final FullRestoreService _restoreService = const FullRestoreService();
  final BackupEncryptionService _encryptionService =
      const BackupEncryptionService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= CloudBackupService(
      authService: context.read<AuthService>(),
    );
    _refresh();
  }

  Future<void> _refresh() async {
    final service = _service;
    if (service == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      CloudBackupCleanupResult? cleanupResult;
      try {
        cleanupResult = await service.cleanupBackups();
      } catch (e) {
        debugPrint('☁️ CloudBackup cleanup skipped on list screen: $e');
      }
      final backups = await service.listBackups();
      if (!mounted) return;
      setState(() {
        _cleanupResult = cleanupResult;
        _backups = backups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('클라우드 백업 목록'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CloudBackupPolicyCard(
              uid: uid,
              loading: _loading,
              cleanupResult: _cleanupResult,
              backups: _backups,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _CloudBackupErrorCard(
                error: _error!,
                onRetry: _refresh,
              )
            else if (_backups.isEmpty)
              const _CloudBackupEmptyCard()
            else
              ..._backups.map(
                (backup) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CloudBackupCard(
                    backup: backup,
                    restoring: _restoring,
                    deleting: _deleting,
                    onRestore: backup.status == 'ready'
                        ? () => _restoreBackup(backup)
                        : null,
                    onDelete: () => _deleteBackup(backup),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreBackup(CloudBackupMetadata backup) async {
    final service = _service;
    if (service == null || _restoring) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이 백업으로 복원'),
        content: _CloudBackupRestorePreview(backup: backup),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.restore_outlined),
            label: const Text('백업 시점으로 되돌리기'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('복원 최종 확인'),
        content: const Text(
          '현재 앱 데이터가 선택한 클라우드 백업 시점으로 교체됩니다.\n\n'
          '현재 기기의 미백업 변경사항은 사라질 수 있습니다. '
          '복원 완료 후 앱이 종료됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('복원 실행'),
          ),
        ],
      ),
    );
    if (finalConfirm != true || !mounted) return;

    final decryptRequest = backup.encrypted
        ? await _showEncryptedBackupUnlockDialog()
        : const _EncryptedBackupUnlockRequest.none();
    if (decryptRequest == null || !mounted) return;

    setState(() => _restoring = true);
    FullRestoreResult? restoreResult;
    Object? error;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final download = await service.downloadBackupZip(backup);
      final restoreZip = backup.encrypted
          ? await _decryptCloudBackup(
              encryptedFile: download.zipFile,
              request: decryptRequest,
            )
          : download.zipFile;
      restoreResult = await _restoreService.restoreFromZip(restoreZip);
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _restoring = false);
      }
    }

    if (!mounted) return;
    if (error != null) {
      await _showRestoreErrorDialog(context, error);
      return;
    }

    final missingCount = restoreResult?.missingAttachmentCount ?? 0;
    if (missingCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('첨부파일 누락 경고'),
          content: Text(
            '전체 복원은 완료됐지만, purchase_receipts DB row 중 '
            '$missingCount개의 실제 첨부파일을 찾지 못했습니다.\n\n'
            '백업 zip 생성 시 이미 파일이 누락되었거나, zip 내부 첨부 폴더가 '
            '불완전할 수 있습니다.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('복원 완료'),
        content: const Text(
          '클라우드 백업 복원이 완료되었습니다.\n'
          '변경된 DB를 안전하게 다시 열기 위해 앱을 종료합니다.\n'
          '앱을 다시 실행해 주세요.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    exit(0);
  }

  Future<File> _decryptCloudBackup({
    required File encryptedFile,
    required _EncryptedBackupUnlockRequest request,
  }) async {
    final outputFile = File(
      p.join(
        encryptedFile.parent.path,
        '${p.basenameWithoutExtension(encryptedFile.path)}_decrypted.zip',
      ),
    );
    final decrypted = await _encryptionService.decryptToZip(
      encryptedFile: encryptedFile,
      outputFile: outputFile,
      password: request.password,
      recoveryKey: request.recoveryKey,
    );
    return decrypted.file;
  }

  Future<_EncryptedBackupUnlockRequest?> _showEncryptedBackupUnlockDialog() {
    final passwordController = TextEditingController();
    final recoveryKeyController = TextEditingController();
    var useRecoveryKey = false;
    String? errorText;

    return showDialog<_EncryptedBackupUnlockRequest>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('암호화 백업 잠금 해제'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이 백업은 암호화되어 있습니다. 백업 비밀번호 또는 복구키를 입력해야 복원할 수 있습니다.',
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('비밀번호'),
                      icon: Icon(Icons.password_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('복구키'),
                      icon: Icon(Icons.key_outlined),
                    ),
                  ],
                  selected: {useRecoveryKey},
                  onSelectionChanged: (selection) {
                    setDialogState(() {
                      useRecoveryKey = selection.first;
                      errorText = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (useRecoveryKey)
                  TextField(
                    controller: recoveryKeyController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: '복구키',
                      hintText: 'STOCK-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                      helperText: '공백과 소문자는 자동으로 정리됩니다.',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '백업 비밀번호',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (useRecoveryKey) {
                  final recoveryKey =
                      _normalizeRecoveryKey(recoveryKeyController.text);
                  if (recoveryKey.isEmpty) {
                    setDialogState(() => errorText = '복구키를 입력해주세요.');
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    _EncryptedBackupUnlockRequest(recoveryKey: recoveryKey),
                  );
                  return;
                }

                final password = passwordController.text;
                if (password.isEmpty) {
                  setDialogState(() => errorText = '비밀번호를 입력해주세요.');
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _EncryptedBackupUnlockRequest(password: password),
                );
              },
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('잠금 해제'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      passwordController.dispose();
      recoveryKeyController.dispose();
    });
  }

  static String _normalizeRecoveryKey(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _deleteBackup(CloudBackupMetadata backup) async {
    final service = _service;
    if (service == null || _restoring || _deleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('클라우드 백업 삭제'),
        content: _CloudBackupDeletePreview(backup: backup),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('백업 삭제'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    Object? error;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await service.deleteBackup(backup);
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _deleting = false);
      }
    }

    if (!mounted) return;
    if (error != null) {
      await _showDeleteErrorDialog(context, error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('클라우드 백업을 삭제했습니다.')),
    );
    await _refresh();
  }
}

class _CloudBackupPolicyCard extends StatelessWidget {
  final String? uid;
  final bool loading;
  final CloudBackupCleanupResult? cleanupResult;
  final List<CloudBackupMetadata> backups;

  const _CloudBackupPolicyCard({
    required this.uid,
    required this.loading,
    required this.cleanupResult,
    required this.backups,
  });

  @override
  Widget build(BuildContext context) {
    final readyCount =
        backups.where((backup) => backup.status == 'ready').length;
    final failedCount =
        backups.where((backup) => backup.status == 'failed').length;
    final uploadingCount =
        backups.where((backup) => backup.status == 'uploading').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '관리 정책',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: '계정 UID', value: uid ?? '로그인 필요'),
            const SizedBox(height: 8),
            _InfoRow(label: 'ready 백업', value: '$readyCount개 / 최대 10개 유지'),
            const SizedBox(height: 8),
            _InfoRow(label: '전체 백업', value: '${backups.length}개 / 최대 20개 유지'),
            const SizedBox(height: 8),
            _InfoRow(
              label: '기타 상태',
              value: 'failed $failedCount개 / uploading $uploadingCount개',
            ),
            if (cleanupResult != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: '최근 정리',
                value:
                    '삭제 ${cleanupResult!.deletedCount}개 / 실패전환 ${cleanupResult!.markedFailedCount}개',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CloudBackupCard extends StatelessWidget {
  final CloudBackupMetadata backup;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;
  final bool restoring;
  final bool deleting;

  const _CloudBackupCard({
    required this.backup,
    required this.onRestore,
    required this.onDelete,
    required this.restoring,
    required this.deleting,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDateTime(backup.createdAt);
    final uploadedAt =
        backup.uploadedAt == null ? '-' : _formatDateTime(backup.uploadedAt!);
    final statusColor = _statusColor(context, backup.status);
    final numberFormat = NumberFormat.decimalPattern('ko_KR');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    createdAt,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    backup.status.isEmpty ? 'unknown' : backup.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: '용량',
              value: StorageUsageService.formatBytes(backup.totalSizeBytes),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '백업 기기',
              value: _formatDevice(backup),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '아이템',
              value: _formatCount(backup.summaryItemCount, numberFormat),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '총 재고수량',
              value: _formatCount(backup.summaryTotalStockQty, numberFormat),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '거래처',
              value: _formatSupplierSummary(backup, numberFormat),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '최근 입출고',
              value: _formatLatestTxn(backup),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '최근 발주',
              value: _formatLatestPurchase(backup),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '첨부파일',
              value: _formatReceiptSummary(backup, numberFormat),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '암호화',
              value: backup.encrypted
                  ? '사용 (${backup.encryptionAlgorithm ?? 'AES-256-GCM'})'
                  : '미사용',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'schemaVersion',
              value: '${backup.dbSchemaVersion}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'backupFormat',
              value: '${backup.backupFormatVersion}',
            ),
            const SizedBox(height: 8),
            _InfoRow(label: '업로드 완료', value: uploadedAt),
            if (backup.status == 'failed') ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: '실패 시각',
                value: backup.failedAt == null
                    ? '-'
                    : _formatDateTime(backup.failedAt!),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: '실패 사유',
                value: _formatFailureReason(backup),
                valueColor: Theme.of(context).colorScheme.error,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Storage 경로',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.64),
                  ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              backup.storagePath.isEmpty ? '-' : backup.storagePath,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: restoring || deleting ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('삭제'),
                ),
                FilledButton.icon(
                  onPressed: restoring || deleting ? null : onRestore,
                  icon: const Icon(Icons.restore_outlined),
                  label: Text(
                    backup.status == 'ready' ? '이 백업으로 복원' : '복원 불가',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  static String _formatCount(int? value, NumberFormat numberFormat) {
    if (value == null) return '-';
    return numberFormat.format(value);
  }

  static String _formatDevice(CloudBackupMetadata backup) {
    final name = backup.deviceName?.trim();
    final platform = backup.devicePlatform?.trim();
    final osVersion = backup.deviceOsVersion?.trim();

    final main = [
      if (name != null && name.isNotEmpty) name,
      if (platform != null && platform.isNotEmpty) platform,
    ].join(' / ');
    if (main.isEmpty && (osVersion == null || osVersion.isEmpty)) return '-';
    if (osVersion == null || osVersion.isEmpty) return main;
    if (main.isEmpty) return osVersion;
    return '$main\n$osVersion';
  }

  static String _formatLatestPurchase(CloudBackupMetadata backup) {
    final date = backup.summaryLatestPurchaseOrderAt;
    if (date == null) return '-';
    final supplierName = backup.summaryLatestPurchaseSupplierName?.trim();
    if (supplierName == null || supplierName.isEmpty) {
      return _formatDateTime(date);
    }
    return '${_formatDateTime(date)} / $supplierName';
  }

  static String _formatSupplierSummary(
    CloudBackupMetadata backup,
    NumberFormat numberFormat,
  ) {
    final count = _formatCount(backup.summarySupplierCount, numberFormat);
    if (backup.summarySupplierNames.isEmpty) return count;
    final names = backup.summarySupplierNames.take(3).join(', ');
    final remaining = backup.summarySupplierNames.length - 3;
    final suffix = remaining > 0 ? ' 외 $remaining개' : '';
    return '$count / $names$suffix';
  }

  static String _formatLatestTxn(CloudBackupMetadata backup) {
    final date = backup.summaryLatestTxnAt;
    if (date == null) return '-';
    final itemName = backup.summaryLatestTxnItemName?.trim();
    final type = _formatTxnType(backup.summaryLatestTxnType);
    final qty = backup.summaryLatestTxnQty;
    final details = [
      if (type != null) type,
      if (qty != null && qty > 0)
        '${NumberFormat.decimalPattern('ko_KR').format(qty)}개',
      if (itemName != null && itemName.isNotEmpty) itemName,
    ].join(' / ');
    if (details.isEmpty) return _formatDateTime(date);
    return '${_formatDateTime(date)} / $details';
  }

  static String? _formatTxnType(String? type) {
    switch (type) {
      case 'in_':
      case 'in':
        return '입고';
      case 'out_':
      case 'out':
        return '출고';
      default:
        final trimmed = type?.trim();
        return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }
  }

  static String _formatFailureReason(CloudBackupMetadata backup) {
    final message = backup.errorMessage?.trim();
    if (message == null || message.isEmpty) {
      return '실패 사유가 기록되지 않았습니다.';
    }
    return message;
  }

  static String _formatReceiptSummary(
    CloudBackupMetadata backup,
    NumberFormat numberFormat,
  ) {
    final count = backup.receiptFileCount;
    final sizeBytes = backup.receiptTotalSizeBytes;
    if (count == null && sizeBytes == null) return '-';
    final countText = count == null ? '-' : '${numberFormat.format(count)}개';
    final sizeText =
        sizeBytes == null ? '-' : StorageUsageService.formatBytes(sizeBytes);
    return '$countText / $sizeText';
  }

  static Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'ready':
        return Colors.green.shade700;
      case 'failed':
        return Theme.of(context).colorScheme.error;
      case 'uploading':
        return Colors.orange.shade800;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }
}

String _formatDateTime(DateTime value) {
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}

class _EncryptedBackupUnlockRequest {
  final String? password;
  final String? recoveryKey;

  const _EncryptedBackupUnlockRequest({
    this.password,
    this.recoveryKey,
  });

  const _EncryptedBackupUnlockRequest.none()
      : password = null,
        recoveryKey = null;
}

class _CloudBackupRestorePreview extends StatelessWidget {
  final CloudBackupMetadata backup;

  const _CloudBackupRestorePreview({required this.backup});

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern('ko_KR');

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 DB와 첨부파일을 아래 백업 시점으로 되돌립니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                '현재 기기의 미백업 변경사항은 사라질 수 있습니다. '
                '복원 완료 후 앱이 종료됩니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 14),
            _InfoRow(label: '생성일', value: _formatDateTime(backup.createdAt)),
            const SizedBox(height: 8),
            _InfoRow(
              label: '백업 기기',
              value: _CloudBackupCard._formatDevice(backup),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '용량',
              value: StorageUsageService.formatBytes(backup.totalSizeBytes),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '아이템',
              value: _CloudBackupCard._formatCount(
                backup.summaryItemCount,
                numberFormat,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '총 재고수량',
              value: _CloudBackupCard._formatCount(
                backup.summaryTotalStockQty,
                numberFormat,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '거래처',
              value: _CloudBackupCard._formatSupplierSummary(
                backup,
                numberFormat,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '최근 입출고',
              value: _CloudBackupCard._formatLatestTxn(backup),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '최근 발주',
              value: _CloudBackupCard._formatLatestPurchase(backup),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '첨부파일',
              value: _CloudBackupCard._formatReceiptSummary(
                backup,
                numberFormat,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '암호화',
              value: backup.encrypted
                  ? '사용 (${backup.encryptionAlgorithm ?? 'AES-256-GCM'})'
                  : '미사용',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'schemaVersion',
              value: '${backup.dbSchemaVersion}',
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudBackupDeletePreview extends StatelessWidget {
  final CloudBackupMetadata backup;

  const _CloudBackupDeletePreview({required this.backup});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 클라우드 백업을 삭제합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                'Firebase Storage의 zip을 먼저 삭제한 뒤 Firestore metadata를 삭제합니다. '
                '삭제한 클라우드 백업은 복원할 수 없습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 14),
            _InfoRow(label: '생성일', value: _formatDateTime(backup.createdAt)),
            const SizedBox(height: 8),
            _InfoRow(
              label: '백업 기기',
              value: _CloudBackupCard._formatDevice(backup),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: '상태', value: backup.status),
            const SizedBox(height: 8),
            _InfoRow(
              label: '용량',
              value: StorageUsageService.formatBytes(backup.totalSizeBytes),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: '첨부파일',
              value: _CloudBackupCard._formatReceiptSummary(
                backup,
                NumberFormat.decimalPattern('ko_KR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showDeleteErrorDialog(
  BuildContext context,
  Object error,
) {
  var title = '클라우드 백업 삭제 실패';
  var message = '클라우드 백업 삭제 중 오류가 발생했습니다.\n\n$error';

  if (error is CloudBackupException) {
    message = error.message;
    switch (error.code) {
      case CloudBackupErrorCode.storageDelete:
        title = 'Storage zip 삭제 실패';
        message = '${error.message}\n\n'
            'Firestore metadata는 삭제하지 않았습니다. '
            '잠시 후 다시 시도하면 Storage와 Firestore 불일치를 줄일 수 있습니다.';
        break;
      case CloudBackupErrorCode.metadataDelete:
        title = 'Firestore metadata 삭제 실패';
        message = '${error.message}\n\n'
            'Storage zip은 이미 삭제되었을 수 있습니다. '
            '목록을 새로고침한 뒤 같은 항목이 남아 있으면 다시 삭제를 시도해주세요.';
        break;
      default:
        break;
    }
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

Future<void> _showRestoreErrorDialog(
  BuildContext context,
  Object error,
) {
  var title = '클라우드 백업 복원 실패';
  var message = '클라우드 백업 복원 중 오류가 발생했습니다.\n\n$error';

  if (error is FullRestoreException) {
    message = error.message;
    switch (error.code) {
      case FullRestoreErrorCode.schemaTooNew:
        title = '앱 업데이트 후 복원 필요';
        message = '이 백업은 더 최신 앱 버전에서 생성되었습니다.\n'
            '앱 업데이트 후 다시 시도해주세요.';
        break;
      case FullRestoreErrorCode.manifestInvalid:
        title = 'manifest 손상';
        break;
      case FullRestoreErrorCode.checksumMismatch:
        title = 'checksum 검증 실패';
        break;
      case FullRestoreErrorCode.databaseInvalid:
      case FullRestoreErrorCode.missingRequiredTables:
        title = '백업 DB 검증 실패';
        break;
      case FullRestoreErrorCode.rollbackFailed:
        title = 'rollback 실패';
        break;
      case FullRestoreErrorCode.general:
        break;
    }
  } else if (error is CloudBackupException) {
    title = '클라우드 백업 다운로드 실패';
    message = error.message;
  } else if (error is BackupEncryptionException) {
    title = '암호화 백업 잠금 해제 실패';
    message = '비밀번호 또는 복구키가 올바르지 않거나 백업 파일이 손상되었습니다.\n\n'
        '${error.message}';
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class _CloudBackupErrorCard extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _CloudBackupErrorCard({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = error is CloudBackupException
        ? (error as CloudBackupException).message
        : '클라우드 백업 목록을 불러오지 못했습니다.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '목록 불러오기 실패',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudBackupEmptyCard extends StatelessWidget {
  const _CloudBackupEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('아직 클라우드 백업이 없습니다'),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.64),
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.visible,
            style: valueColor == null ? null : TextStyle(color: valueColor),
          ),
        ),
      ],
    );
  }
}
