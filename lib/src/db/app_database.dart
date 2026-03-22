// lib/src/db/app_database.dart
import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

// 도메인 모델 import
import '../models/item.dart';
import '../models/folder_node.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/order.dart';
import '../models/work.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';
import '../models/suppliers.dart';
import '../models/lot.dart';
import '../models/types.dart';
import '../utils/korean_search.dart';


// drift가 생성해줄 파일
part 'app_database.g.dart';

/// =======================
///  Items 테이블 정의
/// =======================

@DataClassName('ItemRow') // 도메인 Item과 이름 충돌 방지
class Items extends Table {
  TextColumn get id => text()();                // it_xxx
  TextColumn get name => text()();              // name
  TextColumn get displayName => text().nullable()();
  TextColumn get sku => text()();
  TextColumn get unit => text()();              // EA, SET, ROLL...
  TextColumn get searchNormalized => text().withDefault(const Constant(''))();
  TextColumn get searchInitials => text().withDefault(const Constant(''))();
  TextColumn get searchFullNormalized => text().withDefault(const Constant(''))();


  // 레거시 폴더 필드
  TextColumn get folder => text()();            // 레거시 L1
  TextColumn get subfolder => text().nullable()();
  TextColumn get subsubfolder => text().nullable()();

  IntColumn get minQty => integer().withDefault(const Constant(0))();
  IntColumn get qty => integer().withDefault(const Constant(0))();

  // kind: Finished/SemiFinished/Sub 등
  TextColumn get kind => text().nullable()();

  // attrs: JSON 문자열로 저장 (Map<String,dynamic>)
  TextColumn get attrsJson => text().nullable()();

  // 환산 필드
  TextColumn get unitIn => text().withDefault(const Constant('EA'))();
  TextColumn get unitOut => text().withDefault(const Constant('EA'))();
  RealColumn get conversionRate =>
      real().withDefault(const Constant(1.0))();             // 1 unitIn = rate * unitOut
  TextColumn get conversionMode =>
      text().withDefault(const Constant('fixed'))();          // fixed | lot

  // stockHints도 JSON으로 보관 (레거시 폴백용)
  TextColumn get stockHintsJson => text().nullable()();

  // 거래처
  TextColumn get supplierName => text().nullable()();
  IntColumn get defaultSupplierId => integer().nullable()();
  RealColumn get defaultPrice => real().nullable()();
  RealColumn get defaultPurchasePrice => real().nullable()();
  RealColumn get defaultSalePrice => real().nullable()();

  //즐겨찾기
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601




  @override
  Set<Column> get primaryKey => {id};
  @override
    List<Index> get indexes => [
      Index('idx_items_search', 'searchNormalized'),
      Index('idx_items_search_full', 'searchFullNormalized'),
      Index('idx_items_initials', 'searchInitials'),
    ];

}

/// =======================
///  Folders (FolderNode)
/// =======================

@DataClassName('FolderRow')
class Folders extends Table {
  TextColumn get id => text()(); // FolderNode.id (결정적 해시)
  TextColumn get name => text()();
  TextColumn get parentId => text()
      .nullable()
      .references(Folders, #id, onDelete: KeyAction.setNull)();
  IntColumn get depth => integer()(); // 1,2,3
  IntColumn get order =>
      integer().withDefault(const Constant(0))(); // 형제 순서

  // ✅ 검색 키
  TextColumn get searchNormalized =>
      text().withDefault(const Constant(''))();
  TextColumn get searchInitials =>
      text().withDefault(const Constant(''))();


  @override
  Set<Column> get primaryKey => {id};
}

/// =======================
///  ItemPaths (itemId → L1/L2/L3 폴더 id들)
/// =======================

@DataClassName('ItemPathRow')
class ItemPaths extends Table {
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  TextColumn get l1Id =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  TextColumn get l2Id =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  TextColumn get l3Id =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column> get primaryKey => {itemId};

  @override
    List<Index> get indexes => [
      Index('idx_itempaths_l1', 'l1Id'),
      Index('idx_itempaths_l2', 'l2Id'),
      Index('idx_itempaths_l3', 'l3Id'),
    ];
}

/// =======================
///  Txns (입출고 트랜잭션)
/// =======================

@DataClassName('TxnRow')
class Txns extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get ts => text()(); // ISO8601 문자열
  TextColumn get type => text()(); // TxnType.name (in_, out_)
  TextColumn get status => text()(); // TxnStatus.name
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  IntColumn get qty => integer()(); // > 0

