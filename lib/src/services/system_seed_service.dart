import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/bom.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/purchase_line.dart';
import '../models/purchase_order.dart';
import '../models/quote.dart';
import '../models/quote_line.dart';
import '../models/suppliers.dart';
import '../models/txn.dart';
import '../models/types.dart';
import '../models/work.dart';
import '../utils/item_search_keys.dart';

class SystemSeedService {
  static const Map<String, String> systemRootFolders = {
    'Finished': '완제품',
    'SemiFinished': '반제품',
    'Raw': '원자재',
    'Sub': '부자재',
  };

  static Future<void> ensure(AppDatabase db) async {
    await ensureSystemRootFolders(db);
    await ensureExampleItems(db);
    await ensureExampleBomRows(db);
    await ensureExampleSuppliers(db);
    await ensureExampleOrders(db);
    await ensureExampleQuotes(db);
    await ensureExamplePurchaseOrders(db);
    await ensureExampleWorks(db);
    await ensureExampleTransactions(db);
  }

  static Future<void> ensureSystemRootFolders(AppDatabase db) async {
    var order = 0;
    for (final entry in systemRootFolders.entries) {
      await db.into(db.folders).insertOnConflictUpdate(
            FoldersCompanion(
              id: Value(entry.key),
              name: Value(entry.value),
              parentId: const Value(null),
              depth: const Value(0),
              order: Value(order++),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
            ),
          );
    }
  }

  static Future<void> ensureExampleItems(AppDatabase db) async {
    for (final entry in systemRootFolders.entries) {
      for (final item in _exampleItemsForRoot(entry.key, entry.value)) {
        final existing = await (db.select(db.items)
              ..where((t) => t.id.equals(item.id)))
            .getSingleOrNull();
        if (existing != null &&
            (existing.isDeleted ||
                (!existing.name.startsWith('샘플 ') &&
                    !existing.sku.startsWith('SAMPLE-')))) {
          continue;
        }

        final keys = buildItemSearchKeysRaw(
          name: item.displayName ?? item.name,
          sku: item.sku,
          folder: entry.value,
        );
        final companion = item.toCompanion().copyWith(
              folder: Value(entry.value),
              subfolder: const Value(null),
              subsubfolder: const Value(null),
              searchNormalized: Value(keys.nameNorm),
              searchInitials: Value(keys.initials),
              searchFullNormalized: Value(keys.fullNorm),
              defaultPurchasePrice: Value(item.defaultPurchasePrice),
              defaultSalePrice: Value(item.defaultSalePrice),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
            );

        if (existing == null) {
          await db.into(db.items).insert(companion);
        } else {
          await (db.update(db.items)..where((t) => t.id.equals(item.id)))
              .write(companion);
        }
        await db.into(db.itemPaths).insertOnConflictUpdate(
              ItemPathsCompanion(
                itemId: Value(item.id),
                l1Id: Value(entry.key),
                l2Id: const Value(null),
                l3Id: const Value(null),
              ),
            );
      }
    }
  }

