import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class BackupFileHash {
  final String relativePath;
  final int sizeBytes;
  final String sha256;

  const BackupFileHash({
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256,
  });

  Map<String, Object?> toJson() {
    return {
      'relativePath': relativePath,
      'sizeBytes': sizeBytes,
      'sha256': sha256,
    };
  }
}

class BackupHashService {
  const BackupHashService();

  Future<BackupFileHash> hashFile({
    required File file,
    required String relativePath,
  }) async {
    final stat = await file.stat();
    final digest = await sha256.bind(file.openRead()).first;
    return BackupFileHash(
      relativePath: relativePath,
      sizeBytes: stat.size,
      sha256: digest.toString(),
    );
  }

  Future<List<BackupFileHash>> hashDirectoryFiles({
    required Directory root,
    required String relativeRoot,
  }) async {
    if (!await root.exists()) return const [];

    final hashes = <BackupFileHash>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final relativeFromRoot = p.relative(entity.path, from: root.path);
      final relativePath = p.posix.joinAll([
        relativeRoot,
        ...p.split(relativeFromRoot),
      ]);
      hashes.add(
        await hashFile(file: entity, relativePath: relativePath),
      );
    }

    hashes.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return hashes;
  }
}