  TextColumn get refType => text()(); // RefType.name
  TextColumn get refId => text()();   // 원본 id

  TextColumn get note => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get sourceKey => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601



  @override
  Set<Column> get primaryKey => {id};
  @override
    List<Index> get indexes => [
      Index('idx_txn_item', 'itemId'),
      Index('idx_txn_ts', 'ts'),
    ];
}

/// =======================
///  BomRows (2단계 레시피)
///  Composite PK: (root, parentItemId, componentItemId, kind)
/// =======================

@DataClassName('BomRowDb')
class BomRows extends Table {
  TextColumn get root => text()(); // 'finished' | 'semi'
  TextColumn get parentItemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get componentItemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()(); // 'semi' | 'raw' | 'sub'
  RealColumn get qtyPer => real()(); // >0
  RealColumn get wastePct =>
      real().withDefault(const Constant(0.0))(); // 0..1

  @override
  Set<Column> get primaryKey =>
      {root, parentItemId, componentItemId, kind};
}

/// =======================
///  Orders / OrderLines
/// =======================

@DataClassName('OrderRow')
class Orders extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get date => text()(); // ISO8601
  TextColumn get customer => text()();
  TextColumn get memo => text().nullable()();
  TextColumn get status => text()(); // OrderStatus.name
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text().nullable()(); // ISO8601
  TextColumn get deletedAt => text().nullable()(); // ISO8601
  // ✅ 신규
  TextColumn get shippedAt => text().nullable()();  // 실제 출고(완료)일
  TextColumn get dueDate  => text().nullable()();   // 납기(출고 예정)일



  @override
  Set<Column> get primaryKey => {id};

}

@DataClassName('OrderLineRow')
class OrderLines extends Table {
  TextColumn get id => text()(); // uuid (line id)
  TextColumn get orderId =>
      text().references(Orders, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.restrict)();
  IntColumn get qty => integer()(); // >0

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601


  @override
  Set<Column> get primaryKey => {id};
  @override
    List<Index> get indexes => [
      Index('idx_orderline_order', 'orderId'),
      Index('idx_orderline_item', 'itemId'),
    ];
}

/// =======================
///  Works (생산 작업 지시)
/// =======================

@DataClassName('WorkRow')
class Works extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.restrict)();
  IntColumn get qty => integer()(); // >0

  // ✅ 누적 완료 수량 (초과 생산 가능)
  IntColumn get doneQty =>
      integer().withDefault(const Constant(0))(); // >= 0


  TextColumn get orderId =>
      text().nullable().references(Orders, #id, onDelete: KeyAction.setNull)();
  //부모 작업
  TextColumn get parentWorkId => text().nullable()();

  TextColumn get status => text()(); // WorkStatus.name
  TextColumn get createdAt => text()(); // ISO8601
  TextColumn get updatedAt => text().nullable()(); // ISO8601
  TextColumn get sourceKey => text().nullable()();

  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601

  TextColumn get startedAt => text().nullable()();   // 작업 시작(ISO8601)
  TextColumn get finishedAt => text().nullable()();  // 작업 완료(ISO8601)


  @override
  Set<Column> get primaryKey => {id};
  @override
    List<Index> get indexes => [
      Index('idx_work_item', 'itemId'),
      Index('idx_work_order', 'orderId'),
      Index('idx_work_status', 'status'),
    ];
}

/// =======================
///  PurchaseOrders / PurchaseLines
/// =======================

@DataClassName('PurchaseOrderRow')
class PurchaseOrders extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get supplierName => text()(); // 상호
  IntColumn get supplierId => integer().nullable()();

  RealColumn get shippingCost => real().withDefault(const Constant(0))();
  RealColumn get extraCost => real().withDefault(const Constant(0))();
  RealColumn get vat => real().withDefault(const Constant(0))();
  TextColumn get eta => text()(); // ISO8601
  TextColumn get status => text()(); // PurchaseOrderStatus.name
  TextColumn get createdAt => text()(); // ISO8601
  TextColumn get updatedAt => text()(); // ISO8601
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get memo => text().nullable()();
  TextColumn get deletedAt => text().nullable()(); // ISO8601
  // 🔥 신규 컬럼 2개 (주문 연동/입고일)
  TextColumn get orderId => text().nullable()();     // 주문 연동 발주면 채움
  TextColumn get receivedAt => text().nullable()();  // 실제 입고 완료일 (ISO8601 string)



  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PurchaseLineRow')
