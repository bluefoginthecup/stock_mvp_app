import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import 'app_path_service.dart';

class DrMdbImportPreview {
  final int itemCount;
  final int supplierCount;
  final int purchaseOrderCount;
  final int purchaseLineCount;
  final int missingItemJoins;
  final int missingSupplierJoins;
  final String createdAt;

  const DrMdbImportPreview({
    required this.itemCount,
    required this.supplierCount,
    required this.purchaseOrderCount,
    required this.purchaseLineCount,
    required this.missingItemJoins,
    required this.missingSupplierJoins,
    required this.createdAt,
  });
}

class DrMdbImportResult {
  final int itemCount;
  final int supplierCount;
  final int purchaseOrderCount;
  final int purchaseLineCount;
  final String backupPath;

  const DrMdbImportResult({
    required this.itemCount,
    required this.supplierCount,
    required this.purchaseOrderCount,
    required this.purchaseLineCount,
    required this.backupPath,
  });

  String get message => '경영박사 이관 완료: 품목 $itemCount개, 거래처 $supplierCount개, '
      '발주 $purchaseOrderCount건, 라인 $purchaseLineCount개';
}

class DrMdbImportService {
  static const format = 'chalstock.dr_mdb.v1';

  final AppDatabase db;

  const DrMdbImportService(this.db);

  Future<DrMdbImportPreview> previewZip(File file) async {
    final payload = await _readPayload(file);
    final manifest = payload.manifest;
    _validateManifest(manifest);
    final counts = _mapValue(manifest['counts']);
    final validation = _mapValue(manifest['validation']);
    return DrMdbImportPreview(
      itemCount: _intValue(counts['items']),
      supplierCount: _intValue(counts['suppliers']),
      purchaseOrderCount: _intValue(counts['purchaseOrders']),
      purchaseLineCount: _intValue(counts['purchaseLines']),
      missingItemJoins: _intValue(validation['missingItemJoins']),
      missingSupplierJoins: _intValue(validation['missingSupplierJoins']),
      createdAt: (manifest['createdAt'] ?? '').toString(),
    );
  }

  Future<DrMdbImportResult> importZip(File file) async {
    final payload = await _readPayload(file);
    _validateManifest(payload.manifest);
    final backupPath = await _backupCurrentDatabase();

    await db.transaction(() async {
      await _ensureLegacyFolders();
      await _upsertItems(payload.items);
      await _upsertPurchaseOrders(payload.purchaseOrders);
      await _upsertPurchaseLines(payload.purchaseLines);
    });

    return DrMdbImportResult(
      itemCount: payload.items.length,
      supplierCount: payload.suppliers.length,
      purchaseOrderCount: payload.purchaseOrders.length,
      purchaseLineCount: payload.purchaseLines.length,
      backupPath: backupPath,
    );
  }

  Future<_DrMdbImportPayload> _readPayload(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final manifest = jsonDecode(_readTextFile(archive, 'manifest.json'));
    if (manifest is! Map) {
      throw const FormatException('manifest.json 형식이 올바르지 않습니다.');
    }
    return _DrMdbImportPayload(
      manifest: Map<String, dynamic>.from(manifest),
      items: _readCsvFile(archive, 'items.csv'),
      suppliers: _readCsvFile(archive, 'suppliers.csv'),
      purchaseOrders: _readCsvFile(archive, 'purchase_orders.csv'),
      purchaseLines: _readCsvFile(archive, 'purchase_lines.csv'),
    );
  }

  String _readTextFile(Archive archive, String name) {
    final file = archive.files.where((entry) => entry.name == name).firstOrNull;
    if (file == null || !file.isFile) {
      throw FormatException('$name 파일이 ZIP에 없습니다.');
    }
    final bytes = file.content as List<int>;
    return utf8.decode(bytes, allowMalformed: true).replaceFirst('\ufeff', '');
  }