  static Future<void> ensureExampleBomRows(AppDatabase db) async {
    final rows = <BomRow>[
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_001',
        componentItemId: 'system_sample_SemiFinished_002',
        kind: BomKind.semi,
        qtyPer: 1,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_001',
        componentItemId: 'system_sample_Raw_003',
        kind: BomKind.raw,
        qtyPer: 20,
        wastePct: 0.05,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_001',
        componentItemId: 'system_sample_Sub_001',
        kind: BomKind.sub,
        qtyPer: 1,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_001',
        componentItemId: 'system_sample_Sub_002',
        kind: BomKind.sub,
        qtyPer: 1,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_002',
        componentItemId: 'system_sample_SemiFinished_001',
        kind: BomKind.semi,
        qtyPer: 1,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_002',
        componentItemId: 'system_sample_Raw_002',
        kind: BomKind.raw,
        qtyPer: 0.4,
        wastePct: 0.1,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_002',
        componentItemId: 'system_sample_Sub_003',
        kind: BomKind.sub,
        qtyPer: 0.5,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_003',
        componentItemId: 'system_sample_SemiFinished_003',
        kind: BomKind.semi,
        qtyPer: 1,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_003',
        componentItemId: 'system_sample_Sub_002',
        kind: BomKind.sub,
        qtyPer: 1,
      ),
      const BomRow(
        root: BomRoot.finished,
        parentItemId: 'system_sample_Finished_003',
        componentItemId: 'system_sample_Sub_003',
        kind: BomKind.sub,
        qtyPer: 1.2,
      ),
      const BomRow(
        root: BomRoot.semi,
        parentItemId: 'system_sample_SemiFinished_001',
        componentItemId: 'system_sample_Raw_002',
        kind: BomKind.raw,
        qtyPer: 0.5,
        wastePct: 0.08,
      ),
      const BomRow(
        root: BomRoot.semi,
        parentItemId: 'system_sample_SemiFinished_002',
        componentItemId: 'system_sample_Raw_001',
        kind: BomKind.raw,
        qtyPer: 180,
        wastePct: 0.03,
      ),
      const BomRow(
        root: BomRoot.semi,
        parentItemId: 'system_sample_SemiFinished_002',
        componentItemId: 'system_sample_Raw_003',
        kind: BomKind.raw,
        qtyPer: 12,
      ),
      const BomRow(
        root: BomRoot.semi,
        parentItemId: 'system_sample_SemiFinished_003',
        componentItemId: 'system_sample_Sub_001',
        kind: BomKind.sub,
        qtyPer: 1,
      ),
      const BomRow(
        root: BomRoot.semi,
        parentItemId: 'system_sample_SemiFinished_003',
        componentItemId: 'system_sample_Sub_002',
        kind: BomKind.sub,
        qtyPer: 1,
      ),
    ];

    final byParent = <String, List<BomRow>>{};
    for (final row in rows) {
      byParent
          .putIfAbsent('${row.root.name}|${row.parentItemId}', () => [])
          .add(row);
    }