class PurchaseLines extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get orderId =>
      text().references(PurchaseOrders, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()(); // 표시용 이름
  TextColumn get unit => text()();
  RealColumn get qty => real()(); // 소수 허용
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get colorNo => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601




  @override
  Set<Column> get primaryKey => {id};
  @override
    List<Index> get indexes => [
      Index('idx_purchase_order', 'orderId'),
      Index('idx_purchase_item', 'itemId'),
    ];
}

/// =======================
///  Suppliers
/// =======================

@DataClassName('SupplierRow')
class Suppliers extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text()();
  TextColumn get contactName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get addr => text().nullable()();
  TextColumn get memo => text().nullable()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()(); // ISO8601
  TextColumn get updatedAt => text()(); // ISO8601

  @override
  Set<Column> get primaryKey => {id};
}

/// =======================
///  Lots (롤/필지 단위 재고)
/// =======================

@DataClassName('LotRow')
class Lots extends Table {
  TextColumn get id => text()(); // uuid or composed
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get lotNo => text()();
  RealColumn get receivedQtyRoll => real()(); // 롤 수
  RealColumn get measuredLengthM => real()(); // 실측 길이(m)
  RealColumn get usableQtyM => real()(); // 사용 가능 길이(m)
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get receivedAt => text()(); // ISO8601

  @override
  Set<Column> get primaryKey => {id};
}

/// =======================
///  AppDatabase
/// =======================
// ➊ 빠른실행 순서 저장 테이블
class QuickActionOrders extends Table {
    // 액션 ID (enum을 문자열로 저장: 'orders','stock',...)
    TextColumn get action => text()();
    // 현재 순서 (0부터 시작)
    IntColumn get orderIndex => integer()();
    @override
    Set<Column> get primaryKey => {action};

  }

@DriftDatabase(
  tables: [
    Items,
    Folders,
    ItemPaths,
    Txns,
    BomRows,
    Orders,
    OrderLines,
    Works,
    PurchaseOrders,
    PurchaseLines,
    Suppliers,
    Lots,
    QuickActionOrders, // ➋ 등록
  ],
)