  List<Map<String, String>> _readCsvFile(Archive archive, String name) {
    final text = _readTextFile(archive, name);
    if (text.trim().isEmpty) return const [];
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(text)
        .where((row) => row.isNotEmpty)
        .toList(growable: false);
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((value) => value.toString()).toList();
    return rows.skip(1).map((row) {
      final map = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        map[headers[i]] = i < row.length ? row[i].toString() : '';
      }
      return map;
    }).toList(growable: false);
  }

  void _validateManifest(Map<String, dynamic> manifest) {
    if ((manifest['format'] ?? '').toString() != format) {
      throw const FormatException('경영박사 이관 ZIP 형식이 아닙니다.');
    }
    if (_intValue(manifest['formatVersion']) != 1) {
      throw const FormatException('지원하지 않는 경영박사 이관 형식입니다.');
    }
  }

  Future<String> _backupCurrentDatabase() async {
    final dir = await const AppPathService().userSupportDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final backupPath = p.join(dir.path, 'stockapp_before_dr_import_$stamp.db');
    await db
        .customStatement("VACUUM INTO '${backupPath.replaceAll("'", "''")}'");
    return backupPath;
  }

  Future<void> _ensureLegacyFolders() async {
    const rootId = 'dr_folder_root';
    const childId = 'dr_folder_balju';
    await db.customStatement(
      '''
      INSERT OR IGNORE INTO folders
        (id, name, parent_id, depth, "order", search_normalized,
         search_initials, is_deleted)
      VALUES (?, ?, NULL, 1, 9000, ?, ?, 0)
      ''',
      [rootId, '경영박사', '경영박사', 'ㄱㅇㅂㅅ'],
    );
    await db.customStatement(
      '''
      INSERT OR IGNORE INTO folders
        (id, name, parent_id, depth, "order", search_normalized,
         search_initials, is_deleted)
      VALUES (?, ?, ?, 2, 0, ?, ?, 0)
      ''',
      [childId, '발주이관', rootId, '발주이관', 'ㅂㅈㅇㄱ'],
    );
  }

  Future<void> _upsertItems(List<Map<String, String>> rows) async {
    for (final row in rows) {
      final itemId = _stringValue(row['item_id']);
      if (itemId.isEmpty) continue;
      final spec = _stringValue(row['spec']);
      final memo = _stringValue(row['memo']);
      final memo2 = _stringValue(row['memo2']);
      final attrs = {
        'source': 'drmdb',
        'legacyTable': 'ITEM',
        'legacyCode': _intValue(row['legacy_code']),
        if (_stringValue(row['legacy_code2']).isNotEmpty)
          'legacyCode2': _stringValue(row['legacy_code2']),
        if (spec.isNotEmpty) '규격': spec,
        if (memo.isNotEmpty) '비고': memo,
        if (memo2.isNotEmpty) '비고2': memo2,
      };
      final unit =
          _stringValue(row['unit']).isEmpty ? 'EA' : _stringValue(row['unit']);
      await db.customStatement(
        '''
        INSERT INTO items
          (id, name, display_name, sku, unit, search_normalized,
           search_initials, search_full_normalized, folder, subfolder,
           subsubfolder, min_qty, qty, kind, attrs_json, unit_in, unit_out,
           conversion_rate, conversion_mode, stock_hints_json, supplier_name,
           default_supplier_id, default_supplier_uid, default_price,
           default_purchase_price, default_sale_price, reorder_interval_days,
           last_ordered_at, next_reorder_date, reorder_reminder_enabled,
           reorder_reminder_days_before, is_favorite, is_deleted, deleted_at,
           extra)
        VALUES
          (?, ?, ?, ?, ?, ?, '', ?, '경영박사', '발주이관',
           NULL, 0, 0, ?, ?, ?, ?, 1.0, 'fixed', NULL, ?,
           NULL, ?, ?, ?, ?, NULL, NULL, NULL, 0, 0, 0, 0, NULL, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          display_name = excluded.display_name,
          sku = excluded.sku,
          unit = excluded.unit,
          search_normalized = excluded.search_normalized,
          search_full_normalized = excluded.search_full_normalized,
          folder = excluded.folder,
          subfolder = excluded.subfolder,
          kind = excluded.kind,
          attrs_json = excluded.attrs_json,
          unit_in = excluded.unit_in,
          unit_out = excluded.unit_out,
          supplier_name = excluded.supplier_name,
          default_supplier_uid = excluded.default_supplier_uid,
          default_price = excluded.default_price,
          default_purchase_price = excluded.default_purchase_price,
          default_sale_price = excluded.default_sale_price,
          is_deleted = 0,
          deleted_at = NULL,
          extra = excluded.extra
        ''',
        [
          itemId,
          _fallback(row['name'], '경영박사 품목'),
          _fallback(row['display_name'], _fallback(row['name'], '경영박사 품목')),
          _fallback(row['legacy_code2'], 'DR-${_intValue(row['legacy_code'])}'),
          unit,
          _fallback(row['display_name'], _fallback(row['name'], '경영박사 품목')),
          _fallback(row['display_name'], _fallback(row['name'], '경영박사 품목')),
          _stringValue(row['kind']).isEmpty ? 'raw' : _stringValue(row['kind']),
          jsonEncode(attrs),
          unit,
          unit,
          _nullIfEmpty(row['supplier_name']),
          _nullIfEmpty(row['supplier_id']),
          _nullableDouble(row['default_purchase_price']),
          _nullableDouble(row['default_purchase_price']),
          _nullableDouble(row['default_sale_price']),
          jsonEncode({'source': 'drmdb', 'legacyCode': row['legacy_code']}),
        ],
      );
      await db.customStatement(
        '''
        INSERT INTO item_paths (item_id, l1_id, l2_id, l3_id)
        VALUES (?, 'dr_folder_root', 'dr_folder_balju', NULL)
        ON CONFLICT(item_id) DO UPDATE SET
          l1_id = excluded.l1_id,
          l2_id = excluded.l2_id,
          l3_id = excluded.l3_id
        ''',
        [itemId],
      );
    }
  }

  Future<void> _upsertPurchaseOrders(List<Map<String, String>> rows) async {
    for (final row in rows) {
      final id = _stringValue(row['purchase_order_id']);
      if (id.isEmpty) continue;
      await db.customStatement(
        '''
        INSERT INTO purchase_orders
          (id, supplier_name, supplier_id, shipping_cost, extra_cost, vat,
           payment_status, paid_at, payment_due_at, vat_invoice_status,
           vat_invoice_issued_at, vat_invoice_due_at, vat_included, vat_type,
           eta, status, created_at, updated_at, is_deleted, memo,
           delivery_name, delivery_address, delivery_phone, delivery_memo,
           show_delivery_on_print, shipping_destination_id, buyer_profile_id,
           buyer_profile_name, buyer_business_number, buyer_company_name,
           buyer_representative, buyer_address, buyer_business_type,
           buyer_business_item, buyer_phone_fax, deleted_at, order_id,
           received_at)
        VALUES
          (?, ?, NULL, 0, 0, 0,
           'unpaid', NULL, NULL, 'pending',
           NULL, NULL, 0, 2,
           ?, ?, ?, ?, 0, ?,
           NULL, NULL, NULL, NULL,
           0, NULL, NULL,
           NULL, NULL, NULL,
           NULL, NULL, NULL,
           NULL, NULL, NULL, NULL,
           ?)
        ON CONFLICT(id) DO UPDATE SET
          supplier_name = excluded.supplier_name,
          eta = excluded.eta,
          status = excluded.status,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          is_deleted = 0,
          memo = excluded.memo,
          received_at = excluded.received_at
        ''',
        [
          id,
          _fallback(row['supplier_name'], '경영박사 거래처'),
          _dateIso(row['eta']),
          _stringValue(row['status']).isEmpty ? 'received' : row['status'],
          _dateIso(row['order_date']),
          DateTime.now().toIso8601String(),
          _nullIfEmpty(row['memo']),
          _nullableDateIso(row['received_at']),
        ],
      );
    }
  }

  Future<void> _upsertPurchaseLines(List<Map<String, String>> rows) async {
    final orderIds = rows
        .map((row) => _stringValue(row['purchase_order_id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final orderId in orderIds) {
      await db.customStatement(
        "DELETE FROM purchase_lines WHERE order_id = ? AND id LIKE 'dr_balju_%'",
        [orderId],
      );
    }

    for (final row in rows) {
      final id = _stringValue(row['purchase_line_id']);
      final orderId = _stringValue(row['purchase_order_id']);
      final itemId = _stringValue(row['item_id']);
      if (id.isEmpty || orderId.isEmpty || itemId.isEmpty) continue;
      final qty = _doubleValue(row['qty']);
      final unitPrice = _doubleValue(row['unit_price']);
      final supplyAmount = _doubleValue(row['supply_amount'], qty * unitPrice);
      final totalAmount = _doubleValue(row['total_amount'], supplyAmount);
      final attrs = [
        {
          'key': 'legacyPurchaseNo',
          'label': '경영박사 발주번호',
          'value': _stringValue(row['purchase_no']),
        },
        {
          'key': 'legacyLineNo',
          'label': '경영박사 라인번호',
          'value': _stringValue(row['legacy_line_no']),
        },
        if (_stringValue(row['spec']).isNotEmpty)
          {'key': 'spec', 'label': '규격', 'value': _stringValue(row['spec'])},
      ];
      await db.customStatement(
        '''
        INSERT INTO purchase_lines
          (id, order_id, item_id, name, unit, qty, unit_price, vat_type,
           supply_amount, vat_amount, total_amount, amount_edited, note, memo,
           color_no, print_attrs_json, is_deleted, deleted_at)
        VALUES
          (?, ?, ?, ?, ?, ?, ?, 2, ?, 0, ?, 1, ?, ?, NULL, ?, 0, NULL)
        ON CONFLICT(id) DO UPDATE SET
          order_id = excluded.order_id,
          item_id = excluded.item_id,
          name = excluded.name,
          unit = excluded.unit,
          qty = excluded.qty,
          unit_price = excluded.unit_price,
          vat_type = excluded.vat_type,
          supply_amount = excluded.supply_amount,
          vat_amount = excluded.vat_amount,
          total_amount = excluded.total_amount,
          amount_edited = excluded.amount_edited,
          note = excluded.note,
          memo = excluded.memo,
          print_attrs_json = excluded.print_attrs_json,
          is_deleted = 0,
          deleted_at = NULL
        ''',
        [
          id,
          orderId,
          itemId,
          _fallback(row['name'], '경영박사 품목'),
          _fallback(row['unit'], 'EA'),
          qty,
          unitPrice,
          supplyAmount,
          totalAmount,
          _nullIfEmpty(row['purchase_no']),
          _nullIfEmpty(row['memo']),
          jsonEncode(attrs),
        ],
      );
    }
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static String _stringValue(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static String _fallback(Object? value, String fallback) {
    final text = _stringValue(value);
    return text.isEmpty ? fallback : text;
  }

  static String? _nullIfEmpty(Object? value) {
    final text = _stringValue(value);
    return text.isEmpty ? null : text;
  }

  static int _intValue(Object? value) {
    final text = _stringValue(value);
    if (text.isEmpty) return 0;
    return double.tryParse(text)?.round() ?? int.tryParse(text) ?? 0;
  }

  static double _doubleValue(Object? value, [double fallback = 0]) {
    final text = _stringValue(value);
    if (text.isEmpty) return fallback;
    return double.tryParse(text) ?? fallback;
  }

  static double? _nullableDouble(Object? value) {
    final text = _stringValue(value);
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static String _dateIso(Object? value) {
    final text = _stringValue(value);
    if (text.isEmpty) return DateTime.now().toIso8601String();
    return DateTime.tryParse(text)?.toIso8601String() ??
        DateTime.now().toIso8601String();
  }

  static String? _nullableDateIso(Object? value) {
    final text = _stringValue(value);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toIso8601String();
  }
}

class _DrMdbImportPayload {
  final Map<String, dynamic> manifest;
  final List<Map<String, String>> items;
  final List<Map<String, String>> suppliers;
  final List<Map<String, String>> purchaseOrders;
  final List<Map<String, String>> purchaseLines;

  const _DrMdbImportPayload({
    required this.manifest,
    required this.items,
    required this.suppliers,
    required this.purchaseOrders,
    required this.purchaseLines,
  });
}
