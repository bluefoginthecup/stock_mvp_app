import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:stockapp_mvp/src/services/seed_importer.dart';
import 'package:flutter/foundation.dart';
import 'package:stockapp_mvp/src/db/app_database.dart';
import 'dart:io';
import '/src/services/backup_file_delivery_service.dart';
import '/src/services/export_service.dart';
import '/src/services/full_backup_service.dart';
import '/src/services/full_restore_service.dart';
import '/src/services/restore_rollback_service.dart';
import '/src/services/storage_usage_service.dart';
// ⬆️ 여기에는 enum SeedPart와 UnifiedSeedImporter가 이미 포함되어 있어야 합니다.

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exportService = context.read<ExportService>(); // ← 여기 추가
    const fullBackupService = FullBackupService();
    const fullRestoreService = FullRestoreService();
    const backupFileDeliveryService = BackupFileDeliveryService();

    // 공통 실행 함수: 진행중 스피너 + 에러/성공 스낵바
    Future<void> runWithSpinner(
      Future<void> Function() job, {
      String okMsg = '완료했습니다.',
    }) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      String msg = okMsg;
      try {
        await job();
      } catch (e) {
        msg = '실패: $e';
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // progress 닫기
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    }

    Future<void> runWithSpinnerMessage(Future<String> Function() job) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      var msg = '완료했습니다.';
      try {
        msg = await job();
      } catch (e) {
        msg = '실패: $e';
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    }

    // 개별 파트 임포트 실행기
    Future<void> runPart(SeedPart part, String okMsg) async {
      await runWithSpinner(
        () => UnifiedSeedImporter.runPart(
          context,
          part: part,
          // 필요 시 에셋 경로 커스터마이즈 가능:
          // itemsAssetPath: 'assets/seeds/2025-10-26/items.json',
          // foldersAssetPath: 'assets/seeds/2025-10-26/folders.json',
          // bomAssetPath: 'assets/seeds/2025-10-26/bom.json',
          // lotsAssetPath: 'assets/seeds/2025-10-26/lots.json',
          clearBefore: false,
          verbose: true,
        ),
        okMsg: okMsg,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('설정')), // TODO: i18n 키가 있으면 교체
      body: ListView(
        children: [
          const _SectionHeader('일반'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('언어 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/settings/language'),
          ),

          const _StorageUsageSection(),

          const _SectionHeader('데이터'),

          // ───────────────── 전체 임포트 (기존)
          ListTile(
            leading: const Icon(Icons.download_for_offline),
            title: const Text('시드 임포트 (전체)'),
            subtitle: const Text('assets/seeds/2025-10-26의 JSON을 한 번에 불러옵니다'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('시드 임포트(전체)'),
                  content: const Text(
                      '현재 DB에 전체 시드 데이터를 가져올까요?\n기존 데이터와 병합/덮어쓰기는 SeedImporter 로직을 따릅니다.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;

              await runWithSpinner(
                () => UnifiedSeedImporter.run(context,
                    clearBefore: false, verbose: true),
                okMsg: '전체 임포트 완료',
              );
            },
          ),

          // ───────────────── 개별 임포트 (신규)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child:
                Text('개별 임포트', style: TextStyle(fontWeight: FontWeight.w600)),
          ),

          ListTile(
            leading: const Icon(Icons.archive_outlined, color: Colors.red),
            title: const Text(
              '전체 백업 내보내기',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text('DB와 영수증/거래명세서 첨부파일을 zip으로 공유합니다'),
            onTap: () async {
              await runWithSpinnerMessage(
                () async {
                  final result = await fullBackupService.createBackup();
                  final deliveryResult =
                      await backupFileDeliveryService.deliverBackupFile(
                    file: result.zipFile,
                    fileName: result.zipFile.uri.pathSegments.last,
                    subject: 'StockApp Full Backup',
                    allowedExtensions: const ['zip'],
                  );
                  return deliveryResult?.message('전체 백업') ??
                      '전체 백업 저장이 취소되었습니다';
                },
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('폴더만 임포트'),
            subtitle: const Text('folders.json만 반영 (트리 리빌드 포함)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('폴더만 임포트'),
                  content: const Text('folders.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.folders, '폴더 임포트 완료');
            },
          ),

          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('아이템만 임포트'),
            subtitle: const Text('items.json만 반영 (폴더 경로 자동 매칭 시도)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('아이템만 임포트'),
                  content: const Text('items.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.items, '아이템 임포트 완료');
            },
          ),

          ListTile(
            leading: const Icon(Icons.account_tree),
            title: const Text('BOM만 임포트'),
            subtitle: const Text('bom.json만 반영 (BOM 스냅샷/인덱스 리프레시)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('BOM만 임포트'),
                  content: const Text('bom.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.bom, 'BOM 임포트 완료');
            },
          ),

          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: const Text('로트만 임포트'),
            subtitle: const Text('lots.json만 반영 (트랜잭션/스냅샷 갱신)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('로트만 임포트'),
                  content: const Text('lots.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.lots, '로트 임포트 완료');
            },
          ),
          if (kDebugMode && Platform.isMacOS)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('개발용 DB 초기화'),
              subtitle: const Text('디버그 모드에서만 표시됩니다'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('DB 초기화'),
                    content: const Text('로컬 데이터베이스를 삭제하고 새로 생성합니다. 계속할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('초기화'),
                      ),
                    ],
                  ),
                );

                if (ok != true) return;

                await runWithSpinner(() async {
                  final db = AppDatabase();
                  await db.resetDatabase();
                }, okMsg: 'DB 초기화 완료. 앱을 다시 실행하세요.');
              },
            ),

          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('DB만 백업'),
            subtitle: const Text('문제 해결용: 첨부파일 없이 데이터베이스 파일만 공유합니다'),
            onTap: () async {
              await runWithSpinnerMessage(
                () => exportService.exportDatabase(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore_page_outlined, color: Colors.red),
            title: const Text(
              '전체 백업 복원',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text('DB와 영수증/거래명세서 첨부파일을 백업 시점으로 되돌립니다'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('전체 백업 복원'),
                  content: const Text(
                    '현재 DB와 첨부파일이 전체 백업 파일의 내용으로 교체됩니다.\n'
                    '복원 전 rollback 백업을 만들지만, 작업 중 앱을 종료하지 마세요.\n'
                    '복원이 완료되면 앱이 종료됩니다. 다시 실행해 주세요.\n\n'
                    '계속하시겠습니까?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('복원'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              if (!context.mounted) return;

              await Future<void>.delayed(const Duration(milliseconds: 100));
              if (!context.mounted) return;

              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['zip'],
              );
              final path = result?.files.single.path;
              if (path == null) return;

              var restored = false;
              FullRestoreResult? restoreResult;
              await runWithSpinner(
                () async {
                  restoreResult =
                      await fullRestoreService.restoreFromZip(File(path));
                  restored = true;
                },
                okMsg: '전체 백업 복원 완료',
              );

              if (!context.mounted) return;
              if (restored) {
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
                if (!context.mounted) return;

                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('복원 완료'),
                    content: const Text(
                      '전체 백업 복원이 완료되었습니다.\n'
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
            },
          ),
        ],
      ),
    );
  }
}

class _StorageUsageSection extends StatefulWidget {
  const _StorageUsageSection();

  @override
  State<_StorageUsageSection> createState() => _StorageUsageSectionState();
}

class _StorageUsageSectionState extends State<_StorageUsageSection> {
  final StorageUsageService _service = const StorageUsageService();
  final RestoreRollbackService _rollbackService =
      const RestoreRollbackService();
  StorageUsageSummary? _summary;
  RestoreRollbackSummary? _rollbackSummary;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await _service.calculate();
      final rollbackSummary = await _rollbackService.calculateUsage();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _rollbackSummary = rollbackSummary;
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
    final receiptUsage = _receiptUsage;
    final bytes = receiptUsage?.bytes ?? 0;
    final fileCount = receiptUsage?.fileCount ?? 0;
    final rollbackSummary = _rollbackSummary;
    final rollbackCount = rollbackSummary?.count ?? 0;
    final rollbackBytes = rollbackSummary?.totalBytes ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '저장공간 정보',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StorageUsageRow(
                label: '영수증/거래명세서',
                value: StorageUsageService.formatBytes(bytes),
              ),
              const SizedBox(height: 8),
              _StorageUsageRow(
                label: '파일 개수',
                value: '$fileCount개',
              ),
              const SizedBox(height: 8),
              _StorageUsageRow(
                label: '복원 rollback',
                value:
                    '$rollbackCount개 / ${StorageUsageService.formatBytes(rollbackBytes)}',
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '저장공간 정보를 불러오지 못했습니다.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('새로고침'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || rollbackCount == 0
                        ? null
                        : _cleanupRollbacks,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('오래된 rollback 정리'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  StorageFolderUsage? get _receiptUsage {
    final folders = _summary?.folders;
    if (folders == null) return null;
    for (final item in folders) {
      if (item.id == StorageUsageService.purchaseReceipts.id) {
        return item;
      }
    }
    return null;
  }

  Future<void> _cleanupRollbacks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _rollbackService.cleanupOldRollbacks();
      final summary = await _service.calculate();
      final rollbackSummary = await _rollbackService.calculateUsage();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _rollbackSummary = rollbackSummary;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'rollback ${result.deletedCount}개 정리 완료 '
            '(${StorageUsageService.formatBytes(result.deletedBytes)})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }
}

class _StorageUsageRow extends StatelessWidget {
  final String label;
  final String value;

  const _StorageUsageRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: style?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
