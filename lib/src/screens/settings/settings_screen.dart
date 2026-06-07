import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:stockapp_mvp/src/services/seed_importer.dart';
import 'package:flutter/foundation.dart';
import 'package:stockapp_mvp/src/db/app_database.dart';
import 'dart:io';
import '/src/models/attachment_domain.dart';
import '/src/models/app_entitlement.dart';
import '/src/models/buyer_profile.dart';
import '/src/models/subscription_plan.dart';
import '/src/services/backup_file_delivery_service.dart';
import '/src/services/backup_encryption_settings_service.dart';
import '/src/services/backup_encryption_key_store.dart';
import '/src/services/auth_service.dart';
import '/src/services/attachment_limit_config.dart';
import '/src/services/buyer_profile_service.dart';
import '/src/services/cloud_auto_backup_service.dart';
import '/src/services/cloud_backup_service.dart';
import '/src/services/entitlement_service.dart';
import '/src/services/export_service.dart';
import '/src/services/full_backup_service.dart';
import '/src/services/full_restore_service.dart';
import '/src/services/restore_rollback_service.dart';
import '/src/services/revenuecat_purchase_service.dart';
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
    final showDeveloperSeedImport = kDebugMode && Platform.isMacOS;

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

    Future<bool> runRestoreWithSpinner(Future<void> Function() job) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      FullRestoreException? restoreError;
      Object? otherError;
      try {
        await job();
      } on FullRestoreException catch (e) {
        restoreError = e;
      } catch (e) {
        otherError = e;
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (!context.mounted) return false;
      if (restoreError != null) {
        await _showRestoreErrorDialog(context, restoreError);
        return false;
      }
      if (otherError != null) {
        await _showSimpleErrorDialog(
          context,
          title: '복원 실패',
          message: '전체 백업 복원 중 오류가 발생했습니다.\n\n$otherError',
        );
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전체 백업 복원 완료')),
      );
      return true;
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
          const _AccountSection(),
          const _BuyerProfileSection(),
          const _StorageUsageSection(),
          const _BackupEncryptionSection(),
          const _CloudBackupSection(),
          const _SectionHeader('데이터'),
          if (showDeveloperSeedImport) ...[
            const _SectionHeader('개발자 도구'),
            ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: const Text('시드 임포트 (전체)'),
              subtitle: const Text('assets/seeds/2025-10-26의 JSON을 한 번에 불러옵니다'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('시드 임포트(전체)'),
                    content: const Text(
                        '현재 DB에 전체 시드 데이터를 가져올까요?\n기존 데이터와 병합/덮어쓰기는 SeedImporter 로직을 따릅니다.'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('취소')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
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
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('폴더만 임포트'),
              subtitle: const Text('folders.json만 반영 (트리 리빌드 포함)'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('폴더만 임포트'),
                    content: const Text('folders.json만 임포트합니다. 계속할까요?'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('취소')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
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
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('아이템만 임포트'),
                    content: const Text('items.json만 임포트합니다. 계속할까요?'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('취소')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
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
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('BOM만 임포트'),
                    content: const Text('bom.json만 임포트합니다. 계속할까요?'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('취소')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
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
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('로트만 임포트'),
                    content: const Text('lots.json만 임포트합니다. 계속할까요?'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('취소')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('가져오기')),
                    ],
                  ),
                );
                if (ok != true) return;
                await runPart(SeedPart.lots, '로트 임포트 완료');
              },
            ),
          ],
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
          if (kDebugMode && Platform.isMacOS)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('개발용 DB 초기화'),
              subtitle: const Text('디버그 모드에서만 표시됩니다'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('DB 초기화'),
                    content: const Text('로컬 데이터베이스를 삭제하고 새로 생성합니다. 계속할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
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
              restored = await runRestoreWithSpinner(
                () async {
                  restoreResult =
                      await fullRestoreService.restoreFromZip(File(path));
                },
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

Future<void> _showRestoreErrorDialog(
  BuildContext context,
  FullRestoreException error,
) {
  switch (error.code) {
    case FullRestoreErrorCode.schemaTooNew:
      return _showSimpleErrorDialog(
        context,
        title: '앱 업데이트 후 복원 필요',
        message: '이 백업은 더 최신 앱 버전에서 생성되었습니다.\n'
            '앱 업데이트 후 다시 시도해주세요.',
      );
    case FullRestoreErrorCode.checksumMismatch:
      return _showSimpleErrorDialog(
        context,
        title: '백업 파일 검증 실패',
        message: '백업 파일의 크기 또는 checksum이 맞지 않아 복원을 중단했습니다.\n'
            '파일이 손상되었거나 일부 내용이 바뀌었을 수 있습니다.\n\n'
            '${error.message}',
      );
    case FullRestoreErrorCode.manifestInvalid:
      return _showSimpleErrorDialog(
        context,
        title: '백업 정보 손상',
        message: 'manifest.json이 없거나 형식이 올바르지 않아 복원할 수 없습니다.\n\n'
            '${error.message}',
      );
    case FullRestoreErrorCode.databaseInvalid:
    case FullRestoreErrorCode.missingRequiredTables:
      return _showSimpleErrorDialog(
        context,
        title: '백업 DB 검증 실패',
        message: '백업 DB가 정상적인 앱 데이터베이스인지 확인하지 못해 복원을 중단했습니다.\n\n'
            '${error.message}',
      );
    case FullRestoreErrorCode.rollbackFailed:
      return _showSimpleErrorDialog(
        context,
        title: '복원 실패',
        message: error.message,
      );
    case FullRestoreErrorCode.general:
      return _showSimpleErrorDialog(
        context,
        title: '복원 실패',
        message: error.message,
      );
  }
}

Future<void> _showCloudBackupErrorDialog(
  BuildContext context,
  CloudBackupException error,
) {
  switch (error.code) {
    case CloudBackupErrorCode.notSignedIn:
      return _showSimpleErrorDialog(
        context,
        title: '로그인 필요',
        message: '로그인 후 클라우드 백업을 사용할 수 있습니다.',
      );
    case CloudBackupErrorCode.firebaseNotInitialized:
      return _showSimpleErrorDialog(
        context,
        title: 'Firebase 초기화 실패',
        message: 'Firebase 초기화가 완료되지 않았습니다. 앱을 다시 실행한 뒤 시도해주세요.',
      );
    case CloudBackupErrorCode.firestoreConnection:
    case CloudBackupErrorCode.metadataWrite:
      return _showSimpleErrorDialog(
        context,
        title: 'Firestore 연결 실패',
        message: 'Firestore 연결에 실패했습니다. Firebase 설정 또는 네트워크를 확인해주세요.',
      );
    case CloudBackupErrorCode.storageUpload:
      return _showSimpleErrorDialog(
        context,
        title: 'Storage 업로드 실패',
        message:
            'Firebase Storage 업로드에 실패했습니다. Firebase Storage 설정 또는 네트워크를 확인해주세요.',
      );
    case CloudBackupErrorCode.storageDelete:
      return _showSimpleErrorDialog(
        context,
        title: 'Storage 삭제 실패',
        message: error.message,
      );
    case CloudBackupErrorCode.metadataDelete:
      return _showSimpleErrorDialog(
        context,
        title: 'Firestore metadata 삭제 실패',
        message: error.message,
      );
    case CloudBackupErrorCode.general:
      return _showSimpleErrorDialog(
        context,
        title: '클라우드 백업 실패',
        message: '클라우드 백업 중 오류가 발생했습니다.',
      );
  }
}

Future<void> _showSimpleErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
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

class _AccountSection extends StatefulWidget {
  const _AccountSection();

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  EntitlementService? _entitlementService;
  AppEntitlement _entitlement = AppEntitlement.signedOut;
  bool _loadingEntitlement = true;
  bool _workingEntitlement = false;
  Object? _entitlementError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entitlementService ??= context.read<EntitlementService>();
    _loadEntitlement();
  }

  Future<void> _loadEntitlement() async {
    final service = _entitlementService;
    if (service == null) return;
    setState(() {
      _loadingEntitlement = true;
      _entitlementError = null;
    });
    try {
      final entitlement = await service.loadEntitlement();
      if (!mounted) return;
      setState(() {
        _entitlement = entitlement;
        _loadingEntitlement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entitlementError = e;
        _loadingEntitlement = false;
      });
    }
  }

  Future<void> _runEntitlementAction(
    Future<AppEntitlement> Function(EntitlementService service) action,
    String successMessage,
  ) async {
    final service = _entitlementService;
    if (service == null || _workingEntitlement) return;
    setState(() {
      _workingEntitlement = true;
      _entitlementError = null;
    });
    try {
      final entitlement = await action(service);
      if (!mounted) return;
      setState(() => _entitlement = entitlement);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _entitlementError = e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _workingEntitlement = false);
    }
  }

  Future<void> _runPurchaseOptionAction({
    required String title,
    required Future<List<RevenueCatPackageOption>> Function(
      EntitlementService service,
    ) loadOptions,
    required Future<AppEntitlement> Function(
      EntitlementService service,
      String productId,
    ) purchase,
    required String successMessage,
  }) async {
    final service = _entitlementService;
    if (service == null || _workingEntitlement) return;

    setState(() {
      _workingEntitlement = true;
      _entitlementError = null;
    });

    try {
      final options = await loadOptions(service);
      if (!mounted) return;
      setState(() => _workingEntitlement = false);

      final selected = await _showPurchaseOptions(
        context: context,
        title: title,
        options: options,
      );
      if (selected == null) return;

      setState(() => _workingEntitlement = true);
      final entitlement = await purchase(service, selected.productId);
      if (!mounted) return;
      setState(() => _entitlement = entitlement);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _entitlementError = e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _workingEntitlement = false);
    }
  }

  Future<RevenueCatPackageOption?> _showPurchaseOptions({
    required BuildContext context,
    required String title,
    required List<RevenueCatPackageOption> options,
  }) {
    if (options.isEmpty) {
      throw const RevenueCatProductNotFoundException(<String>{});
    }

    return showModalBottomSheet<RevenueCatPackageOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option.displayName),
                  subtitle: Text(
                    [
                      option.periodLabel,
                      option.productId,
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: Text(
                    option.priceString,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('현재 Google 계정에서 로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await context.read<AuthService>().signOut();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil(
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그아웃 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildEntitlementPanel(BuildContext context) {
    const limits = AttachmentLimitConfig.defaults;
    final service = _entitlementService;
    final purchasesReady = service?.purchaseConfigured ?? false;
    final appTrialAvailable =
        _entitlement.appTrialEndsAt == null && !_entitlement.isPaidPlan;
    final cloudTrialAvailable = _entitlement.cloudTrialEndsAt == null &&
        !_entitlement.hasCloudBackup &&
        _entitlement.canUseProFeatures;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),
        _StorageUsageRow(
          label: '현재 플랜',
          value: _loadingEntitlement ? '확인 중...' : _entitlement.planLabel,
        ),
        const SizedBox(height: 8),
        _StorageUsageRow(
          label: 'App Trial',
          value: _trialStatus(
            active: _entitlement.isAppTrialActive,
            endsAt: _entitlement.appTrialEndsAt,
            notStartedLabel: '시작 전',
          ),
        ),
        const SizedBox(height: 8),
        _StorageUsageRow(
          label: 'Cloud Backup',
          value: _entitlement.cloudBackupLabel,
        ),
        const SizedBox(height: 8),
        _StorageUsageRow(
          label: 'Cloud Trial',
          value: _trialStatus(
            active: _entitlement.isCloudTrialActive,
            endsAt: _entitlement.cloudTrialEndsAt,
            notStartedLabel: '시작 전',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _workingEntitlement ||
                      _loadingEntitlement ||
                      !appTrialAvailable
                  ? null
                  : () => _runEntitlementAction(
                        (service) => service.startAppTrial(),
                        '7일 무료체험을 시작했습니다.',
                      ),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('7일 무료체험 시작'),
            ),
            FilledButton.icon(
              onPressed: _workingEntitlement ||
                      _loadingEntitlement ||
                      _entitlement.isPaidPlan ||
                      !purchasesReady
                  ? null
                  : () => _runPurchaseOptionAction(
                        title: 'Pro 구독 선택',
                        loadOptions: (service) => service.proPackageOptions(),
                        purchase: (service, productId) =>
                            service.purchaseProProduct(productId),
                        successMessage: 'Pro 구독 상태를 확인했습니다.',
                      ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Pro 구독'),
            ),
            OutlinedButton.icon(
              onPressed: _workingEntitlement ||
                      _loadingEntitlement ||
                      !cloudTrialAvailable
                  ? null
                  : () => _runEntitlementAction(
                        (service) => service.startCloudTrial(),
                        'Cloud Backup 체험을 시작했습니다.',
                      ),
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Cloud Backup 체험 시작'),
            ),
            OutlinedButton.icon(
              onPressed: _workingEntitlement ||
                      _loadingEntitlement ||
                      !_entitlement.isPaidPlan ||
                      _entitlement.hasCloudBackup ||
                      !purchasesReady
                  ? null
                  : () => _runPurchaseOptionAction(
                        title: 'Cloud Backup 구독 선택',
                        loadOptions: (service) =>
                            service.cloudBackupPackageOptions(),
                        purchase: (service, productId) =>
                            service.purchaseCloudBackupProduct(productId),
                        successMessage: 'Cloud Backup 구독 상태를 확인했습니다.',
                      ),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Cloud Backup 구독'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _workingEntitlement || _loadingEntitlement || !purchasesReady
                      ? null
                      : () => _runEntitlementAction(
                            (service) => service.restorePurchases(),
                            '구매 복원을 완료했습니다.',
                          ),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('구매 복원'),
            ),
          ],
        ),
        if (!purchasesReady) ...[
          const SizedBox(height: 8),
          Text(
            'RevenueCat API key가 없어 구독 버튼은 비활성화되어 있습니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.62),
                ),
          ),
        ],
        if (_entitlementError != null) ...[
          const SizedBox(height: 8),
          Text(
            '권한 정보를 확인하지 못했습니다: $_entitlementError',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        _PlanLimitSummary(
          plan: _entitlement.canUseProFeatures
              ? SubscriptionPlan.pro
              : SubscriptionPlan.free,
          limitConfig: limits,
        ),
      ],
    );
  }

  String _trialStatus({
    required bool active,
    required DateTime? endsAt,
    String notStartedLabel = '없음',
  }) {
    if (endsAt == null) return notStartedLabel;
    if (!active) return '종료됨';
    final remaining = endsAt.difference(DateTime.now());
    final days = remaining.inDays + 1;
    return '$days일 남음';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return StreamBuilder(
      stream: auth.userStream,
      initialData: auth.currentUser,
      builder: (context, snapshot) {
        final user = auth.currentUser;
        final email = user?.email;
        final name = user?.displayName;
        final uid = user?.uid;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '계정',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _StorageUsageRow(
                    label: '로그인 상태',
                    value: user == null ? '로그아웃됨' : '로그인됨',
                  ),
                  const SizedBox(height: 8),
                  _StorageUsageRow(
                    label: '사용자 이메일',
                    value: email?.isNotEmpty == true ? email! : '-',
                  ),
                  const SizedBox(height: 8),
                  _StorageUsageRow(
                    label: '사용자 이름',
                    value: name?.isNotEmpty == true ? name! : '-',
                  ),
                  if (uid != null) ...[
                    const SizedBox(height: 10),
                    SelectableText(
                      'UID: $uid',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  _buildEntitlementPanel(context),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: user == null ? null : () => _signOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('로그아웃'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanLimitSummary extends StatelessWidget {
  const _PlanLimitSummary({
    required this.plan,
    required this.limitConfig,
  });

  final SubscriptionPlan plan;
  final AttachmentLimitConfig limitConfig;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const domains = [
      AttachmentDomain.itemImages,
      AttachmentDomain.purchaseReceipts,
      AttachmentDomain.scheduleAttachments,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plan.label} 첨부 한도',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final domain in domains) ...[
              _StorageUsageRow(
                label: domain.label,
                value: limitConfig
                    .limitFor(plan: plan, domain: domain)
                    .summaryFor(domain),
              ),
              if (domain != domains.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _BuyerProfileSection extends StatefulWidget {
  const _BuyerProfileSection();

  @override
  State<_BuyerProfileSection> createState() => _BuyerProfileSectionState();
}

class _BuyerProfileSectionState extends State<_BuyerProfileSection> {
  late final BuyerProfileService _service;
  List<BuyerProfile> _profiles = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _service = BuyerProfileService(context.read<AppDatabase>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profiles = await _service.listProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
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

  BuyerProfile _slotProfile(int id) {
    return _profiles.where((profile) => profile.id == id).firstOrNull ??
        BuyerProfile(
          id: id,
          profileName: '',
          businessNumber: '',
          companyName: '',
          representative: '',
          address: '',
          businessType: '',
          businessItem: '',
          phoneFax: '',
          isDefault: false,
          updatedAt: DateTime.now(),
        );
  }

  Future<void> _edit(BuyerProfile profile) async {
    final edited = await _showBuyerProfileEditor(context, profile);
    if (edited == null) return;

    await _service.saveProfile(edited);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공급받는자 정보를 저장했습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '공급받는자 정보',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '발주서에 표시될 내 사업자 정보를 최대 2개까지 저장합니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text('불러오기 실패: $_error')
              else
                Column(
                  children: [
                    _BuyerProfileTile(
                      profile: _slotProfile(1),
                      onTap: () => _edit(_slotProfile(1)),
                    ),
                    const Divider(height: 1),
                    _BuyerProfileTile(
                      profile: _slotProfile(2),
                      onTap: () => _edit(_slotProfile(2)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyerProfileTile extends StatelessWidget {
  final BuyerProfile profile;
  final VoidCallback onTap;

  const _BuyerProfileTile({
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final configured = profile.isConfigured;
    final title = configured ? profile.displayName : '공급받는자 ${profile.id}';
    final subtitle = configured
        ? [
            if (profile.companyName.trim().isNotEmpty) profile.companyName,
            if (profile.businessNumber.trim().isNotEmpty)
              profile.businessNumber,
            if (profile.representative.trim().isNotEmpty)
              profile.representative,
          ].join(' / ')
        : '미설정';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        configured ? Icons.business_outlined : Icons.add_business_outlined,
      ),
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (profile.isDefault)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Chip(label: Text('기본')),
            ),
        ],
      ),
      subtitle: Text(subtitle.isEmpty ? '미설정' : subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

Future<BuyerProfile?> _showBuyerProfileEditor(
  BuildContext context,
  BuyerProfile profile,
) {
  final profileNameC = TextEditingController(text: profile.profileName);
  final businessNumberC = TextEditingController(text: profile.businessNumber);
  final companyNameC = TextEditingController(text: profile.companyName);
  final representativeC = TextEditingController(text: profile.representative);
  final addressC = TextEditingController(text: profile.address);
  final businessTypeC = TextEditingController(text: profile.businessType);
  final businessItemC = TextEditingController(text: profile.businessItem);
  final phoneFaxC = TextEditingController(text: profile.phoneFax);
  var isDefault = profile.isDefault;

  return showModalBottomSheet<BuyerProfile>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '공급받는자 ${profile.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('기본 공급받는자로 사용'),
                    value: isDefault,
                    onChanged: (value) {
                      setSheetState(() => isDefault = value);
                    },
                  ),
                  TextField(
                    controller: profileNameC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '프로필 이름'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: businessNumberC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '사업자등록번호'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: companyNameC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '상호'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: representativeC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '대표자'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressC,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '주소'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: businessTypeC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '업태'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: businessItemC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '종목'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneFaxC,
                    decoration: const InputDecoration(labelText: '전화/팩스'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop(
                        profile.copyWith(
                          profileName: profileNameC.text.trim(),
                          businessNumber: businessNumberC.text.trim(),
                          companyName: companyNameC.text.trim(),
                          representative: representativeC.text.trim(),
                          address: addressC.text.trim(),
                          businessType: businessTypeC.text.trim(),
                          businessItem: businessItemC.text.trim(),
                          phoneFax: phoneFaxC.text.trim(),
                          isDefault: isDefault,
                          updatedAt: DateTime.now(),
                        ),
                      );
                    },
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    profileNameC.dispose();
    businessNumberC.dispose();
    companyNameC.dispose();
    representativeC.dispose();
    addressC.dispose();
    businessTypeC.dispose();
    businessItemC.dispose();
    phoneFaxC.dispose();
  });
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
                    label: const Text('rollback 모두 삭제'),
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
      final result = await _rollbackService.cleanupAllRollbacks();
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

class _BackupEncryptionSection extends StatefulWidget {
  const _BackupEncryptionSection();

  @override
  State<_BackupEncryptionSection> createState() =>
      _BackupEncryptionSectionState();
}

class _BackupEncryptionSectionState extends State<_BackupEncryptionSection> {
  final BackupEncryptionSettingsService _service =
      const BackupEncryptionSettingsService();
  final BackupEncryptionKeyStore _keyStore = const BackupEncryptionKeyStore();
  BackupEncryptionSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

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
      final settings = await _service.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
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

  Future<void> _setupEncryption() async {
    if (_saving) return;

    final password = await _showPasswordDialog();
    if (password == null || !mounted) return;

    final draft = _service.createSetupDraft();
    final confirmed = await _showRecoveryKeyDialog(draft.recoveryKey);
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _keyStore.saveSecret(
        password: password,
        recoveryKey: draft.recoveryKey,
      );
      await _service.completeSetup(draft);
      final settings = await _service.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('백업 암호화 설정을 완료했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('백업 암호화 설정 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _resetEncryption() async {
    if (_saving) return;

    final confirmed = await _showResetEncryptionDialog();
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _keyStore.deleteSecret();
      await _service.clearSetup();
      final settings = await _service.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('백업 암호화 설정을 초기화했습니다.')),
      );
    } on BackupEncryptionKeyStoreException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _showSimpleErrorDialog(
        context,
        title: '기기 보안 저장소 사용 불가',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _showSimpleErrorDialog(
        context,
        title: '백업 암호화 초기화 실패',
        message: '백업 암호화 설정을 초기화하지 못했습니다.\n\n$e',
      );
    }
  }

  Future<bool?> _showResetEncryptionDialog() {
    var checked = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('백업 암호화 초기화'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이 기기에 저장된 백업 암호화 secret과 복구키 검증 정보를 삭제합니다.',
                ),
                const SizedBox(height: 12),
                Text(
                  '이미 클라우드에 올라간 암호화 백업은 삭제되지 않습니다. '
                  '다만 기존 백업을 복원하려면 그 백업을 만들 때 사용한 비밀번호 또는 복구키가 계속 필요합니다.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '초기화 후에는 새 백업을 만들기 전에 백업 암호를 다시 설정해야 합니다.',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: (value) {
                    setDialogState(() => checked = value ?? false);
                  },
                  title: const Text('기존 암호화 백업 복원에 기존 비밀번호/복구키가 필요함을 이해했습니다'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed:
                  checked ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('초기화'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showPasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('백업 암호 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이 비밀번호는 클라우드 백업 암호화와 복원에 사용합니다. '
                '비밀번호 원문은 저장하지 않고 암호화용 secret만 기기 보안 저장소에 저장합니다.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  border: OutlineInputBorder(),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                final confirm = confirmController.text;
                if (password.length < 8) {
                  setDialogState(() {
                    errorText = '비밀번호는 8자 이상으로 입력해주세요.';
                  });
                  return;
                }
                if (password != confirm) {
                  setDialogState(() {
                    errorText = '비밀번호가 서로 다릅니다.';
                  });
                  return;
                }
                Navigator.of(dialogContext).pop(password);
              },
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      passwordController.dispose();
      confirmController.dispose();
    });
  }

  Future<bool?> _showRecoveryKeyDialog(String recoveryKey) {
    var checked = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('복구키 보관'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '비밀번호를 잊었을 때 이 복구키로 암호화 백업을 복원할 수 있습니다. '
                  '복구키 원문은 앱에 저장하지 않습니다.',
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: SelectableText(
                    recoveryKey,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '이 복구키를 잃어버리면 비밀번호 분실 시 백업 복원이 불가능합니다.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: (value) {
                    setDialogState(() => checked = value ?? false);
                  },
                  title: const Text('복구키를 안전한 곳에 보관했습니다'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed:
                  checked ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('설정 완료'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final configured = settings?.configured ?? false;
    final configuredAt = settings?.configuredAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                      '백업 암호화',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_loading || _saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StorageUsageRow(
                label: '상태',
                value: configured ? '설정 완료' : '설정 안 됨',
              ),
              if (configuredAt != null) ...[
                const SizedBox(height: 8),
                _StorageUsageRow(
                  label: '설정일',
                  value: DateFormat('yyyy-MM-dd HH:mm')
                      .format(configuredAt.toLocal()),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '수동/자동 클라우드 백업은 저장된 암호화 secret으로 .stockbackup 파일만 업로드합니다. '
                '복구키 원문은 저장하지 않고 검증용 hash만 저장합니다. '
                '다른 기기에서 복원할 때는 비밀번호 또는 복구키가 필요합니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.62),
                    ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '백업 암호화 설정을 불러오지 못했습니다.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _loading || _saving ? null : _setupEncryption,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(configured ? '백업 암호 다시 설정' : '백업 암호 설정'),
                  ),
                  if (configured)
                    OutlinedButton.icon(
                      onPressed: _loading || _saving ? null : _resetEncryption,
                      icon: const Icon(Icons.lock_reset_outlined),
                      label: const Text('암호화 초기화'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudBackupSection extends StatefulWidget {
  const _CloudBackupSection();

  @override
  State<_CloudBackupSection> createState() => _CloudBackupSectionState();
}

class _CloudBackupSectionState extends State<_CloudBackupSection> {
  CloudBackupService? _service;
  CloudAutoBackupService? _autoBackupService;
  EntitlementService? _entitlementService;
  AppEntitlement _entitlement = AppEntitlement.signedOut;
  CloudBackupMetadata? _latestBackup;
  CloudAutoBackupSettings _autoSettings = CloudAutoBackupSettings.defaults;
  DateTime? _lastAutoAttemptAt;
  DateTime? _lastAutoSuccessAt;
  Object? _error;
  bool _loading = true;
  bool _uploading = false;
  double? _uploadProgress;
  String _uploadStatusMessage = '';
  bool _savingAutoSettings = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= CloudBackupService(
      authService: context.read<AuthService>(),
    );
    _entitlementService ??= context.read<EntitlementService>();
    _autoBackupService ??= CloudAutoBackupService(
      authService: context.read<AuthService>(),
      cloudBackupService: _service,
      entitlementService: _entitlementService,
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
      final autoService = _autoBackupService;
      final latest = await service.latestReadyBackup();
      final autoSettings =
          await autoService?.loadSettings() ?? CloudAutoBackupSettings.defaults;
      final lastAutoAttemptAt = await autoService?.lastAttemptAt();
      final lastAutoSuccessAt = await autoService?.lastSuccessAt();
      final entitlement = await _entitlementService?.loadEntitlement() ??
          AppEntitlement.signedOut;
      if (!mounted) return;
      setState(() {
        _latestBackup = latest;
        _entitlement = entitlement;
        _autoSettings = autoSettings;
        _lastAutoAttemptAt = lastAutoAttemptAt;
        _lastAutoSuccessAt = lastAutoSuccessAt;
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

  Future<void> _saveAutoSettings(CloudAutoBackupSettings settings) async {
    final service = _autoBackupService;
    if (service == null || _savingAutoSettings) return;

    if (settings.enabled && !_entitlement.canCreateCloudBackup) {
      await _showSimpleErrorDialog(
        context,
        title: 'Cloud Backup 권한 필요',
        message: 'Cloud Backup 체험 또는 구독이 활성화되어야 자동 백업을 켤 수 있습니다.',
      );
      return;
    }

    if (settings.enabled && !await _ensureAutoBackupEncryptionReady()) {
      return;
    }

    setState(() {
      _savingAutoSettings = true;
      _autoSettings = settings;
    });

    try {
      await service.saveSettings(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.enabled
                ? '자동 백업이 켜졌습니다. (${_frequencyLabel(settings.frequency)})'
                : '자동 백업이 꺼졌습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('자동 백업 설정 저장 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingAutoSettings = false);
      }
    }
  }

  Future<bool> _ensureAutoBackupEncryptionReady() async {
    const encryptionSettingsService = BackupEncryptionSettingsService();
    const keyStore = BackupEncryptionKeyStore();
    try {
      final settings = await encryptionSettingsService.load();
      if (!settings.configured) {
        if (!mounted) return false;
        await _showSimpleErrorDialog(
          context,
          title: '백업 암호화 설정 필요',
          message: '자동 클라우드 백업은 암호화된 .stockbackup 파일만 업로드합니다.\n\n'
              '먼저 설정 화면의 백업 암호화를 완료해주세요.',
        );
        return false;
      }

      final hasSecret = await keyStore.hasSecret();
      if (!hasSecret) {
        if (!mounted) return false;
        await _showSimpleErrorDialog(
          context,
          title: '백업 암호화 재설정 필요',
          message: '기기 보안 저장소에서 백업 암호화 secret을 찾지 못했습니다.\n\n'
              '백업 암호화를 다시 설정한 뒤 자동 백업을 켜주세요.',
        );
        return false;
      }
      return true;
    } on BackupEncryptionKeyStoreException catch (e) {
      if (!mounted) return false;
      await _showSimpleErrorDialog(
        context,
        title: '기기 보안 저장소 사용 불가',
        message: e.message,
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      await _showSimpleErrorDialog(
        context,
        title: '백업 암호화 설정 확인 실패',
        message: '자동 백업 암호화 설정을 확인하지 못했습니다.\n\n$e',
      );
      return false;
    }
  }

  Future<void> _uploadNow() async {
    final service = _service;
    if (service == null || _uploading) return;

    if (!_entitlement.canCreateCloudBackup) {
      await _showSimpleErrorDialog(
        context,
        title: 'Cloud Backup 권한 필요',
        message: 'Cloud Backup 체험 또는 구독이 활성화되어야 새 클라우드 백업을 만들 수 있습니다.',
      );
      return;
    }

    final encryptionRequest = await _readManualBackupEncryptionRequest();
    if (encryptionRequest == null || !mounted) return;

    setState(() {
      _uploading = true;
      _uploadProgress = null;
      _uploadStatusMessage = '백업 파일을 준비하고 암호화하는 중입니다. 앱을 종료하지 마세요.';
      _error = null;
    });

    try {
      final result = await service.uploadFullBackup(
        encryption: encryptionRequest,
        onUploadProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = progress.fraction;
            final percent = progress.fraction == null
                ? null
                : (progress.fraction! * 100).clamp(0, 100).round();
            _uploadStatusMessage = percent == null
                ? '클라우드에 백업을 업로드하는 중입니다. 앱을 종료하지 마세요.'
                : '클라우드 백업 진행중입니다. $percent% 완료 - 앱을 종료하지 마세요.';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _latestBackup = result.metadata;
        _uploading = false;
        _uploadProgress = null;
        _uploadStatusMessage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '클라우드 백업 완료 (${StorageUsageService.formatBytes(result.metadata.totalSizeBytes)})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _uploading = false;
        _uploadProgress = null;
        _uploadStatusMessage = '';
      });
      if (e is CloudBackupException) {
        await _showCloudBackupErrorDialog(context, e);
      } else {
        await _showSimpleErrorDialog(
          context,
          title: '클라우드 백업 실패',
          message: '클라우드 백업 중 오류가 발생했습니다.',
        );
      }
    }
  }

  Future<CloudBackupEncryptionRequest?>
      _readManualBackupEncryptionRequest() async {
    const encryptionSettingsService = BackupEncryptionSettingsService();
    const keyStore = BackupEncryptionKeyStore();
    late final BackupEncryptionSettings settings;
    try {
      settings = await encryptionSettingsService.load();
    } catch (e) {
      if (!mounted) return null;
      await _showSimpleErrorDialog(
        context,
        title: '백업 암호화 설정 확인 실패',
        message: '백업 암호화 설정을 확인하지 못했습니다.\n\n$e',
      );
      return null;
    }
    if (!settings.configured) {
      if (!mounted) return null;
      await _showSimpleErrorDialog(
        context,
        title: '백업 암호화 설정 필요',
        message: '클라우드 백업을 만들기 전에 설정 화면의 백업 암호화를 먼저 설정해주세요.',
      );
      return null;
    }

    late final BackupEncryptionStoredSecret? secret;
    try {
      secret = await keyStore.readSecret();
    } on BackupEncryptionKeyStoreException catch (e) {
      if (!mounted) return null;
      await _showSimpleErrorDialog(
        context,
        title: '기기 보안 저장소 사용 불가',
        message: e.message,
      );
      return null;
    } catch (e) {
      if (!mounted) return null;
      await _showSimpleErrorDialog(
        context,
        title: '백업 암호화 secret 확인 실패',
        message: '기기 보안 저장소에서 백업 암호화 secret을 읽지 못했습니다.\n\n$e',
      );
      return null;
    }
    if (secret == null) {
      if (!mounted) return null;
      await _showSimpleErrorDialog(
        context,
        title: '백업 암호화 재설정 필요',
        message: '기기 보안 저장소에서 백업 암호화 secret을 찾지 못했습니다.\n\n'
            '백업 암호화를 다시 설정한 뒤 클라우드 백업을 시도해주세요.',
      );
      return null;
    }

    return CloudBackupEncryptionRequest(
      passwordSecret: secret.passwordSecret,
      recoverySecret: secret.recoverySecret,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.uid;
    final latestBackup = _latestBackup;
    final canCreateCloudBackup = _entitlement.canCreateCloudBackup;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                      '클라우드 백업',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_loading || _uploading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StorageUsageRow(
                label: '로그인',
                value: uid == null ? '필요' : '완료',
              ),
              const SizedBox(height: 8),
              _StorageUsageRow(
                label: 'Cloud Backup 권한',
                value: canCreateCloudBackup ? '사용 가능' : '구독/체험 필요',
              ),
              const SizedBox(height: 8),
              _StorageUsageRow(
                label: '마지막 백업',
                value: latestBackup == null
                    ? '없음'
                    : DateFormat('yyyy-MM-dd HH:mm')
                        .format(latestBackup.createdAt.toLocal()),
              ),
              if (latestBackup != null) ...[
                const SizedBox(height: 8),
                _StorageUsageRow(
                  label: '백업 크기',
                  value: StorageUsageService.formatBytes(
                      latestBackup.totalSizeBytes),
                ),
              ],
              const SizedBox(height: 8),
              _StorageUsageRow(
                label: '자동 백업',
                value: _autoSettings.enabled
                    ? '${_frequencyLabel(_autoSettings.frequency)} / 켜짐'
                    : '꺼짐',
              ),
              const SizedBox(height: 8),
              _StorageUsageRow(
                label: '자동 백업 성공',
                value: _lastAutoSuccessAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm')
                        .format(_lastAutoSuccessAt!.toLocal()),
              ),
              const SizedBox(height: 8),
              _StorageUsageRow(
                label: '자동 백업 시도',
                value: _lastAutoAttemptAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm')
                        .format(_lastAutoAttemptAt!.toLocal()),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('자동 백업 사용'),
                subtitle: const Text('앱 실행 시와 앱이 다시 활성화될 때 자동 백업 여부를 확인합니다.'),
                value: _autoSettings.enabled,
                onChanged:
                    uid == null || _savingAutoSettings || !canCreateCloudBackup
                        ? null
                        : (value) => _saveAutoSettings(
                              CloudAutoBackupSettings(
                                enabled: value ?? false,
                                frequency: _autoSettings.frequency,
                              ),
                            ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<CloudAutoBackupFrequency>(
                value: _autoSettings.frequency,
                decoration: const InputDecoration(
                  labelText: '자동 백업 주기',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: CloudAutoBackupFrequency.values
                    .map(
                      (frequency) => DropdownMenuItem(
                        value: frequency,
                        child: Text(_frequencyLabel(frequency)),
                      ),
                    )
                    .toList(),
                onChanged:
                    uid == null || _savingAutoSettings || !canCreateCloudBackup
                        ? null
                        : (frequency) {
                            if (frequency == null) return;
                            _saveAutoSettings(
                              CloudAutoBackupSettings(
                                enabled: _autoSettings.enabled,
                                frequency: frequency,
                              ),
                            );
                          },
              ),
              const SizedBox(height: 8),
              Text(
                '매일: 마지막 성공 백업 후 24시간이 지났을 때\n'
                '매주: 마지막 성공 백업 후 7일이 지났을 때\n'
                '매달: 마지막 성공 백업 후 30일이 지났을 때\n'
                '단, 이전 백업과 내용이 같으면 새 백업을 만들지 않습니다. '
                '자동 백업은 암호화된 .stockbackup으로 업로드되며, '
                '시도 후 최소 12시간 동안은 다시 시도하지 않습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.62),
                    ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '클라우드 백업 정보를 불러오지 못했습니다.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_uploading) ...[
                const SizedBox(height: 12),
                _CloudBackupProgressNotice(
                  progress: _uploadProgress,
                  message: _uploadStatusMessage,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed:
                        uid == null || _uploading || !canCreateCloudBackup
                            ? null
                            : _uploadNow,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('지금 클라우드 백업하기'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || _uploading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('새로고침'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => Navigator.of(context)
                            .pushNamed('/settings/cloud-backups'),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('백업 목록 보기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _frequencyLabel(CloudAutoBackupFrequency frequency) {
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

class _CloudBackupProgressNotice extends StatelessWidget {
  final double? progress;
  final String message;

  const _CloudBackupProgressNotice({
    required this.progress,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent =
        progress == null ? null : '${(progress! * 100).clamp(0, 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message.isEmpty ? '백업 진행중입니다. 앱을 종료하지 마세요.' : message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (percent != null) ...[
                const SizedBox(width: 8),
                Text(
                  percent,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
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
