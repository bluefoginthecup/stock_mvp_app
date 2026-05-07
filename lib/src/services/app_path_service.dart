import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPathService {
  static const purchaseReceiptsRelativeRoot = 'purchase_receipts';
  static const scheduleAttachmentsRelativeRoot = 'schedule_attachments';
  static String? _activeUserId;

  const AppPathService();

  static void setActiveUserId(String? userId) {
    _activeUserId = userId == null || userId.trim().isEmpty
        ? null
        : _sanitizeUserPathSegment(userId);
  }

  Future<Directory> appSupportDirectory() {
    return getApplicationSupportDirectory();
  }

  Future<File> stockDatabaseFile() async {
    final dir = await userSupportDirectory();
    return File(p.join(dir.path, 'stockapp.db'));
  }

  Future<File> legacyStockDatabaseFile() async {
    final dir = await appSupportDirectory();
    return File(p.join(dir.path, 'stockapp.db'));
  }

  Future<Directory> userSupportDirectory() async {
    final dir = await appSupportDirectory();
    final userId = _activeUserId;
    if (userId == null) return dir;
    return Directory(p.join(dir.path, 'users', userId));
  }

  Future<void> migrateLegacyDatabaseToActiveUserIfNeeded() async {
    final userId = _activeUserId;
    if (userId == null) return;

    final legacyFile = await legacyStockDatabaseFile();
    if (!await legacyFile.exists()) return;

    final userDbFile = await stockDatabaseFile();
    if (await userDbFile.exists()) return;

    final userDir = userDbFile.parent;
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }

    await legacyFile.copy(userDbFile.path);

    final preservedDir =
        Directory(p.join((await appSupportDirectory()).path, 'legacy_db'));
    if (!await preservedDir.exists()) {
      await preservedDir.create(recursive: true);
    }
    final preservedFile = File(p.join(
      preservedDir.path,
      'stockapp_legacy_migrated_to_$userId.db',
    ));
    if (!await preservedFile.exists()) {
      await legacyFile.copy(preservedFile.path);
    }

    final retiredLegacyFile = File(p.join(
      preservedDir.path,
      'stockapp_legacy_original.db',
    ));
    if (!await retiredLegacyFile.exists()) {
      await legacyFile.rename(retiredLegacyFile.path);
    } else {
      await legacyFile.delete();
    }

    final legacyReceiptsRoot = Directory(
      p.join((await appSupportDirectory()).path, purchaseReceiptsRelativeRoot),
    );
    final userReceiptsRoot = await purchaseReceiptsRoot();
    if (await legacyReceiptsRoot.exists() && !await userReceiptsRoot.exists()) {
      await _copyDirectory(legacyReceiptsRoot, userReceiptsRoot);
    }
  }

  Future<Directory> purchaseReceiptsRoot() async {
    final dir = await userSupportDirectory();
    return Directory(p.join(dir.path, purchaseReceiptsRelativeRoot));
  }

  Future<Directory> scheduleAttachmentsRoot() async {
    final dir = await userSupportDirectory();
    return Directory(p.join(dir.path, scheduleAttachmentsRelativeRoot));
  }

  Future<Directory> purchaseReceiptOrderDirectory(
      String purchaseOrderId) async {
    final root = await purchaseReceiptsRoot();
    return Directory(p.join(root.path, purchaseOrderId));
  }

  String purchaseReceiptRelativePath(
    String purchaseOrderId,
    String fileName,
  ) {
    return p.posix.join(
      purchaseReceiptsRelativeRoot,
      purchaseOrderId,
      fileName,
    );
  }

  Future<Directory> scheduleAttachmentDirectory(String scheduleId) async {
    final root = await scheduleAttachmentsRoot();
    return Directory(p.join(root.path, scheduleId));
  }

  String scheduleAttachmentRelativePath(
    String scheduleId,
    String fileName,
  ) {
    return p.posix.join(
      scheduleAttachmentsRelativeRoot,
      scheduleId,
      fileName,
    );
  }

  Future<File> resolveAppFile(String storedPath) async {
    final dir = await userSupportDirectory();
    if (p.isAbsolute(storedPath)) {
      if (p.equals(storedPath, dir.path) || p.isWithin(dir.path, storedPath)) {
        return File(storedPath);
      }

      final parts = p.split(storedPath);
      final receiptsIndex = parts.lastIndexOf(purchaseReceiptsRelativeRoot);
      if (receiptsIndex >= 0 && receiptsIndex < parts.length - 1) {
        return File(p.joinAll([
          dir.path,
          ...parts.skip(receiptsIndex),
        ]));
      }

      final scheduleAttachmentsIndex =
          parts.lastIndexOf(scheduleAttachmentsRelativeRoot);
      if (scheduleAttachmentsIndex >= 0 &&
          scheduleAttachmentsIndex < parts.length - 1) {
        return File(p.joinAll([
          dir.path,
          ...parts.skip(scheduleAttachmentsIndex),
        ]));
      }

      return File(storedPath);
    }

    return File(p.joinAll([dir.path, ...p.posix.split(storedPath)]));
  }

  Future<String> normalizeToRelativePath(String absoluteOrRelativePath) async {
    if (!p.isAbsolute(absoluteOrRelativePath)) {
      return _normalizeRelativePath(absoluteOrRelativePath);
    }

    final userDir = await userSupportDirectory();
    if (p.equals(absoluteOrRelativePath, userDir.path) ||
        p.isWithin(userDir.path, absoluteOrRelativePath)) {
      return _normalizeRelativePath(
        p.relative(absoluteOrRelativePath, from: userDir.path),
      );
    }

    final parts = p.split(absoluteOrRelativePath);
    final receiptsIndex = parts.lastIndexOf(purchaseReceiptsRelativeRoot);
    if (receiptsIndex >= 0 && receiptsIndex < parts.length - 1) {
      return p.posix.joinAll(parts.skip(receiptsIndex));
    }

    final scheduleAttachmentsIndex =
        parts.lastIndexOf(scheduleAttachmentsRelativeRoot);
    if (scheduleAttachmentsIndex >= 0 &&
        scheduleAttachmentsIndex < parts.length - 1) {
      return p.posix.joinAll(parts.skip(scheduleAttachmentsIndex));
    }

    return absoluteOrRelativePath;
  }

  Future<File?> resolveExistingPurchaseReceiptFile({
    required String purchaseOrderId,
    required String storedPath,
  }) async {
    final direct = await resolveAppFile(storedPath);
    if (await direct.exists()) return direct;

    final root = await purchaseReceiptsRoot();
    final fileName = p.basename(storedPath);
    final candidates = <String>{
      p.join(root.path, purchaseOrderId, fileName),
    };

    final parts = p.split(storedPath);
    final receiptsIndex = parts.lastIndexOf(purchaseReceiptsRelativeRoot);
    if (receiptsIndex >= 0 && receiptsIndex < parts.length - 1) {
      candidates.add(
        p.joinAll([
          root.path,
          ...parts.skip(receiptsIndex + 1),
        ]),
      );
    }

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) return file;
    }

    final orderDir = await purchaseReceiptOrderDirectory(purchaseOrderId);
    final foundInOrder = await _findFileByName(orderDir, fileName);
    if (foundInOrder != null) return foundInOrder;

    return _findFileByName(root, fileName);
  }

  String _normalizeRelativePath(String relativePath) {
    final parts = relativePath
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty && part != '.');
    return p.posix.normalize(p.posix.joinAll(parts));
  }

  static String _sanitizeUserPathSegment(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  Future<File?> _findFileByName(Directory dir, String fileName) async {
    if (!await dir.exists()) return null;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == fileName) {
        return entity;
      }
    }

    return null;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: source.path);
      final targetPath = p.join(destination.path, relative);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(p.dirname(targetPath)).create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }
}
