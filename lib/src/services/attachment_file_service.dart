import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class StoredAttachmentFile {
  final String fileName;
  final String filePath;
  final String mimeType;

  const StoredAttachmentFile({
    required this.fileName,
    required this.filePath,
    required this.mimeType,
  });
}

class AttachmentFileService {
  const AttachmentFileService();

  static const _uuid = Uuid();

  Future<StoredAttachmentFile> copyOptimizedImage({
    required String sourcePath,
    required String originalFileName,
    required Directory destinationDirectory,
    int maxLongSide = 1600,
    int jpgQuality = 75,
  }) async {
    if (!await destinationDirectory.exists()) {
      await destinationDirectory.create(recursive: true);
    }

    final safeName = _safeFileName(originalFileName, fallback: 'image');
    final baseName = p.basenameWithoutExtension(safeName);
    final destName =
        '${DateTime.now().microsecondsSinceEpoch}_${_uuid.v4()}_$baseName.jpg';
    final destPath = p.join(destinationDirectory.path, destName);

    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) {
        throw const FormatException('Unsupported image format');
      }

      final oriented = img.bakeOrientation(decoded);
      final longSide =
          oriented.width > oriented.height ? oriented.width : oriented.height;
      final resized = longSide > maxLongSide
          ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? maxLongSide : null,
              height: oriented.height > oriented.width ? maxLongSide : null,
              interpolation: img.Interpolation.average,
            )
          : oriented;

      final jpgBytes = img.encodeJpg(resized, quality: jpgQuality);
      await File(destPath).writeAsBytes(jpgBytes, flush: true);

      return StoredAttachmentFile(
        fileName: '$baseName.jpg',
        filePath: destPath,
        mimeType: 'image/jpeg',
      );
    } catch (_) {
      return copyOriginalFile(
        sourcePath: sourcePath,
        originalFileName: safeName,
        destinationDirectory: destinationDirectory,
        mimeType: _mimeFor(safeName),
      );
    }
  }

  Future<StoredAttachmentFile> copyOriginalFile({
    required String sourcePath,
    required String originalFileName,
    required Directory destinationDirectory,
    String? mimeType,
  }) async {
    if (!await destinationDirectory.exists()) {
      await destinationDirectory.create(recursive: true);
    }

    final safeName = _safeFileName(originalFileName, fallback: 'attachment');
    final destName =
        '${DateTime.now().microsecondsSinceEpoch}_${_uuid.v4()}_$safeName';
    final destPath = p.join(destinationDirectory.path, destName);
    await File(sourcePath).copy(destPath);

    return StoredAttachmentFile(
      fileName: safeName,
      filePath: destPath,
      mimeType: mimeType ?? _mimeFor(safeName),
    );
  }

  String _safeFileName(String name, {required String fallback}) {
    final trimmed = name.trim().isEmpty ? fallback : name.trim();
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _mimeFor(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.heic':
        return 'image/heic';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