class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

    factory AppDatabase() {
        _instance ??= AppDatabase._internal();
        return _instance!;
      }

    AppDatabase._internal() : super(_openConnection());

  // 🔥 이것 추가
  static AppDatabase get instance {
    if (_instance == null) {
      _instance = AppDatabase();
    }
    return _instance!;
  }

  static Future<void> closeInstance() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }

  @override
  int get schemaVersion => 12; //

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 → v2: Orders.deletedAt 추가
      if (from < 2) {
        await m.alterTable(TableMigration(
          orders,
          newColumns: [orders.deletedAt],
        ));
      }

      // v2 → v3: Items.isFavorite 추가
      if (from < 3) {
        await m.alterTable(TableMigration(
          items,
          newColumns: [items.isFavorite],
        ));
      }

      // v3 → v4: 통합휴지통 컬럼 일괄 추가
      if (from < 4) {
        await m.alterTable(TableMigration(
          items,
          newColumns: [items.isDeleted, items.deletedAt],
        ));
        await m.alterTable(TableMigration(
          txns,
          newColumns: [txns.isDeleted, txns.deletedAt],
        ));
        await m.alterTable(TableMigration(
          orders,
          newColumns: [orders.isDeleted],
        ));
        await m.alterTable(TableMigration(
          orderLines,
          newColumns: [orderLines.isDeleted, orderLines.deletedAt],
        ));
        await m.alterTable(TableMigration(
          works,
          newColumns: [works.isDeleted, works.deletedAt],
        ));
        await m.alterTable(TableMigration(
          purchaseOrders,
          newColumns: [purchaseOrders.isDeleted, purchaseOrders.deletedAt],
        ));
        await m.alterTable(TableMigration(
          purchaseLines,
          newColumns: [purchaseLines.isDeleted, purchaseLines.deletedAt],
        ));
      }

      // 🔥 v4 → v5: 타임라인용 신규 컬럼 추가
      if (from < 5) {
        // 1) 발주: 주문 연동/입고완료일
        await m.alterTable(TableMigration(
          purchaseOrders,
          newColumns: [
            purchaseOrders.orderId,      // nullable
            purchaseOrders.receivedAt,   // nullable
          ],
        ));

        // 2) 작업: 시작/완료일
        await m.alterTable(TableMigration(
          works,
          newColumns: [
            works.startedAt,             // nullable
            works.finishedAt,            // nullable
          ],
        ));

        // 3) 주문: 출고(완료)일 / 납기일
        await m.alterTable(TableMigration(
          orders,
          newColumns: [
            orders.shippedAt,            // nullable
            orders.dueDate,              // nullable
          ],
        ));
      }


      if (from < 6) {
        final exists = await _columnExists('works', 'done_qty');
        if (!exists) {
          await m.addColumn(works, works.doneQty);
        }
      }


      // v6 → v7 (검색 키 컬럼 + backfill)
      if (from < 7) {
        await m.addColumn(items, items.searchNormalized);
        await m.addColumn(items, items.searchInitials);
        await _backfillItemSearchKeys();
      }

      // v7 → v8 (재고브라우저용 full 검색키 컬럼 + backfill)
      if (from < 8) {
        await m.addColumn(items, items.searchFullNormalized);
        await _backfillItemFullSearchKeys();
      }
      // v8 → v9(재고 브라우저용 폴더 검색키 컬럼 +backfill)
      if (from < 9) {
        await m.alterTable(TableMigration(
          folders,
          newColumns: [
            folders.searchNormalized,
            folders.searchInitials,
          ],
        ));

        await _backfillFolderSearchKeys();
      }

      if (from < 10) {
        await m.alterTable(
          TableMigration(
            works,
            newColumns: [works.parentWorkId],
          ),
        );
      }
      if (from < 11) {
        await m.addColumn(items, items.defaultSupplierId as GeneratedColumn);
        await m.addColumn(items, items.defaultPrice as GeneratedColumn);

        await m.addColumn(purchaseOrders, purchaseOrders.supplierId as GeneratedColumn);
        await m.addColumn(purchaseOrders, purchaseOrders.shippingCost as GeneratedColumn);
        await m.addColumn(purchaseOrders, purchaseOrders.extraCost as GeneratedColumn);
        await m.addColumn(purchaseOrders, purchaseOrders.vat as GeneratedColumn);

        await m.addColumn(purchaseLines, purchaseLines.unitPrice as GeneratedColumn);
      }
      if (from < 12) {
        await m.addColumn(items, items.defaultPurchasePrice as GeneratedColumn);
        await m.addColumn(items, items.defaultSalePrice as GeneratedColumn);
      }


    },
  );Future<void> _backfillItemSearchKeys() async {
    final rows = await (select(items)
      ..where((t) => t.searchNormalized.equals('') | t.searchInitials.equals('')))
        .get();

    await transaction(() async {
      for (final r in rows) {
        final base = r.displayName?.trim().isNotEmpty == true
            ? r.displayName!
            : r.name;

        final normalized = normalizeForSearch(base);
        final initials = toChosungString(base);

        await (update(items)..where((t) => t.id.equals(r.id))).write(
          ItemsCompanion(
            searchNormalized: Value(normalized),
            searchInitials: Value(initials),
          ),
        );
      }
    });
  }
  Future<void> _backfillItemFullSearchKeys() async {
    final rows = await (select(items)
      ..where((t) => t.searchFullNormalized.equals('')))
        .get();

    await transaction(() async {
      for (final r in rows) {
        final baseName = (r.displayName?.trim().isNotEmpty == true)
            ? r.displayName!.trim()
            : r.name;

        // ✅ full 키: name + sku + folder names
        final src = [
          baseName,
          r.sku,
          r.folder,
          if (r.subfolder != null) r.subfolder!,
          if (r.subsubfolder != null) r.subsubfolder!,
        ].join(' ');

        final full = normalizeForSearch(src);

        await (update(items)..where((t) => t.id.equals(r.id))).write(
          ItemsCompanion(
            searchFullNormalized: Value(full),
          ),
        );
      }
    });
  }

  Future<void> _backfillFolderSearchKeys() async {
    final rows = await (select(folders)
      ..where((t) =>
      t.searchNormalized.equals('') | t.searchInitials.equals('')))
        .get();
    await transaction(() async {
    for (final r in rows) {
      final base = r.name.trim();
      final normalized = normalizeForSearch(base);
      final initials = toChosungString(base);

      await (update(folders)..where((t) => t.id.equals(r.id))).write(
        FoldersCompanion(
          searchNormalized: Value(normalized),
          searchInitials: Value(initials),
        ),
      );
    }
  });
        }


  Future<bool> _columnExists(String table, String column) async {
    final result = await customSelect(
      "PRAGMA table_info($table)",
    ).get();

    return result.any((row) => row.data['name'] == column);
  }
  Future<void> resetDatabase() async {
    final db = this;

    // DB 닫기
    await db.close();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');
    final file = File(dbPath);

    if (await file.exists()) {
      await file.delete();
    }

    // singleton 초기화
    _instance = null;
  }
}





