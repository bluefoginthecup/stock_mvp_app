import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DrMdbImportException implements Exception {
  const DrMdbImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DrMdbImportPreview {
  const DrMdbImportPreview({
    required this.items,
    required this.suppliers,
    required this.purchaseOrders,
    required this.purchaseLines,
    required this.missingItemJoins,
    required this.missingSupplierJoins,
  });

  final int items;
  final int suppliers;
  final int purchaseOrders;
  final int purchaseLines;
  final int missingItemJoins;
  final int missingSupplierJoins;
}

class DrMdbImportResult {
  const DrMdbImportResult({
    required this.items,
    required this.suppliers,
    required this.purchaseOrders,
    required this.purchaseLines,
  });

  final int items;
  final int suppliers;
  final int purchaseOrders;
  final int purchaseLines;
}

class DrExistingSupplierMatch {
  const DrExistingSupplierMatch({required this.id, required this.name});
  final String id;
  final String name;
}

class DrSupplierDuplicateCandidate {
  const DrSupplierDuplicateCandidate({
    required this.importedId,
    required this.importedName,
    required this.matches,
  });
  final String importedId;
  final String importedName;
  final List<DrExistingSupplierMatch> matches;
}

class DrMdbZipImportService {
  DrMdbZipImportService(this.db);

  final AppDatabase db;

  Future<DrMdbImportPreview> preview(File zipFile) async {
    final package = await _readPackage(zipFile);
    return package.preview;
  }

  Future<List<DrSupplierDuplicateCandidate>> duplicateSupplierCandidates(
      File zipFile) async {
    final package = await _readPackage(zipFile);
    final existingRows = await (db.select(db.suppliers)
          ..where((table) => table.id.like('dr_supplier_%').not()))
        .get();
    final byName = <String, List<DrExistingSupplierMatch>>{};
    for (final supplier in existingRows) {
      final key = _normalizedName(supplier.name);
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(
            DrExistingSupplierMatch(id: supplier.id, name: supplier.name),
          );
    }
    return package.suppliers
        .map((row) {
          final importedName = _text(row['name']);
          final matches = byName[_normalizedName(importedName)] ?? const [];
          return DrSupplierDuplicateCandidate(
            importedId: _required(row, 'supplier_id'),
            importedName: importedName,
            matches: matches,
          );
        })
        .where((candidate) => candidate.matches.isNotEmpty)
        .toList();
  }

  Future<DrMdbImportResult> import(
    File zipFile, {
    Map<String, String> supplierMappings = const {},
  }) async {
    final package = await _readPackage(zipFile);
    const rootFolderId = 'dr_folder_root';
    const subfolderId = 'dr_folder_balju';
    final now = DateTime.now().toIso8601String();
    final mappedSupplierNames = <String, String>{};
    for (final targetId in supplierMappings.values.toSet()) {
      final target = await (db.select(db.suppliers)
            ..where((table) => table.id.equals(targetId)))
          .getSingleOrNull();
      if (target == null) {
        throw DrMdbImportException('연결할 기존 거래처를 찾을 수 없습니다: $targetId');
      }
      mappedSupplierNames[targetId] = target.name;
    }

    await db.transaction(() async {
      await db.into(db.folders).insertOnConflictUpdate(
            FoldersCompanion.insert(
              id: rootFolderId,
              name: '경영박사',
              depth: 1,
              order: const Value(9000),
              searchNormalized: const Value('경영박사'),
              searchInitials: const Value('ㄱㅇㅂㅅ'),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
              extra: Value(jsonEncode({'source': 'drmdb'})),
            ),
          );
      await db.into(db.folders).insertOnConflictUpdate(
            FoldersCompanion.insert(
              id: subfolderId,
              name: '발주이관',
              parentId: const Value(rootFolderId),
              depth: 2,
              searchNormalized: const Value('발주이관'),
              searchInitials: const Value('ㅂㅈㅇㄱ'),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
              extra: Value(jsonEncode({'source': 'drmdb'})),
            ),
          );

      for (final row in package.suppliers) {
        final id = _required(row, 'supplier_id');
        if (supplierMappings.containsKey(id)) continue;
        final memoParts = [
          row['memo'],
          if (_text(row['fax']).isNotEmpty) '팩스: ${row['fax']}'
        ].map(_text).where((value) => value.isNotEmpty).join('\n');
        await db.into(db.suppliers).insertOnConflictUpdate(
              SuppliersCompanion.insert(
                id: id,
                name: _fallback(row['name'], '경영박사 거래처 ${row['legacy_code']}'),
                contactName: Value(_nullable(row['contact_name'])),
                phone: Value(_nullable(row['phone'])),
                addr: Value(_nullable(row['address'])),
                memo: Value(_nullable(memoParts)),
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      for (final row in package.items) {
        final id = _required(row, 'item_id');
        final name = _fallback(row['name'], '경영박사 품목 ${row['legacy_code']}');
        final displayName = _fallback(row['display_name'], name);
        final sourceSupplierId = _nullable(row['supplier_id']);
        final targetSupplierId = sourceSupplierId == null
            ? null
            : supplierMappings[sourceSupplierId] ?? sourceSupplierId;
        final targetSupplierName = targetSupplierId == null
            ? _nullable(row['supplier_name'])
            : mappedSupplierNames[targetSupplierId] ??
                _nullable(row['supplier_name']);
        final attrs = <String, Object?>{
          'source': 'drmdb',
          'legacyCode': row['legacy_code'],
          if (_text(row['spec']).isNotEmpty) '규격': row['spec'],
          if (_text(row['memo']).isNotEmpty) '비고': row['memo'],
          if (_text(row['memo2']).isNotEmpty) '비고2': row['memo2'],
        };
        final itemValues = ItemsCompanion(
          name: Value(name),
          displayName: Value(displayName),
          sku:
              Value(_fallback(row['legacy_code2'], 'DR-${row['legacy_code']}')),
          unit: Value(_fallback(row['unit'], 'EA')),
          searchNormalized: Value(displayName),
          searchFullNormalized: Value(displayName),
          folder: const Value('경영박사'),
          subfolder: const Value('발주이관'),
          kind: const Value('raw'),
          attrsJson: Value(jsonEncode(attrs)),
          unitIn: Value(_fallback(row['unit'], 'EA')),
          unitOut: Value(_fallback(row['unit'], 'EA')),
          supplierName: Value(targetSupplierName),
          defaultSupplierUid: Value(targetSupplierId),
          defaultPrice: Value(_doubleOrNull(row['default_purchase_price'])),
          defaultPurchasePrice:
              Value(_doubleOrNull(row['default_purchase_price'])),
          defaultSalePrice: Value(_doubleOrNull(row['default_sale_price'])),
          isDeleted: const Value(false),
          deletedAt: const Value(null),
          extra: Value(jsonEncode(
              {'source': 'drmdb', 'legacyCode': row['legacy_code']})),
        );
        final existingItem = await (db.select(db.items)
              ..where((table) => table.id.equals(id)))
            .getSingleOrNull();
        if (existingItem == null) {
          await db.into(db.items).insert(
                ItemsCompanion.insert(
                  id: id,
                  name: name,
                  displayName: Value(displayName),
                  sku: _fallback(
                      row['legacy_code2'], 'DR-${row['legacy_code']}'),
                  unit: _fallback(row['unit'], 'EA'),
                  searchNormalized: Value(displayName),
                  searchFullNormalized: Value(displayName),
                  folder: '경영박사',
                  subfolder: const Value('발주이관'),
                  minQty: const Value(0),
                  qty: const Value(0),
                  kind: const Value('raw'),
                  attrsJson: Value(jsonEncode(attrs)),
                  unitIn: Value(_fallback(row['unit'], 'EA')),
                  unitOut: Value(_fallback(row['unit'], 'EA')),
                  supplierName: Value(targetSupplierName),
                  defaultSupplierUid: Value(targetSupplierId),
                  defaultPrice:
                      Value(_doubleOrNull(row['default_purchase_price'])),
                  defaultPurchasePrice:
                      Value(_doubleOrNull(row['default_purchase_price'])),
                  defaultSalePrice:
                      Value(_doubleOrNull(row['default_sale_price'])),
                  isDeleted: const Value(false),
                  deletedAt: const Value(null),
                  extra: Value(jsonEncode(
                      {'source': 'drmdb', 'legacyCode': row['legacy_code']})),
                ),
              );
        } else {
          await (db.update(db.items)..where((table) => table.id.equals(id)))
              .write(itemValues);
        }
        await db.into(db.itemPaths).insertOnConflictUpdate(
              ItemPathsCompanion.insert(
                itemId: id,
                l1Id: const Value(rootFolderId),
                l2Id: const Value(subfolderId),
              ),
            );
      }

      for (final row in package.purchaseOrders) {
        final id = _required(row, 'purchase_order_id');
        final createdAt = _isoDate(row['order_date'], now);
        final sourceSupplierId = _nullable(row['supplier_id']);
        final targetSupplierId = sourceSupplierId == null
            ? null
            : supplierMappings[sourceSupplierId] ?? sourceSupplierId;
        final targetSupplierName = targetSupplierId == null
            ? _fallback(row['supplier_name'], '경영박사 거래처')
            : mappedSupplierNames[targetSupplierId] ??
                _fallback(row['supplier_name'], '경영박사 거래처');
        await db.into(db.purchaseOrders).insertOnConflictUpdate(
              PurchaseOrdersCompanion.insert(
                id: id,
                supplierName: targetSupplierName,
                supplierId: Value(targetSupplierId),
                paymentStatus: const Value('unpaid'),
                vatInvoiceStatus: const Value('pending'),
                vatIncluded: const Value(false),
                vatType: const Value(2),
                eta: _isoDate(row['eta'], createdAt),
                status: 'received',
                createdAt: createdAt,
                updatedAt: now,
                isDeleted: const Value(false),
                memo: Value(_nullable(row['memo'])),
                deletedAt: const Value(null),
                receivedAt: Value(_nullableIsoDate(row['received_at'])),
              ),
            );
      }

      for (final row in package.purchaseLines) {
        final id = _required(row, 'purchase_line_id');
        await db.into(db.purchaseLines).insertOnConflictUpdate(
              PurchaseLinesCompanion.insert(
                id: id,
                orderId: _required(row, 'purchase_order_id'),
                itemId: _required(row, 'item_id'),
                name: _fallback(row['name'], '경영박사 품목'),
                unit: _fallback(row['unit'], 'EA'),
                qty: _asDouble(row['qty']),
                unitPrice: Value(_asDouble(row['unit_price'])),
                vatType: const Value(2),
                supplyAmount: Value(_asDouble(row['supply_amount'])),
                vatAmount: Value(_asDouble(row['vat_amount'])),
                totalAmount: Value(_asDouble(row['total_amount'])),
                amountEdited: const Value(true),
                note: Value(_nullable(row['purchase_no'])),
                memo: Value(_nullable(row['memo'])),
                isDeleted: const Value(false),
                deletedAt: const Value(null),
              ),
            );
      }
    });

    return DrMdbImportResult(
      items: package.items.length,
      suppliers: package.suppliers.length,
      purchaseOrders: package.purchaseOrders.length,
      purchaseLines: package.purchaseLines.length,
    );
  }

  Future<_DrPackage> _readPackage(File file) async {
    if (!await file.exists()) {
      throw const DrMdbImportException('선택한 ZIP 파일을 찾을 수 없습니다.');
    }
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (_) {
      throw const DrMdbImportException('올바른 ZIP 파일이 아닙니다.');
    }
    final entries = <String, ArchiveFile>{
      for (final entry in archive.files.where((entry) => entry.isFile))
        entry.name.replaceAll('\\', '/'): entry,
    };
    final manifestEntry = entries['manifest.json'];
    if (manifestEntry == null) {
      throw const DrMdbImportException('manifest.json이 없는 경영박사 ZIP입니다.');
    }
    final manifest = jsonDecode(_entryText(manifestEntry));
    if (manifest is! Map ||
        manifest['format'] != 'chalstock.dr_mdb.v1' ||
        manifest['formatVersion'] != 1) {
      throw const DrMdbImportException('지원하지 않는 경영박사 ZIP 형식입니다.');
    }
    final items = _csv(entries, 'items.csv');
    final suppliers = _csv(entries, 'suppliers.csv');
    final orders = _csv(entries, 'purchase_orders.csv');
    final lines = _csv(entries, 'purchase_lines.csv');
    final counts =
        manifest['counts'] is Map ? manifest['counts'] as Map : const {};
    if (_manifestCount(counts, 'items') != items.length ||
        _manifestCount(counts, 'suppliers') != suppliers.length ||
        _manifestCount(counts, 'purchaseOrders') != orders.length ||
        _manifestCount(counts, 'purchaseLines') != lines.length) {
      throw const DrMdbImportException('manifest의 건수와 CSV 데이터 건수가 일치하지 않습니다.');
    }
    final validation = manifest['validation'] is Map
        ? manifest['validation'] as Map
        : const {};
    return _DrPackage(
      items: items,
      suppliers: suppliers,
      purchaseOrders: orders,
      purchaseLines: lines,
      preview: DrMdbImportPreview(
        items: items.length,
        suppliers: suppliers.length,
        purchaseOrders: orders.length,
        purchaseLines: lines.length,
        missingItemJoins: _manifestCount(validation, 'missingItemJoins'),
        missingSupplierJoins:
            _manifestCount(validation, 'missingSupplierJoins'),
      ),
    );
  }

  static List<Map<String, dynamic>> _csv(
      Map<String, ArchiveFile> entries, String name) {
    final entry = entries[name];
    if (entry == null) throw DrMdbImportException('$name 파일이 없습니다.');
    final text = _entryText(entry).replaceFirst('\ufeff', '');
    if (text.trim().isEmpty) return [];
    final rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(text);
    if (rows.isEmpty) return [];
    final headers = rows.first.map(_text).toList();
    return rows
        .skip(1)
        .where((row) => row.any((value) => _text(value).isNotEmpty))
        .map((row) {
      return <String, dynamic>{
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < row.length ? row[i] : ''
      };
    }).toList();
  }

  static String _entryText(ArchiveFile entry) =>
      utf8.decode(entry.content as List<int>);
  static int _manifestCount(Map values, String key) =>
      int.tryParse('${values[key] ?? 0}') ?? 0;
  static String _required(Map<String, dynamic> row, String key) {
    final value = _text(row[key]);
    if (value.isEmpty) throw DrMdbImportException('$key 값이 비어 있습니다.');
    return value;
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';
  static String _fallback(Object? value, String fallback) =>
      _text(value).isEmpty ? fallback : _text(value);
  static String? _nullable(Object? value) =>
      _text(value).isEmpty ? null : _text(value);
  static double _asDouble(Object? value) => double.tryParse(_text(value)) ?? 0;
  static double? _doubleOrNull(Object? value) =>
      _text(value).isEmpty ? null : double.tryParse(_text(value));
  static String _isoDate(Object? value, String fallback) =>
      _nullableIsoDate(value) ?? fallback;
  static String? _nullableIsoDate(Object? value) {
    final text = _text(value);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toIso8601String() ?? text;
  }

  static String _normalizedName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

class _DrPackage {
  const _DrPackage(
      {required this.items,
      required this.suppliers,
      required this.purchaseOrders,
      required this.purchaseLines,
      required this.preview});
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> purchaseOrders;
  final List<Map<String, dynamic>> purchaseLines;
  final DrMdbImportPreview preview;
}
