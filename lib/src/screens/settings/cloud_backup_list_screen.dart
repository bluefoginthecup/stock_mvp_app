import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '/src/services/auth_service.dart';
import '/src/services/cloud_backup_service.dart';
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
  CloudBackupCleanupResult? _cleanupResult;

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
      final cleanupResult = await service.cleanupBackups();
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
                  child: _CloudBackupCard(backup: backup),
                ),
              ),
          ],
        ),
      ),
    );
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
            _InfoRow(label: 'ready 백업', value: '$readyCount개 / 최대 5개 유지'),
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

  const _CloudBackupCard({required this.backup});

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDateTime(backup.createdAt);
    final uploadedAt =
        backup.uploadedAt == null ? '-' : _formatDateTime(backup.uploadedAt!);
    final statusColor = _statusColor(context, backup.status);

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
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('복원 준비 중'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
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

  const _InfoRow({
    required this.label,
    required this.value,
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
          ),
        ),
      ],
    );
  }
}