/// 실제 SQLite 파일을 여는 부분
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');
    final file = File(dbPath);

    debugPrint("DB path: $dbPath");

    return NativeDatabase(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA busy_timeout = 5000;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
      },
    );
  });
}

/// =======================
///  Row ↔ 도메인 Item 변환
/// =======================

extension ItemRowMapping on ItemRow {
  Item toDomain() {
    Map<String, dynamic>? attrs;
    if (attrsJson != null && attrsJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(attrsJson!);
        if (decoded is Map<String, dynamic>) {
          attrs = decoded;
        } else if (decoded is Map) {
          attrs = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {/* ignore */}
    }

    StockHints? hints;
    if (stockHintsJson != null && stockHintsJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(stockHintsJson!);
        hints = StockHints.fromJson(decoded);
      } catch (_) {/* ignore */}
    }

    return Item(
      id: id,
      name: name,
      displayName: displayName,
      sku: sku,
      unit: unit,
      folder: folder,
      subfolder: subfolder,
      subsubfolder: subsubfolder,
      minQty: minQty,
      qty: qty,
      kind: kind,
      attrs: attrs,
      unitIn: unitIn,
      unitOut: unitOut,
      conversionRate: conversionRate,
      conversionMode: conversionMode,
      stockHints: hints,
      supplierName: supplierName,
      isFavorite: isFavorite,
      defaultPurchasePrice: defaultPurchasePrice,
      defaultSalePrice: defaultSalePrice,
    );
  }
}

extension ItemToCompanion on Item {
  ItemsCompanion toCompanion() {
    String? attrsJson;
    if (attrs != null && attrs!.isNotEmpty) {
      attrsJson = jsonEncode(attrs);
    }

    String? stockHintsJson;
    if (stockHints != null) {
      stockHintsJson = jsonEncode(stockHints!.toJson());
    }

    return ItemsCompanion(
      id: Value(id),
      name: Value(name),
      displayName: Value(displayName),
      sku: Value(sku),
      unit: Value(unit),
      folder: Value(folder),
      subfolder: Value(subfolder),
      subsubfolder: Value(subsubfolder),
      minQty: Value(minQty),
      qty: Value(qty),
      kind: Value(kind),
      attrsJson: Value(attrsJson),
      unitIn: Value(unitIn),
      unitOut: Value(unitOut),
      conversionRate: Value(conversionRate),
      conversionMode: Value(conversionMode),
      stockHintsJson: Value(stockHintsJson),
      supplierName: Value(supplierName),
      isFavorite: Value(isFavorite),
    );
  }
}

/// =======================
///  Row ↔ FolderNode
/// =======================

extension FolderRowMapping on FolderRow {
  FolderNode toDomain() => FolderNode(
    id: id,
    name: name,
    parentId: parentId,
    depth: depth,
    order: order,
  );
}

extension FolderNodeToCompanion on FolderNode {
  FoldersCompanion toCompanion() => FoldersCompanion(
    id: Value(id),
    name: Value(name),
    parentId: Value(parentId),
    depth: Value(depth),
    order: Value(order),
  );
}

/// =======================
///  Row ↔ Txn
/// =======================