    for (final group in byParent.values) {
      final first = group.first;
      if (!await _activeItemExists(db, first.parentItemId)) continue;
      final existing = await (db.select(db.bomRows)
            ..where((t) =>
                t.root.equals(first.root.name) &
                t.parentItemId.equals(first.parentItemId)))
          .get();
      if (existing.isNotEmpty) continue;

      for (final row in group) {
        if (await _activeItemExists(db, row.componentItemId)) {
          await db.into(db.bomRows).insertOnConflictUpdate(row.toCompanion());
        }
      }
    }
  }

  static Future<void> ensureExampleSuppliers(AppDatabase db) async {
    final now = DateTime.now();
    final suppliers = [
      Supplier(
        id: 'example_supplier_customer',
        name: '예시 거래처 - 따뜻한상점',
        contactName: '예시 담당자',
        phone: '010-0000-1000',
        email: 'example-customer@chalstock.test',
        addr: '서울시 예시구 샘플로 10',
        memo: '예시 주문/견적에서 사용하는 거래처입니다.',
        businessNumber: '000-00-00000',
        representative: '예시 대표',
        businessType: '소매',
        businessItem: '생활소품',
        createdAt: now,
        updatedAt: now,
      ),
      Supplier(
        id: 'example_supplier_material',
        name: '예시 거래처 - 원부자재상사',
        contactName: '예시 매입담당',
        phone: '010-0000-2000',
        email: 'example-material@chalstock.test',
        addr: '경기도 예시시 재료로 20',
        memo: '예시 발주에서 사용하는 거래처입니다.',
        businessNumber: '111-11-11111',
        representative: '예시 사장',
        businessType: '도매',
        businessItem: '원부자재',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final supplier in suppliers) {
      final existing = await (db.select(db.suppliers)
            ..where((t) => t.id.equals(supplier.id)))
          .getSingleOrNull();
      if (existing != null) continue;
      await db.into(db.suppliers).insert(supplier.toCompanion());
    }
  }

  static Future<void> ensureExampleOrders(AppDatabase db) async {
    const orderId = 'example_order_001';
    if (await _orderRowExists(db, orderId)) return;

    final now = DateTime.now();
    final order = Order(
      id: orderId,
      date: now.subtract(const Duration(days: 2)),
      dueDate: now.add(const Duration(days: 5)),
      customer: '예시 거래처 - 따뜻한상점',
      memo: '예시 주문입니다. 완제품 부족 수량과 작업 계획을 확인해보세요.',
      status: OrderStatus.planned,
      lines: [
        OrderLine(
          id: 'example_order_001_line_001',
          itemId: 'system_sample_Finished_001',
          qty: 6,
        ),
        OrderLine(
          id: 'example_order_001_line_002',
          itemId: 'system_sample_Finished_002',
          qty: 4,
        ),
      ],
      updatedAt: now,
    );
    await db.into(db.orders).insert(order.toCompanion());
    for (final line in order.lines) {
      await db.into(db.orderLines).insert(line.toCompanion(order.id));
    }
  }

  static Future<void> ensureExampleQuotes(AppDatabase db) async {
    const quoteId = 'example_quote_001';
    if (await _quoteRowExists(db, quoteId)) return;

    final now = DateTime.now();
    final quote = Quote(
      id: quoteId,
      customerName: '예시 거래처 - 따뜻한상점',
      customerId: 'example_supplier_customer',
      quoteDate: now,
      validUntil: now.add(const Duration(days: 14)),
      status: QuoteStatus.sent,
      memo: '예시 견적입니다. 출력 미리보기와 공급자 프로필 반영을 확인해보세요.',
      shippingCost: 3000,
      vatType: QuoteVatType.exclusive,
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.quotes).insert(quote.toCompanion());
    final lines = [
      QuoteLine(
        id: 'example_quote_001_line_001',
        quoteId: quoteId,
        itemId: 'system_sample_Finished_001',
        name: '예시 완제품 - 캔들 세트',
        unit: 'EA',
        qty: 10,
        unitPrice: 18000,
        memo: '예시 견적 품목',
      ),
      QuoteLine(
        id: 'example_quote_001_line_002',
        quoteId: quoteId,
        itemId: 'system_sample_Finished_003',
        name: '예시 완제품 - 선물 패키지',
        unit: 'SET',
        qty: 3,
        unitPrice: 35000,
        memo: '예시 견적 품목',
      ),
    ];
    for (final line in lines) {
      await db.into(db.quoteLines).insert(line.toCompanion());
    }
  }

  static Future<void> ensureExamplePurchaseOrders(AppDatabase db) async {
    const purchaseId = 'example_purchase_001';
    if (await _purchaseOrderRowExists(db, purchaseId)) return;

    final now = DateTime.now();
    final po = PurchaseOrder(
      id: purchaseId,
      supplierName: '예시 거래처 - 원부자재상사',
      supplierId: 'example_supplier_material',
      eta: now.add(const Duration(days: 3)),
      status: PurchaseOrderStatus.ordered,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
      memo: '예시 발주입니다. 입고 처리와 거래명세서 첨부 흐름을 확인해보세요.',
      paymentDueAt: now.add(const Duration(days: 30)),
      vatInvoiceDueAt: now.add(const Duration(days: 10)),
    );
    await db.into(db.purchaseOrders).insert(po.toCompanion());
    final lines = [
      PurchaseLine(
        id: 'example_purchase_001_line_001',
        orderId: purchaseId,
        itemId: 'system_sample_Raw_001',
        name: '예시 원자재 - 소이왁스',
        unit: 'g',
        qty: 5000,
        unitPrice: 12000,
        memo: '예시 발주 품목',
      ),
      PurchaseLine(
        id: 'example_purchase_001_line_002',
        orderId: purchaseId,
        itemId: 'system_sample_Sub_002',
        name: '예시 부자재 - 포장 박스',
        unit: 'EA',
        qty: 100,
        unitPrice: 700,
        memo: '예시 발주 품목',
      ),
    ];
    for (final line in lines) {
      await db.into(db.purchaseLines).insert(line.toCompanion());
    }
  }

  static Future<void> ensureExampleWorks(AppDatabase db) async {
    final now = DateTime.now();
    final works = [
      Work(
        id: 'example_work_001',
        itemId: 'system_sample_Finished_001',
        qty: 6,
        doneQty: 2,
        orderId: 'example_order_001',
        status: WorkStatus.inProgress,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
        startedAt: now.subtract(const Duration(hours: 6)),
        sourceKey: 'example',
      ),
      Work(
        id: 'example_work_002',
        itemId: 'system_sample_SemiFinished_002',
        qty: 6,
        doneQty: 6,
        orderId: 'example_order_001',
        parentWorkId: 'example_work_001',
        status: WorkStatus.done,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
        startedAt: now.subtract(const Duration(hours: 5)),
        finishedAt: now.subtract(const Duration(hours: 2)),
        sourceKey: 'example',
      ),
    ];

    for (final work in works) {
      if (await _workRowExists(db, work.id)) continue;
      await db.into(db.works).insert(work.toCompanion());
    }
  }

  static Future<void> ensureExampleTransactions(AppDatabase db) async {
    final now = DateTime.now();
    final txns = [
      Txn.in_(
        id: 'example_txn_001',
        itemId: 'system_sample_Raw_001',
        qty: 5000,
        refType: RefType.purchase,
        refId: 'example_purchase_001',
        ts: now.subtract(const Duration(days: 1)),
        note: '예시 입고 - 발주 입고 처리',
        memo: '예시 입출고내역입니다.',
      ),
      Txn.out_(
        id: 'example_txn_002',
        itemId: 'system_sample_Raw_001',
        qty: 1080,
        refType: RefType.work,
        refId: 'example_work_002',
        ts: now.subtract(const Duration(hours: 2)),
        note: '예시 출고 - 반제품 생산 소모',
        memo: '예시 입출고내역입니다.',
      ),
      Txn.in_(
        id: 'example_txn_003',
        itemId: 'system_sample_SemiFinished_002',
        qty: 6,
        refType: RefType.work,
        refId: 'example_work_002',
        ts: now.subtract(const Duration(hours: 2)),
        note: '예시 입고 - 반제품 생산 완료',
        memo: '예시 입출고내역입니다.',
      ),
    ];

    for (final txn in txns) {
      if (await _txnRowExists(db, txn.id)) continue;
      await db.into(db.txns).insert(txn.toCompanion());
    }
  }

  static List<Item> _exampleItemsForRoot(String folderId, String folderName) {
    Item item({
      required String suffix,
      required String name,
      required String sku,
      required String unit,
      required int qty,
      required int minQty,
      required String kind,
      double? defaultPurchasePrice,
      double? defaultSalePrice,
    }) {
      return Item(
        id: 'system_sample_${folderId}_$suffix',
        name: name,
        displayName: name,
        sku: sku,
        unit: unit,
        folder: folderName,
        minQty: minQty,
        qty: qty,
        kind: kind,
        attrs: const {
          'example': true,
          'exampleNote': '예시 아이템입니다. 사용법 확인 후 필요 없으면 삭제해도 됩니다.',
        },
        defaultPurchasePrice: defaultPurchasePrice,
        defaultSalePrice: defaultSalePrice,
      );
    }

    switch (folderId) {
      case 'Finished':
        return [
          item(
            suffix: '001',
            name: '예시 완제품 - 캔들 세트',
            sku: 'EXAMPLE-FIN-001',
            unit: 'EA',
            qty: 8,
            minQty: 2,
            kind: 'Finished',
            defaultSalePrice: 18000,
          ),
          item(
            suffix: '002',
            name: '예시 완제품 - 파우치',
            sku: 'EXAMPLE-FIN-002',
            unit: 'EA',
            qty: 12,
            minQty: 3,
            kind: 'Finished',
            defaultSalePrice: 22000,
          ),
          item(
            suffix: '003',
            name: '예시 완제품 - 선물 패키지',
            sku: 'EXAMPLE-FIN-003',
            unit: 'SET',
            qty: 5,
            minQty: 1,
            kind: 'Finished',
            defaultSalePrice: 35000,
          ),
        ];
      case 'SemiFinished':
        return [
          item(
            suffix: '001',
            name: '예시 반제품 - 재단 원단',
            sku: 'EXAMPLE-SEMI-001',
            unit: 'EA',
            qty: 20,
            minQty: 5,
            kind: 'SemiFinished',
          ),
          item(
            suffix: '002',
            name: '예시 반제품 - 충전 캔들',
            sku: 'EXAMPLE-SEMI-002',
            unit: 'EA',
            qty: 10,
            minQty: 3,
            kind: 'SemiFinished',
          ),
          item(
            suffix: '003',
            name: '예시 반제품 - 조립 전 키트',
            sku: 'EXAMPLE-SEMI-003',
            unit: 'SET',
            qty: 7,
            minQty: 2,
            kind: 'SemiFinished',
          ),
        ];
      case 'Raw':
        return [
          item(
            suffix: '001',
            name: '예시 원자재 - 소이왁스',
            sku: 'EXAMPLE-RAW-001',
            unit: 'g',
            qty: 5000,
            minQty: 1000,
            kind: 'Raw',
            defaultPurchasePrice: 12000,
          ),
          item(
            suffix: '002',
            name: '예시 원자재 - 면 원단',
            sku: 'EXAMPLE-RAW-002',
            unit: 'm',
            qty: 30,
            minQty: 5,
            kind: 'Raw',
            defaultPurchasePrice: 6500,
          ),
          item(
            suffix: '003',
            name: '예시 원자재 - 향료',
            sku: 'EXAMPLE-RAW-003',
            unit: 'ml',
            qty: 800,
            minQty: 100,
            kind: 'Raw',
            defaultPurchasePrice: 9000,
          ),
        ];
      case 'Sub':
      default:
        return [
          item(
            suffix: '001',
            name: '예시 부자재 - 라벨 스티커',
            sku: 'EXAMPLE-SUB-001',
            unit: 'EA',
            qty: 200,
            minQty: 50,
            kind: 'Sub',
            defaultPurchasePrice: 80,
          ),
          item(
            suffix: '002',
            name: '예시 부자재 - 포장 박스',
            sku: 'EXAMPLE-SUB-002',
            unit: 'EA',
            qty: 60,
            minQty: 20,
            kind: 'Sub',
            defaultPurchasePrice: 700,
          ),
          item(
            suffix: '003',
            name: '예시 부자재 - 리본',
            sku: 'EXAMPLE-SUB-003',
            unit: 'm',
            qty: 40,
            minQty: 10,
            kind: 'Sub',
            defaultPurchasePrice: 300,
          ),
        ];
    }
  }

  static Future<bool> _activeItemExists(AppDatabase db, String itemId) async {
    final row = await (db.select(db.items)
          ..where((t) => t.id.equals(itemId) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row != null;
  }

  static Future<bool> _orderRowExists(AppDatabase db, String id) async =>
      (await (db.select(db.orders)..where((t) => t.id.equals(id)))
          .getSingleOrNull()) !=
      null;

  static Future<bool> _quoteRowExists(AppDatabase db, String id) async =>
      (await (db.select(db.quotes)..where((t) => t.id.equals(id)))
          .getSingleOrNull()) !=
      null;

  static Future<bool> _purchaseOrderRowExists(
    AppDatabase db,
    String id,
  ) async =>
      (await (db.select(db.purchaseOrders)..where((t) => t.id.equals(id)))
          .getSingleOrNull()) !=
      null;

  static Future<bool> _workRowExists(AppDatabase db, String id) async =>
      (await (db.select(db.works)..where((t) => t.id.equals(id)))
          .getSingleOrNull()) !=
      null;

  static Future<bool> _txnRowExists(AppDatabase db, String id) async =>
      (await (db.select(db.txns)..where((t) => t.id.equals(id)))
          .getSingleOrNull()) !=
      null;
}
