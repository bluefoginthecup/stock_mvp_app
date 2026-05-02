import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPathService {
  static const purchaseReceiptsRelativeRoot = 'purchase_receipts';

  const AppPathService();

  Future<Directory> appSupportDirectory() {
    return getApplicationSupportDirectory();
  }

  Future<File> stockDatabaseFile() async {
    final dir = await appSupportDirectory();
    return File(p.join(dir.path, 'stockapp.db'));
  }

  Future<Directory> purchaseReceiptsRoot() async {
    final dir = await appSupportDirectory();
    return Directory(p.join(dir.path, purchaseReceiptsRelativeRoot));
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

  Future<File> resolveAppFile(String storedPath) async {
    if (p.isAbsolute(storedPath)) return File(storedPath);

    final dir = await appSupportDirectory();
    return File(p.joinAll([dir.path, ...p.posix.split(storedPath)]));
  }

  Future<String> normalizeToRelativePath(String absoluteOrRelativePath) async {
    if (!p.isAbsolute(absoluteOrRelativePath)) {
      return _normalizeRelativePath(absoluteOrRelativePath);
    }

    final dir = await appSupportDirectory();
    if (p.equals(absoluteOrRelativePath, dir.path) ||
        p.isWithin(dir.path, absoluteOrRelativePath)) {
      return _normalizeRelativePath(
        p.relative(absoluteOrRelativePath, from: dir.path),
      );
    }

    final parts = p.split(absoluteOrRelativePath);
    final receiptsIndex = parts.lastIndexOf(purchaseReceiptsRelativeRoot);
    if (receiptsIndex >= 0 && receiptsIndex < parts.length - 1) {
      return p.posix.joinAll(parts.skip(receiptsIndex));
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

  Future<File?> _findFileByName(Directory dir, String fileName) async {
    if (!await dir.exists()) return null;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == fileName) {
        return entity;
      }
    }

    return null;
  }
}