extension TxnRowMapping on TxnRow {
  Txn toDomain() => Txn(
    id: id,
    ts: DateTime.parse(ts),
    type:
    TxnType.values.firstWhere((e) => e.name == type, orElse: () => TxnType.in_),
    status: TxnStatus.values
        .firstWhere((e) => e.name == status, orElse: () => TxnStatus.actual),
    itemId: itemId,
    qty: qty,
    refType: RefType.values
        .firstWhere((e) => e.name == refType, orElse: () => RefType.order),
    refId: refId,
    note: note,
    memo: memo,
    sourceKey: sourceKey,
  );
}

extension TxnToCompanion on Txn {
  TxnsCompanion toCompanion() => TxnsCompanion(
    id: Value(id),
    ts: Value(ts.toIso8601String()),
    type: Value(type.name),
    status: Value(status.name),
    itemId: Value(itemId),
    qty: Value(qty),
    refType: Value(refType.name),
    refId: Value(refId),
    note: Value(note),
    memo: Value(memo),
    sourceKey: Value(sourceKey),
  );
}

/// =======================
///  Row ↔ BomRow
/// =======================

extension BomRowDbMapping on BomRowDb {
  BomRow toDomain() => BomRow(
    root: BomRootX.fromString(root),
    parentItemId: parentItemId,
    componentItemId: componentItemId,
    kind: BomKindX.fromString(kind),
    qtyPer: qtyPer,
    wastePct: wastePct,
  );
}

extension BomRowToCompanion on BomRow {
  BomRowsCompanion toCompanion() => BomRowsCompanion(
    root: Value(root.name),
    parentItemId: Value(parentItemId),
    componentItemId: Value(componentItemId),
    kind: Value(kind.name),
    qtyPer: Value(qtyPer),
    wastePct: Value(wastePct),
  );
}

/// =======================
///  Row ↔ Order / OrderLine
/// =======================

extension OrderRowMappingExt on OrderRow {
  Order toDomain(List<OrderLine> lines) => Order(
    id: id,
    date: DateTime.parse(date),
    customer: customer,
    memo: memo,
    status: OrderStatus.values.firstWhere(
          (e) => e.name == status,
      orElse: () => OrderStatus.draft,
    ),
    lines: lines,
    isDeleted: isDeleted,
    updatedAt: updatedAt != null ? DateTime.parse(updatedAt!) : null,
    deletedAt: deletedAt != null ? DateTime.parse(deletedAt!) : null,

  );
}

extension OrderLineRowMapping on OrderLineRow {
  OrderLine toDomain() => OrderLine(
    id: id,
    itemId: itemId,
    qty: qty,
  );
}

extension OrderLineToCompanion on OrderLine {
  OrderLinesCompanion toCompanion(String orderId) => OrderLinesCompanion(
    id: Value(id),
    orderId: Value(orderId),
    itemId: Value(itemId),
    qty: Value(qty),
  );
}

extension OrderToCompanion on Order {
  OrdersCompanion toCompanion() => OrdersCompanion(
    id: Value(id),
    date: Value(date.toIso8601String()),
    customer: Value(customer),
    memo: Value(memo),
    status: Value(status.name),
    isDeleted: Value(isDeleted),
    updatedAt: Value(updatedAt.toIso8601String()),
    deletedAt: Value(deletedAt?.toIso8601String()),
  );
}


/// =======================
///  Row ↔ Work
/// =======================

extension WorkRowMapping on WorkRow {
  Work toDomain() => Work(
    id: id,
    itemId: itemId,
    qty: qty,
    doneQty: doneQty, // ✅ 추가
    orderId: orderId,
    status: WorkStatus.values.firstWhere(
          (e) => e.name == status,
      orElse: () => WorkStatus.planned,
    ),
    createdAt: DateTime.parse(createdAt),
    updatedAt: updatedAt != null ? DateTime.parse(updatedAt!) : null,
    isDeleted: isDeleted,
    sourceKey: sourceKey,
    startedAt: startedAt != null ? DateTime.parse(startedAt!) : null,   // ✅ 보완
    finishedAt: finishedAt != null ? DateTime.parse(finishedAt!) : null, // ✅ 보완
  );
}

