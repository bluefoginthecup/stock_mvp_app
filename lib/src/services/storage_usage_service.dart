import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_path_service.dart';

class StorageUsageFolderSpec {
  final String id;
  final String label;
  final List<String> relativeSegments;

  const StorageUsageFolderSpec({
    required this.id,
    required this.label,
    required this.relativeSegments,
  });
}

class StorageFolderUsage {
  final String id;
  final String label;
  final String path;
  final int bytes;
  final int fileCount;

  const StorageFolderUsage({
    required this.id,
    required this.label,
    required this.path,
    required this.bytes,
    required this.fileCount,
  });
}

class StorageUsageSummary {
  final List<StorageFolderUsage> folders;

  const StorageUsageSummary({required this.folders});

  int get totalBytes => folders.fold(0, (sum, item) => sum + item.bytes);

  int get totalFileCount =>
      folders.fold(0, (sum, item) => sum + item.fileCount);
}

class StorageUsageService {
  static const purchaseReceipts = StorageUsageFolderSpec(
    id: 'purchase_receipts',
    label: '영수증/거래명세서',
    relativeSegments: [AppPathService.purchaseReceiptsRelativeRoot],
  );

  static const scheduleAttachments = StorageUsageFolderSpec(
    id: 'schedule_attachments',
    label: '일정 첨부 이미지',
    relativeSegments: [AppPathService.scheduleAttachmentsRelativeRoot],
  );

  const StorageUsageService({
    this.folders = const [purchaseReceipts, scheduleAttachments],
    this.paths = const AppPathService(),
  });

  final List<StorageUsageFolderSpec> folders;
  final AppPathService paths;

  Future<StorageUsageSummary> calculate() async {
    final baseDir = await paths.userSupportDirectory();
    final usages = <StorageFolderUsage>[];

    for (final folder in folders) {
      final folderPath = p.joinAll([baseDir.path, ...folder.relativeSegments]);
      final usage = await _calculateFolder(folder, folderPath);
      usages.add(usage);
    }

    return StorageUsageSummary(folders: usages);
  }

  Future<StorageFolderUsage> _calculateFolder(
    StorageUsageFolderSpec spec,
    String folderPath,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      return StorageFolderUsage(
        id: spec.id,
        label: spec.label,
        path: folderPath,
        bytes: 0,
        fileCount: 0,
      );
    }

    var bytes = 0;
    var fileCount = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      try {
        final stat = await entity.stat();
        bytes += stat.size;
        fileCount += 1;
      } catch (_) {
        // 접근할 수 없는 파일 하나 때문에 전체 집계를 실패시키지 않는다.
      }
    }

    return StorageFolderUsage(
      id: spec.id,
      label: spec.label,
      path: folderPath,
      bytes: bytes,
      fileCount: fileCount,
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';

    final mb = bytes / (1024 * 1024);
    if (mb < 0.1) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }

    return '${mb.toStringAsFixed(1)} MB';
  }
}
