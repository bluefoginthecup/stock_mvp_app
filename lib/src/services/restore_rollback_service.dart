import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_path_service.dart';

class RestoreRollbackInfo {
  final String path;
  final DateTime modifiedAt;
  final int bytes;
  final int fileCount;

  const RestoreRollbackInfo({
    required this.path,
    required this.modifiedAt,
    required this.bytes,
    required this.fileCount,
  });
}

class RestoreRollbackSummary {
  final List<RestoreRollbackInfo> rollbacks;

  const RestoreRollbackSummary({required this.rollbacks});

  int get count => rollbacks.length;
  int get totalBytes => rollbacks.fold(0, (sum, item) => sum + item.bytes);
  int get totalFileCount =>
      rollbacks.fold(0, (sum, item) => sum + item.fileCount);
}

class RestoreRollbackCleanupResult {
  final int deletedCount;
  final int deletedBytes;

  const RestoreRollbackCleanupResult({
    required this.deletedCount,
    required this.deletedBytes,
  });
}

class RestoreRollbackService {
  static const rollbackPrefix = 'full_restore_rollback_';

  const RestoreRollbackService({
    this.paths = const AppPathService(),
  });

  final AppPathService paths;

  Future<RestoreRollbackSummary> calculateUsage() async {
    final rollbacks = await _listRollbacks();
    return RestoreRollbackSummary(rollbacks: rollbacks);
  }

  Future<RestoreRollbackCleanupResult> cleanupOldRollbacks({
    int keepRecent = 3,
    Duration maxAge = const Duration(days: 30),
  }) async {
    final rollbacks = await _listRollbacks();
    final now = DateTime.now();
    var deletedCount = 0;
    var deletedBytes = 0;

    for (var index = 0; index < rollbacks.length; index += 1) {
      final rollback = rollbacks[index];
      final shouldDelete =
          index >= keepRecent || now.difference(rollback.modifiedAt) > maxAge;
      if (!shouldDelete) continue;

      final dir = Directory(rollback.path);
      if (!await dir.exists()) continue;

      deletedBytes += rollback.bytes;
      await dir.delete(recursive: true);
      deletedCount += 1;
    }

    return RestoreRollbackCleanupResult(
      deletedCount: deletedCount,
      deletedBytes: deletedBytes,
    );
  }

  Future<List<RestoreRollbackInfo>> _listRollbacks() async {
    final appSupportDir = await paths.appSupportDirectory();
    if (!await appSupportDir.exists()) return const [];

    final rollbacks = <RestoreRollbackInfo>[];
    await for (final entity
        in appSupportDir.list(recursive: false, followLinks: false)) {
      if (entity is! Directory) continue;
      if (!p.basename(entity.path).startsWith(rollbackPrefix)) continue;

      final stat = await entity.stat();
      final usage = await _directoryUsage(entity);
      rollbacks.add(
        RestoreRollbackInfo(
          path: entity.path,
          modifiedAt: stat.modified,
          bytes: usage.bytes,
          fileCount: usage.fileCount,
        ),
      );
    }

    rollbacks.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return rollbacks;
  }

  Future<_DirectoryUsage> _directoryUsage(Directory directory) async {
    var bytes = 0;
    var fileCount = 0;

    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      try {
        final stat = await entity.stat();
        bytes += stat.size;
        fileCount += 1;
      } catch (_) {
        // 정리 대상 후보 하나가 읽히지 않아도 전체 화면/정리 흐름은 유지한다.
      }
    }

    return _DirectoryUsage(bytes: bytes, fileCount: fileCount);
  }
}

class _DirectoryUsage {
  final int bytes;
  final int fileCount;

  const _DirectoryUsage({
    required this.bytes,
    required this.fileCount,
  });
}