extension WorkToCompanion on Work {
  WorksCompanion toCompanion() => WorksCompanion(
    id: Value(id),
    itemId: Value(itemId),
    qty: Value(qty),
    orderId: Value(orderId),
    parentWorkId: parentWorkId == null ? const Value.absent() : Value(parentWorkId!),
    status: Value(status.name),
    createdAt: Value(createdAt.toIso8601String()),
    updatedAt: Value(updatedAt?.toIso8601String()),
    isDeleted: Value(isDeleted),
    sourceKey: Value(sourceKey),
    startedAt: Value(startedAt?.toIso8601String()),   // ✅ 보완
    finishedAt: Value(finishedAt?.toIso8601String()),
  );
}

/// =======================
///  Row ↔ PurchaseOrder / PurchaseLine
/// =======================

extension PurchaseOrderRowMapping on PurchaseOrderRow {
  PurchaseOrder toDomain() => PurchaseOrder(
    id: id,
    supplierName: supplierName,
    eta: DateTime.parse(eta),
    status: PurchaseOrderStatus.values.firstWhere(
          (e) => e.name == status,
      orElse: () => PurchaseOrderStatus.draft,
    ),
    createdAt: DateTime.parse(createdAt),
    updatedAt: DateTime.parse(updatedAt),
    isDeleted: isDeleted,
    memo: memo,
  );
}

extension PurchaseOrderToCompanion on PurchaseOrder {
  PurchaseOrdersCompanion toCompanion() => PurchaseOrdersCompanion(
    id: Value(id),
    supplierName: Value(supplierName),
    eta: Value(eta.toIso8601String()),
    status: Value(status.name),
    createdAt: Value(createdAt.toIso8601String()),
    updatedAt: Value(updatedAt.toIso8601String()),
    isDeleted: Value(isDeleted),
    memo: Value(memo),
  );
}

extension PurchaseLineRowMapping on PurchaseLineRow {
  PurchaseLine toDomain() => PurchaseLine(
    id: id,
    orderId: orderId,
    itemId: itemId,
    name: name,
    unit: unit,
    qty: qty,
    note: note,
    memo: memo,
    colorNo: colorNo,
    unitPrice: 0,
  );
}

extension PurchaseLineToCompanionExt on PurchaseLine {
  PurchaseLinesCompanion toCompanion() => PurchaseLinesCompanion(
    id: Value(id),
    orderId: Value(orderId),
    itemId: Value(itemId),
    name: Value(name),
    unit: Value(unit),
    qty: Value(qty),
    note: Value(note),
    memo: Value(memo),
    colorNo: Value(colorNo),
  );
}

/// =======================
///  Row ↔ Supplier
/// =======================

extension SupplierRowMapping on SupplierRow {
  Supplier toDomain() => Supplier(
    id: id,
    name: name,
    contactName: contactName,
    phone: phone,
    email: email,
    addr: addr,
    memo: memo,
    isActive: isActive,
    createdAt: DateTime.parse(createdAt),
    updatedAt: DateTime.parse(updatedAt),
  );
}

extension SupplierToCompanion on Supplier {
  SuppliersCompanion toCompanion() => SuppliersCompanion(
    id: Value(id),
    name: Value(name),
    contactName: Value(contactName),
    phone: Value(phone),
    email: Value(email),
    addr: Value(addr),
    memo: Value(memo),
    isActive: Value(isActive),
    createdAt: Value(createdAt.toIso8601String()),
    updatedAt: Value(updatedAt.toIso8601String()),
  );
}

/// =======================
///  Row ↔ Lot
/// =======================

extension LotRowMapping on LotRow {
  Lot toDomain() => Lot(
    //id: id,
    itemId: itemId,
    lotNo: lotNo,
    receivedQtyRoll: receivedQtyRoll,
    measuredLengthM: measuredLengthM,
    usableQtyM: usableQtyM,
    status: status,
    receivedAt: DateTime.parse(receivedAt),
  );
}

extension LotToCompanion on Lot {
  LotsCompanion toCompanion() => LotsCompanion(
    //id: Value(id),
    itemId: Value(itemId),
    lotNo: Value(lotNo),
    receivedQtyRoll: Value(receivedQtyRoll),
    measuredLengthM: Value(measuredLengthM),
    usableQtyM: Value(usableQtyM),
    status: Value(status),
    receivedAt: Value(receivedAt.toIso8601String()),
  );
}
