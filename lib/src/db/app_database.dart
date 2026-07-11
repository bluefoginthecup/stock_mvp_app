// lib/src/db/app_database.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
import '../models/quote.dart';
import '../models/quote_line.dart';
import '../models/app_schedule.dart';
import '../models/suppliers.dart';
import '../models/lot.dart';
import '../models/types.dart';
import '../services/app_path_service.dart';
import '../utils/korean_search.dart';

// drift가 생성해줄 파일
part 'app_database.g.dart';

/// =======================
///  Items 테이블 정의
/// =======================

@DataClassName('ItemRow') // 도메인 Item과 이름 충돌 방지
class Items extends Table {
  TextColumn get id => text()(); // it_xxx
  TextColumn get name => text()(); // name
  TextColumn get displayName => text().nullable()();
  TextColumn get sku => text()();
  TextColumn get unit => text()(); // EA, SET, ROLL...
  TextColumn get searchNormalized => text().withDefault(const Constant(''))();
  TextColumn get searchInitials => text().withDefault(const Constant(''))();
  TextColumn get searchFullNormalized =>
      text().withDefault(const Constant(''))();

  // 레거시 폴더 필드
  TextColumn get folder => text()(); // 레거시 L1
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
      real().withDefault(const Constant(1.0))(); // 1 unitIn = rate * unitOut
  TextColumn get conversionMode =>
      text().withDefault(const Constant('fixed'))(); // fixed | lot

  // stockHints도 JSON으로 보관 (레거시 폴백용)
  TextColumn get stockHintsJson => text().nullable()();

  // 거래처
  TextColumn get supplierName => text().nullable()();
  IntColumn get defaultSupplierId => integer().nullable()();
  TextColumn get defaultSupplierUid => text().nullable()();
  RealColumn get defaultPrice => real().nullable()();
  RealColumn get defaultPurchasePrice => real().nullable()();
  RealColumn get defaultSalePrice => real().nullable()();

  // 정기 발주/발주 알림. nullable로 두고 도메인 모델에서 기본값을 보정해
  // 기존 DB와 hot reload 중간 상태에서도 안전하게 읽는다.
  IntColumn get reorderIntervalDays => integer().nullable()();
  TextColumn get lastOrderedAt => text().nullable()();
  TextColumn get nextReorderDate => text().nullable()();
  BoolColumn get reorderReminderEnabled => boolean().nullable()();
  IntColumn get reorderReminderDaysBefore => integer().nullable()();

  //즐겨찾기
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601

  // 🔥 추가 (복구용 스냅샷)
  TextColumn get extra => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
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
  TextColumn get parentId =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  IntColumn get depth => integer()(); // 1,2,3
  IntColumn get order => integer().withDefault(const Constant(0))(); // 형제 순서

  // ✅ 검색 키
  TextColumn get searchNormalized => text().withDefault(const Constant(''))();
  TextColumn get searchInitials => text().withDefault(const Constant(''))();
  // 휴지통 관련
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()();

// 🔥 추가 (복구용 스냅샷)
  TextColumn get extra => text().nullable()();

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
  TextColumn get refId => text()(); // 원본 id

  TextColumn get note => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get sourceKey => text().nullable()();
  IntColumn get beforeQty => integer().nullable()();
  IntColumn get afterQty => integer().nullable()();
  RealColumn get unitPrice => real().nullable()();
  TextColumn get reason => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601

  @override
  Set<Column> get primaryKey => {id};
  List<Index> get indexes => [
        Index('idx_txn_item', 'itemId'),
        Index('idx_txn_ts', 'ts'),
      ];
}

/// =======================
///  ItemPriceHistories (입고가/출고가 변경 이력)
/// =======================

@DataClassName('ItemPriceHistoryRow')
class ItemPriceHistories extends Table {
  TextColumn get id => text()();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()(); // purchase | sale
  TextColumn get changedAt => text()(); // ISO8601
  RealColumn get oldPrice => real().nullable()();
  RealColumn get newPrice => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceRefType => text().nullable()();
  TextColumn get sourceRefId => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  List<Index> get indexes => [
        Index(
            'idx_item_price_history_item_kind_date', 'itemId, kind, changedAt'),
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
  RealColumn get wastePct => real().withDefault(const Constant(0.0))(); // 0..1

  @override
  Set<Column> get primaryKey => {root, parentItemId, componentItemId, kind};
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
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text().nullable()(); // ISO8601
  TextColumn get deletedAt => text().nullable()(); // ISO8601
  // ✅ 신규
  TextColumn get shippedAt => text().nullable()(); // 실제 출고(완료)일
  TextColumn get dueDate => text().nullable()(); // 납기(출고 예정)일

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
  IntColumn get doneQty => integer().withDefault(const Constant(0))(); // >= 0

  TextColumn get orderId =>
      text().nullable().references(Orders, #id, onDelete: KeyAction.setNull)();
  //부모 작업
  TextColumn get parentWorkId => text().nullable()();

  TextColumn get status => text()(); // WorkStatus.name
  TextColumn get createdAt => text()(); // ISO8601
  TextColumn get updatedAt => text().nullable()(); // ISO8601
  TextColumn get sourceKey => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601

  TextColumn get startedAt => text().nullable()(); // 작업 시작(ISO8601)
  TextColumn get finishedAt => text().nullable()(); // 작업 완료(ISO8601)

  @override
  Set<Column> get primaryKey => {id};
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
  TextColumn get supplierId => text().nullable()();

  RealColumn get shippingCost => real().withDefault(const Constant(0))();
  RealColumn get extraCost => real().withDefault(const Constant(0))();
  RealColumn get vat => real().withDefault(const Constant(0))();
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('pending'))(); //결제여부
  TextColumn get paidAt => text().nullable()(); //결제일
  TextColumn get paymentDueAt => text().nullable()();
  TextColumn get vatInvoiceStatus =>
      text().withDefault(const Constant('pending'))(); //
  TextColumn get vatInvoiceIssuedAt => text().nullable()();
  TextColumn get vatInvoiceDueAt => text().nullable()();
  BoolColumn get vatIncluded => boolean().withDefault(const Constant(false))();
  IntColumn get vatType => integer().withDefault(const Constant(0))();
  TextColumn get eta => text()(); // ISO8601
  TextColumn get status => text()(); // PurchaseOrderStatus.name
  TextColumn get createdAt => text()(); // ISO8601
  TextColumn get updatedAt => text()(); // ISO8601
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get memo => text().nullable()();
  TextColumn get deliveryName => text().nullable()();
  TextColumn get deliveryAddress => text().nullable()();
  TextColumn get deliveryPhone => text().nullable()();
  TextColumn get deliveryMemo => text().nullable()();
  BoolColumn get showDeliveryOnPrint =>
      boolean().withDefault(const Constant(false))();
  TextColumn get shippingDestinationId => text().nullable()();
  IntColumn get buyerProfileId => integer().nullable()();
  TextColumn get buyerProfileName => text().nullable()();
  TextColumn get buyerBusinessNumber => text().nullable()();
  TextColumn get buyerCompanyName => text().nullable()();
  TextColumn get buyerRepresentative => text().nullable()();
  TextColumn get buyerAddress => text().nullable()();
  TextColumn get buyerBusinessType => text().nullable()();
  TextColumn get buyerBusinessItem => text().nullable()();
  TextColumn get buyerPhoneFax => text().nullable()();
  TextColumn get deletedAt => text().nullable()(); // ISO8601
  // 🔥 신규 컬럼 2개 (주문 연동/입고일)
  TextColumn get orderId => text().nullable()(); // 주문 연동 발주면 채움
  TextColumn get receivedAt =>
      text().nullable()(); // 실제 입고 완료일 (ISO8601 string)

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
  IntColumn get vatType => integer().withDefault(const Constant(0))();
  RealColumn get supplyAmount => real().withDefault(const Constant(0))();
  RealColumn get vatAmount => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  BoolColumn get amountEdited => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get colorNo => text().nullable()();
  TextColumn get printAttrsJson => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()(); // ISO8601

  @override
  Set<Column> get primaryKey => {id};
  List<Index> get indexes => [
        Index('idx_purchase_order', 'orderId'),
        Index('idx_purchase_item', 'itemId'),
      ];
}

/// =======================
///  Quotes / QuoteLines
/// =======================

@DataClassName('QuoteRow')
class Quotes extends Table {
  TextColumn get id => text()();
  TextColumn get customerName => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get quoteDate => text()();
  TextColumn get validUntil => text().nullable()();
  TextColumn get status => text()();
  TextColumn get memo => text().nullable()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get shippingCost => real().withDefault(const Constant(0))();
  IntColumn get vatType => integer().withDefault(const Constant(0))();
  IntColumn get supplierProfileId => integer().nullable()();
  TextColumn get supplierProfileName => text().nullable()();
  TextColumn get supplierBusinessNumber => text().nullable()();
  TextColumn get supplierCompanyName => text().nullable()();
  TextColumn get supplierRepresentative => text().nullable()();
  TextColumn get supplierAddress => text().nullable()();
  TextColumn get supplierBusinessType => text().nullable()();
  TextColumn get supplierBusinessItem => text().nullable()();
  TextColumn get supplierPhoneFax => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QuoteLineRow')
class QuoteLines extends Table {
  TextColumn get id => text()();
  TextColumn get quoteId =>
      text().references(Quotes, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  TextColumn get unit => text()();
  RealColumn get qty => real()();
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  IntColumn get vatType => integer().withDefault(const Constant(0))();
  RealColumn get supplyAmount => real().withDefault(const Constant(0))();
  RealColumn get vatAmount => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  BoolColumn get amountEdited => boolean().withDefault(const Constant(false))();
  TextColumn get memo => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_quote_lines_quote', 'quoteId'),
        Index('idx_quote_lines_item', 'itemId'),
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
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()(); // ISO8601
  TextColumn get updatedAt => text()(); // ISO8601

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShippingDestinationRow')
class ShippingDestinations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get contactName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get mapImagePath => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SupplierShippingDestinationRow')
class SupplierShippingDestinations extends Table {
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  TextColumn get shippingDestinationId => text().references(
        ShippingDestinations,
        #id,
        onDelete: KeyAction.cascade,
      )();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {supplierId, shippingDestinationId};
}

@DataClassName('StorageLocationRow')
class StorageLocations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text()
      .nullable()
      .references(StorageLocations, #id, onDelete: KeyAction.setNull)();
  TextColumn get type => text()();
  TextColumn get memo => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ItemLocationRow')
class ItemLocations extends Table {
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get locationId => text().references(
        StorageLocations,
        #id,
        onDelete: KeyAction.cascade,
      )();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get memo => text().nullable()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {itemId, locationId};
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
///  Memos (대시보드 메모)
/// =======================

@DataClassName('MemoRow')
class Memos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// =======================
///  AppSchedules (일정/할일)
/// =======================

@DataClassName('AppScheduleRow')
class AppSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get tagsJson => text().nullable()();
  TextColumn get date => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  BoolColumn get isPinned => boolean().nullable()();
  IntColumn get sourceMemoId => integer()
      .nullable()
      .references(Memos, #id, onDelete: KeyAction.setNull)();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_app_schedules_date', 'date'),
        Index('idx_app_schedules_status', 'status'),
        Index('idx_app_schedules_source_memo', 'sourceMemoId'),
      ];
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
    ItemPriceHistories,
    Quotes,
    QuoteLines,
    Suppliers,
    ShippingDestinations,
    SupplierShippingDestinations,
    StorageLocations,
    ItemLocations,
    Lots,
    Memos,
    AppSchedules,
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
  int get schemaVersion => 46; //

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureSupplierBusinessColumns();
          await _ensureSupplierRoleColumns();
          await _ensureSupplierContactsTable();
          await _ensureSupplierAccountsTable();
          await _ensurePurchaseReceiptsTable();
          await _ensureBuyerProfilesTable();
          await _ensureShippingDestinationTables();
          await _ensureStorageLocationTables();
          await _ensureStorageLocationMovementTable();
          await _ensureScheduleAttachmentsTable();
          await _ensureItemImagesTable();
          await _ensureProductionGuideTables();
        },
        beforeOpen: (details) async {
          await _ensureSupplierRoleColumns();
          await _ensurePurchaseLineAmountColumns();
          await _ensureQuoteLineAmountColumns();
          await _ensureStorageLocationMovementTable();
          await _ensureItemLocationQuantityColumn();
          await _ensureProductionGuideTables();
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
                purchaseOrders.orderId, // nullable
                purchaseOrders.receivedAt, // nullable
              ],
            ));

            // 2) 작업: 시작/완료일
            await m.alterTable(TableMigration(
              works,
              newColumns: [
                works.startedAt, // nullable
                works.finishedAt, // nullable
              ],
            ));

            // 3) 주문: 출고(완료)일 / 납기일
            await m.alterTable(TableMigration(
              orders,
              newColumns: [
                orders.shippedAt, // nullable
                orders.dueDate, // nullable
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
            await m.addColumn(
                items, items.defaultSupplierId as GeneratedColumn);
            await m.addColumn(items, items.defaultPrice as GeneratedColumn);

            await m.addColumn(
                purchaseOrders, purchaseOrders.supplierId as GeneratedColumn);
            await m.addColumn(
                purchaseOrders, purchaseOrders.shippingCost as GeneratedColumn);
            await m.addColumn(
                purchaseOrders, purchaseOrders.extraCost as GeneratedColumn);
            await m.addColumn(
                purchaseOrders, purchaseOrders.vat as GeneratedColumn);

            await m.addColumn(
                purchaseLines, purchaseLines.unitPrice as GeneratedColumn);
          }
          if (from < 12) {
            await m.addColumn(
                items, items.defaultPurchasePrice as GeneratedColumn);
            await m.addColumn(items, items.defaultSalePrice as GeneratedColumn);
          }
          if (from < 13) {
            await m.addColumn(
                purchaseOrders, purchaseOrders.vatIncluded as GeneratedColumn);
            await m.addColumn(purchaseOrders,
                purchaseOrders.paymentStatus as GeneratedColumn);
            await m.addColumn(
                purchaseOrders, purchaseOrders.paidAt as GeneratedColumn);
            await m.addColumn(purchaseOrders,
                purchaseOrders.vatInvoiceStatus as GeneratedColumn);
            await m.addColumn(purchaseOrders,
                purchaseOrders.vatInvoiceIssuedAt as GeneratedColumn);
          }
          if (from < 14) {
            await m.addColumn(purchaseOrders, purchaseOrders.vatType);
          }
          if (from < 15) {
            await customStatement(
                'ALTER TABLE purchase_orders ADD COLUMN payment_due_at TEXT');

            await customStatement(
                'ALTER TABLE purchase_orders ADD COLUMN vat_invoice_due_at TEXT');
          }
          if (from < 16) {
            await m.alterTable(TableMigration(
              folders,
              newColumns: [folders.isDeleted, folders.deletedAt],
            ));
          }

          if (from < 17) {
            final exists = await _columnExists('items', 'extra');
            if (!exists) {
              await m.addColumn(items, items.extra);
            }

            final exists2 = await _columnExists('folders', 'extra');
            if (!exists2) {
              await m.addColumn(folders, folders.extra);
            }
          }
          if (from < 18) {
            await m.createTable(memos);
          }
          if (from < 19) {
            // supplier_id used to be declared INTEGER. Existing rows are mostly
            // null/name-only, and SQLite can store UUID text in the existing
            // column, so no destructive table rewrite is required here.
          }
          if (from < 20) {
            await _ensureSupplierBusinessColumns();
            await _ensureSupplierContactsTable();
          }
          if (from < 21) {
            await _ensureSupplierAccountsTable();
          }
          if (from < 22) {
            await _ensurePurchaseReceiptsTable();
          }
          if (from < 23) {
            final exists =
                await _columnExists('purchase_lines', 'print_attrs_json');
            if (!exists) {
              await m.addColumn(purchaseLines, purchaseLines.printAttrsJson);
            }
          }
          if (from < 24) {
            await _addColumnIfMissing(
                'purchase_orders', 'delivery_name', 'TEXT');
            await _addColumnIfMissing(
                'purchase_orders', 'delivery_address', 'TEXT');
            await _addColumnIfMissing(
                'purchase_orders', 'delivery_phone', 'TEXT');
            await _addColumnIfMissing(
                'purchase_orders', 'delivery_memo', 'TEXT');
            await _addColumnIfMissing('purchase_orders',
                'show_delivery_on_print', 'INTEGER NOT NULL DEFAULT 0');
          }
          if (from < 25) {
            await _ensureBuyerProfilesTable();
          }
          if (from < 26) {
            await _ensurePurchaseOrderBuyerSnapshotColumns();
          }
          if (from < 27) {
            await m.createTable(quotes);
            await m.createTable(quoteLines);
          }
          if (from < 28) {
            await _addColumnIfMissing(
                'quotes', 'supplier_profile_id', 'INTEGER');
            await _addColumnIfMissing(
                'quotes', 'supplier_profile_name', 'TEXT');
            await _addColumnIfMissing(
                'quotes', 'supplier_business_number', 'TEXT');
            await _addColumnIfMissing(
                'quotes', 'supplier_company_name', 'TEXT');
            await _addColumnIfMissing(
                'quotes', 'supplier_representative', 'TEXT');
            await _addColumnIfMissing('quotes', 'supplier_address', 'TEXT');
            await _addColumnIfMissing(
                'quotes', 'supplier_business_type', 'TEXT');
            await _addColumnIfMissing(
                'quotes', 'supplier_business_item', 'TEXT');
            await _addColumnIfMissing('quotes', 'supplier_phone_fax', 'TEXT');
          }
          if (from < 29) {
            await m.createTable(appSchedules);
          }
          if (from < 30) {
            await _ensureShippingDestinationTables();
            await _addColumnIfMissing(
                'purchase_orders', 'shipping_destination_id', 'TEXT');
          }
          if (from < 31) {
            await _ensureStorageLocationTables();
          }
          if (from < 32) {
            await _ensureScheduleAttachmentsTable();
          }
          if (from < 33) {
            await _ensureItemImagesTable();
          }
          if (from < 34) {
            await _addColumnIfMissing('app_schedules', 'tags_json', 'TEXT');
            await _addColumnIfMissing('app_schedules', 'is_pinned', 'INTEGER');
          }
          if (from < 35) {
            await _addColumnIfMissing(
                'items', 'reorder_interval_days', 'INTEGER');
            await _addColumnIfMissing('items', 'last_ordered_at', 'TEXT');
            await _addColumnIfMissing('items', 'next_reorder_date', 'TEXT');
            await _addColumnIfMissing(
                'items', 'reorder_reminder_enabled', 'INTEGER');
            await _addColumnIfMissing(
                'items', 'reorder_reminder_days_before', 'INTEGER');
          }
          if (from < 36) {
            await _addColumnIfMissing('items', 'default_supplier_uid', 'TEXT');
          }
          if (from < 37) {
            await _ensurePurchaseLineAmountColumns();
            await _backfillPurchaseLineAmounts();
          }
          if (from < 38) {
            await _ensureQuoteLineAmountColumns();
            await _backfillQuoteLineAmounts();
          }
          if (from < 39) {
            await _ensureStorageLocationMovementTable();
          }
          if (from < 40) {
            await _ensureItemLocationQuantityColumn(backfill: true);
          }
          if (from < 41) {
            await _addColumnIfMissing('txns', 'before_qty', 'INTEGER');
            await _addColumnIfMissing('txns', 'after_qty', 'INTEGER');
            await _addColumnIfMissing('txns', 'unit_price', 'REAL');
            await _addColumnIfMissing('txns', 'reason', 'TEXT');
          }
          if (from < 42) {
            await m.createTable(itemPriceHistories);
          }
          if (from < 43) {
            await _addColumnIfMissing(
                'item_price_histories', 'source_ref_type', 'TEXT');
            await _addColumnIfMissing(
                'item_price_histories', 'source_ref_id', 'TEXT');
          }
          if (from < 44) {
            await _ensureProductionGuideTables();
          }
          if (from < 45) {
            await _ensureProductionGuideTables();
          }
          if (from < 46) {
            await _ensureSupplierRoleColumns();
          }
        },
      );
  Future<void> _backfillItemSearchKeys() async {
    final rows = await (select(items)
          ..where((t) =>
              t.searchNormalized.equals('') | t.searchInitials.equals('')))
        .get();

    await transaction(() async {
      for (final r in rows) {
        final base =
            r.displayName?.trim().isNotEmpty == true ? r.displayName! : r.name;

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

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String definition,
  ) async {
    if (await _columnExists(table, column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _ensurePurchaseLineAmountColumns() async {
    await _addColumnIfMissing(
        'purchase_lines', 'vat_type', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'purchase_lines', 'supply_amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'purchase_lines', 'vat_amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'purchase_lines', 'total_amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'purchase_lines', 'amount_edited', 'INTEGER NOT NULL DEFAULT 0');
  }

  Future<void> _backfillPurchaseLineAmounts() async {
    await customStatement('''
      UPDATE purchase_lines
      SET
        vat_type = COALESCE(
          (SELECT po.vat_type FROM purchase_orders po WHERE po.id = purchase_lines.order_id),
          0
        ),
        supply_amount = CASE COALESCE(
          (SELECT po.vat_type FROM purchase_orders po WHERE po.id = purchase_lines.order_id),
          0
        )
          WHEN 1 THEN ROUND((unit_price * qty) - ROUND((unit_price * qty) / 11.0))
          ELSE ROUND(unit_price * qty)
        END,
        vat_amount = CASE COALESCE(
          (SELECT po.vat_type FROM purchase_orders po WHERE po.id = purchase_lines.order_id),
          0
        )
          WHEN 0 THEN ROUND((unit_price * qty) * 0.1)
          WHEN 1 THEN ROUND((unit_price * qty) / 11.0)
          ELSE 0
        END,
        total_amount = CASE COALESCE(
          (SELECT po.vat_type FROM purchase_orders po WHERE po.id = purchase_lines.order_id),
          0
        )
          WHEN 0 THEN ROUND(unit_price * qty) + ROUND((unit_price * qty) * 0.1)
          ELSE ROUND(unit_price * qty)
        END
      WHERE amount_edited = 0
    ''');
  }

  Future<void> _ensureQuoteLineAmountColumns() async {
    await _addColumnIfMissing(
        'quote_lines', 'vat_type', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'quote_lines', 'supply_amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'quote_lines', 'vat_amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'quote_lines', 'total_amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        'quote_lines', 'amount_edited', 'INTEGER NOT NULL DEFAULT 0');
  }

  Future<void> _backfillQuoteLineAmounts() async {
    await customStatement('''
      UPDATE quote_lines
      SET
        vat_type = COALESCE(
          (SELECT q.vat_type FROM quotes q WHERE q.id = quote_lines.quote_id),
          0
        ),
        supply_amount = CASE COALESCE(
          (SELECT q.vat_type FROM quotes q WHERE q.id = quote_lines.quote_id),
          0
        )
          WHEN 1 THEN ROUND((unit_price * qty) - ROUND((unit_price * qty) / 11.0))
          ELSE ROUND(unit_price * qty)
        END,
        vat_amount = CASE COALESCE(
          (SELECT q.vat_type FROM quotes q WHERE q.id = quote_lines.quote_id),
          0
        )
          WHEN 0 THEN ROUND((unit_price * qty) * 0.1)
          WHEN 1 THEN ROUND((unit_price * qty) / 11.0)
          ELSE 0
        END,
        total_amount = CASE COALESCE(
          (SELECT q.vat_type FROM quotes q WHERE q.id = quote_lines.quote_id),
          0
        )
          WHEN 0 THEN ROUND(unit_price * qty) + ROUND((unit_price * qty) * 0.1)
          ELSE ROUND(unit_price * qty)
        END
      WHERE amount_edited = 0
    ''');
  }

  Future<void> _ensureSupplierBusinessColumns() async {
    await _addColumnIfMissing('suppliers', 'fax', 'TEXT');
    await _addColumnIfMissing('suppliers', 'business_number', 'TEXT');
    await _addColumnIfMissing('suppliers', 'representative', 'TEXT');
    await _addColumnIfMissing('suppliers', 'business_type', 'TEXT');
    await _addColumnIfMissing('suppliers', 'business_item', 'TEXT');
  }

  Future<void> _ensureSupplierRoleColumns() async {
    await _addColumnIfMissing(
      'suppliers',
      'is_purchase_supplier',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      'suppliers',
      'is_customer',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _ensureSupplierContactsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS supplier_contacts (
        id TEXT PRIMARY KEY NOT NULL,
        supplier_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role_or_memo TEXT NULL,
        phone TEXT NULL,
        fax TEXT NULL,
        email TEXT NULL,
        address TEXT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_supplier_contacts_supplier '
      'ON supplier_contacts(supplier_id, sort_order)',
    );
  }

  Future<void> _ensureBuyerProfilesTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS buyer_profiles (
        id INTEGER PRIMARY KEY NOT NULL,
        profile_name TEXT NOT NULL DEFAULT '',
        business_number TEXT NOT NULL DEFAULT '',
        company_name TEXT NOT NULL DEFAULT '',
        representative TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        business_type TEXT NOT NULL DEFAULT '',
        business_item TEXT NOT NULL DEFAULT '',
        phone_fax TEXT NOT NULL DEFAULT '',
        is_default INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensurePurchaseOrderBuyerSnapshotColumns() async {
    await _addColumnIfMissing('purchase_orders', 'buyer_profile_id', 'INTEGER');
    await _addColumnIfMissing('purchase_orders', 'buyer_profile_name', 'TEXT');
    await _addColumnIfMissing(
        'purchase_orders', 'buyer_business_number', 'TEXT');
    await _addColumnIfMissing('purchase_orders', 'buyer_company_name', 'TEXT');
    await _addColumnIfMissing(
        'purchase_orders', 'buyer_representative', 'TEXT');
    await _addColumnIfMissing('purchase_orders', 'buyer_address', 'TEXT');
    await _addColumnIfMissing('purchase_orders', 'buyer_business_type', 'TEXT');
    await _addColumnIfMissing('purchase_orders', 'buyer_business_item', 'TEXT');
    await _addColumnIfMissing('purchase_orders', 'buyer_phone_fax', 'TEXT');
  }

  Future<void> _ensureSupplierAccountsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS supplier_accounts (
        id TEXT PRIMARY KEY NOT NULL,
        supplier_id TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL,
        account_holder TEXT NULL,
        memo TEXT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_supplier_accounts_supplier '
      'ON supplier_accounts(supplier_id, sort_order)',
    );
  }

  Future<void> _ensureShippingDestinationTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shipping_destinations (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        contact_name TEXT NULL,
        phone TEXT NULL,
        memo TEXT NULL,
        map_image_path TEXT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS supplier_shipping_destinations (
        supplier_id TEXT NOT NULL,
        shipping_destination_id TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (supplier_id, shipping_destination_id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
        FOREIGN KEY (shipping_destination_id) REFERENCES shipping_destinations(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_supplier_shipping_supplier
      ON supplier_shipping_destinations(supplier_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_supplier_shipping_destination
      ON supplier_shipping_destinations(shipping_destination_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_supplier_shipping_default
      ON supplier_shipping_destinations(supplier_id, is_default)
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_one_default_destination
      ON supplier_shipping_destinations(supplier_id)
      WHERE is_default = 1
    ''');
  }

  Future<void> _ensureStorageLocationTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS storage_locations (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        parent_id TEXT NULL,
        type TEXT NOT NULL,
        memo TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES storage_locations(id) ON DELETE SET NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_locations (
        item_id TEXT NOT NULL,
        location_id TEXT NOT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0,
        qty INTEGER NOT NULL DEFAULT 0,
        memo TEXT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (item_id, location_id),
        FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
        FOREIGN KEY (location_id) REFERENCES storage_locations(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_storage_locations_parent
      ON storage_locations(parent_id, sort_order)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_storage_locations_name
      ON storage_locations(name)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_item_locations_item
      ON item_locations(item_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_item_locations_location
      ON item_locations(location_id)
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_item_one_primary_location
      ON item_locations(item_id)
      WHERE is_primary = 1
    ''');
    await _ensureItemLocationQuantityColumn();
  }

  Future<void> _ensureItemLocationQuantityColumn({
    bool backfill = false,
  }) async {
    await _addColumnIfMissing(
      'item_locations',
      'qty',
      'INTEGER NOT NULL DEFAULT 0',
    );
    if (!backfill) return;

    await customStatement('''
      UPDATE item_locations
      SET qty = COALESCE(
        (SELECT items.qty FROM items WHERE items.id = item_locations.item_id),
        0
      )
      WHERE qty = 0
        AND is_primary = 1
    ''');
    await customStatement('''
      UPDATE item_locations
      SET qty = COALESCE(
        (SELECT items.qty FROM items WHERE items.id = item_locations.item_id),
        0
      )
      WHERE qty = 0
        AND (
          SELECT COUNT(*)
          FROM item_locations il2
          WHERE il2.item_id = item_locations.item_id
        ) = 1
    ''');
  }

  Future<void> _ensureStorageLocationMovementTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS storage_location_movements (
        id TEXT PRIMARY KEY NOT NULL,
        item_id TEXT NOT NULL,
        item_name TEXT NOT NULL DEFAULT '',
        from_location_id TEXT NULL,
        from_location_path TEXT NULL,
        to_location_id TEXT NOT NULL,
        to_location_path TEXT NOT NULL,
        memo TEXT NULL,
        moved_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
        FOREIGN KEY (from_location_id) REFERENCES storage_locations(id) ON DELETE SET NULL,
        FOREIGN KEY (to_location_id) REFERENCES storage_locations(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_storage_movements_item
      ON storage_location_movements(item_id, moved_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_storage_movements_from
      ON storage_location_movements(from_location_id, moved_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_storage_movements_to
      ON storage_location_movements(to_location_id, moved_at)
    ''');
  }

  Future<void> _ensurePurchaseReceiptsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS purchase_receipts (
        id TEXT PRIMARY KEY NOT NULL,
        purchase_order_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        memo TEXT NULL,
        FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_purchase_receipts_order '
      'ON purchase_receipts(purchase_order_id, created_at)',
    );
  }

  Future<void> _ensureScheduleAttachmentsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS schedule_attachments (
        id TEXT PRIMARY KEY NOT NULL,
        schedule_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (schedule_id) REFERENCES app_schedules(id) ON DELETE CASCADE
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schedule_attachments_schedule '
      'ON schedule_attachments(schedule_id, created_at)',
    );
  }

  Future<void> _ensureItemImagesTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_images (
        id TEXT PRIMARY KEY NOT NULL,
        item_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_primary INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_images_item '
      'ON item_images(item_id, sort_order, created_at)',
    );
  }

  Future<void> _ensureProductionGuideTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_production_guides (
        id TEXT PRIMARY KEY NOT NULL,
        item_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '기본 제작 가이드',
        is_primary INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');
    await _addColumnIfMissing(
        'item_production_guides', 'title', "TEXT NOT NULL DEFAULT '기본 제작 가이드'");
    await _addColumnIfMissing(
        'item_production_guides', 'is_primary', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(
        'item_production_guides', 'sort_order', 'INTEGER NOT NULL DEFAULT 0');
    await _removeProductionGuideItemUniqueIfNeeded();
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_production_guide_blocks (
        id TEXT PRIMARY KEY NOT NULL,
        guide_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        text TEXT,
        file_name TEXT,
        file_path TEXT,
        mime_type TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (guide_id) REFERENCES item_production_guides(id) ON DELETE CASCADE
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_production_guides_item '
      'ON item_production_guides(item_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_production_guide_blocks_guide '
      'ON item_production_guide_blocks(guide_id, sort_order, created_at)',
    );
  }

  Future<void> _removeProductionGuideItemUniqueIfNeeded() async {
    final indexes = await customSelect(
      "PRAGMA index_list('item_production_guides')",
    ).get();
    final hasItemUnique = indexes.any((row) {
      final data = row.data;
      final unique = data['unique'];
      final origin = data['origin'];
      return (unique == 1 || unique == true) && origin == 'u';
    });
    if (!hasItemUnique) return;

    await customStatement('PRAGMA foreign_keys = OFF');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_production_guides_new (
        id TEXT PRIMARY KEY NOT NULL,
        item_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '기본 제작 가이드',
        is_primary INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO item_production_guides_new (
        id, item_id, title, is_primary, sort_order, created_at, updated_at
      )
      SELECT id, item_id, title, is_primary, sort_order, created_at, updated_at
      FROM item_production_guides
    ''');
    await customStatement('DROP TABLE item_production_guides');
    await customStatement(
      'ALTER TABLE item_production_guides_new RENAME TO item_production_guides',
    );
    await customStatement('PRAGMA foreign_keys = ON');
  }

  Future<void> resetDatabase() async {
    final db = this;

    // DB 닫기
    await db.close();

    final file = await const AppPathService().stockDatabaseFile();

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
    final file = await const AppPathService().stockDatabaseFile();

    debugPrint("DB path: ${file.path}");

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
      defaultSupplierId: defaultSupplierUid ?? defaultSupplierId?.toString(),
      isFavorite: isFavorite,
      defaultPurchasePrice: defaultPurchasePrice,
      defaultSalePrice: defaultSalePrice,
      reorderIntervalDays: reorderIntervalDays,
      lastOrderedAt:
          lastOrderedAt == null ? null : DateTime.tryParse(lastOrderedAt!),
      nextReorderDate:
          nextReorderDate == null ? null : DateTime.tryParse(nextReorderDate!),
      reorderReminderEnabled: reorderReminderEnabled ?? false,
      reorderReminderDaysBefore: reorderReminderDaysBefore ?? 0,
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
      defaultSupplierUid: Value(defaultSupplierId),
      isFavorite: Value(isFavorite),
      reorderIntervalDays: Value(reorderIntervalDays),
      lastOrderedAt: Value(lastOrderedAt?.toIso8601String()),
      nextReorderDate: Value(nextReorderDate?.toIso8601String()),
      reorderReminderEnabled: Value(reorderReminderEnabled),
      reorderReminderDaysBefore: Value(reorderReminderDaysBefore),
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
        type: TxnType.values
            .firstWhere((e) => e.name == type, orElse: () => TxnType.in_),
        status: TxnStatus.values.firstWhere((e) => e.name == status,
            orElse: () => TxnStatus.actual),
        itemId: itemId,
        qty: qty,
        refType: RefType.values
            .firstWhere((e) => e.name == refType, orElse: () => RefType.order),
        refId: refId,
        note: note,
        memo: memo,
        sourceKey: sourceKey,
        beforeQty: beforeQty,
        afterQty: afterQty,
        unitPrice: unitPrice,
        reason: reason,
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
        beforeQty: Value(beforeQty),
        afterQty: Value(afterQty),
        unitPrice: Value(unitPrice),
        reason: Value(reason),
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
        startedAt:
            startedAt != null ? DateTime.parse(startedAt!) : null, // ✅ 보완
        finishedAt:
            finishedAt != null ? DateTime.parse(finishedAt!) : null, // ✅ 보완
      );
}

extension WorkToCompanion on Work {
  WorksCompanion toCompanion() => WorksCompanion(
        id: Value(id),
        itemId: Value(itemId),
        qty: Value(qty),
        orderId: Value(orderId),
        parentWorkId:
            parentWorkId == null ? const Value.absent() : Value(parentWorkId!),
        status: Value(status.name),
        createdAt: Value(createdAt.toIso8601String()),
        updatedAt: Value(updatedAt?.toIso8601String()),
        isDeleted: Value(isDeleted),
        sourceKey: Value(sourceKey),
        startedAt: Value(startedAt?.toIso8601String()), // ✅ 보완
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
        supplierId: supplierId,
        shippingCost: shippingCost,
        extraCost: extraCost,
        paymentStatus: paymentStatus,
        paidAt: paidAt != null ? DateTime.parse(paidAt!) : null,
        paymentDueAt:
            paymentDueAt != null ? DateTime.parse(paymentDueAt!) : null,
        vatInvoiceStatus: vatInvoiceStatus,
        vatInvoiceIssuedAt: vatInvoiceIssuedAt != null
            ? DateTime.parse(vatInvoiceIssuedAt!)
            : null,
        vatInvoiceDueAt:
            vatInvoiceDueAt != null ? DateTime.parse(vatInvoiceDueAt!) : null,
        eta: DateTime.parse(eta),
        status: PurchaseOrderStatus.values.firstWhere(
          (e) => e.name == status,
          orElse: () => PurchaseOrderStatus.draft,
        ),
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        isDeleted: isDeleted,
        memo: memo,
        deliveryName: deliveryName,
        deliveryAddress: deliveryAddress,
        deliveryPhone: deliveryPhone,
        deliveryMemo: deliveryMemo,
        showDeliveryOnPrint: showDeliveryOnPrint,
        shippingDestinationId: shippingDestinationId,
        buyerProfileId: buyerProfileId,
        buyerProfileName: buyerProfileName,
        buyerBusinessNumber: buyerBusinessNumber,
        buyerCompanyName: buyerCompanyName,
        buyerRepresentative: buyerRepresentative,
        buyerAddress: buyerAddress,
        buyerBusinessType: buyerBusinessType,
        buyerBusinessItem: buyerBusinessItem,
        buyerPhoneFax: buyerPhoneFax,
        orderId: orderId,
        receivedAt: receivedAt != null ? DateTime.parse(receivedAt!) : null,
      );
}

extension PurchaseOrderToCompanion on PurchaseOrder {
  PurchaseOrdersCompanion toCompanion() => PurchaseOrdersCompanion(
        id: Value(id),
        supplierName: Value(supplierName),
        supplierId: Value(supplierId),
        shippingCost: Value(shippingCost),
        extraCost: Value(extraCost),
        vatType: Value(vatType.index),
        paymentStatus: Value(paymentStatus),
        paidAt: Value(paidAt?.toIso8601String()),
        paymentDueAt: Value(paymentDueAt?.toIso8601String()),
        vatInvoiceStatus: Value(vatInvoiceStatus),
        vatInvoiceIssuedAt: Value(vatInvoiceIssuedAt?.toIso8601String()),
        vatInvoiceDueAt: Value(vatInvoiceDueAt?.toIso8601String()),
        eta: Value(eta.toIso8601String()),
        status: Value(status.name),
        createdAt: Value(createdAt.toIso8601String()),
        updatedAt: Value(updatedAt.toIso8601String()),
        isDeleted: Value(isDeleted),
        memo: Value(memo),
        deliveryName: Value(deliveryName),
        deliveryAddress: Value(deliveryAddress),
        deliveryPhone: Value(deliveryPhone),
        deliveryMemo: Value(deliveryMemo),
        showDeliveryOnPrint: Value(showDeliveryOnPrint),
        shippingDestinationId: Value(shippingDestinationId),
        buyerProfileId: Value(buyerProfileId),
        buyerProfileName: Value(buyerProfileName),
        buyerBusinessNumber: Value(buyerBusinessNumber),
        buyerCompanyName: Value(buyerCompanyName),
        buyerRepresentative: Value(buyerRepresentative),
        buyerAddress: Value(buyerAddress),
        buyerBusinessType: Value(buyerBusinessType),
        buyerBusinessItem: Value(buyerBusinessItem),
        buyerPhoneFax: Value(buyerPhoneFax),
        orderId: Value(orderId),
        receivedAt: Value(receivedAt?.toIso8601String()),
      );
}

extension PurchaseLineRowMapping on PurchaseLineRow {
  PurchaseLine toDomain() {
    final printAttrs = <PurchaseLinePrintAttr>[];
    final rawPrintAttrs = printAttrsJson;
    if (rawPrintAttrs != null && rawPrintAttrs.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPrintAttrs);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final attr = PurchaseLinePrintAttr.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (attr.label.trim().isNotEmpty &&
                  attr.value.trim().isNotEmpty) {
                printAttrs.add(attr);
              }
            }
          }
        }
      } catch (_) {
        // Keep old rows readable even if custom print attrs are malformed.
      }
    }

    return PurchaseLine(
      id: id,
      orderId: orderId,
      itemId: itemId,
      name: name,
      unit: unit,
      qty: qty,
      note: note,
      memo: memo,
      colorNo: colorNo,
      unitPrice: unitPrice,
      vatType:
          VatType.values[vatType.clamp(0, VatType.values.length - 1).toInt()],
      supplyAmount: supplyAmount,
      vatAmount: vatAmount,
      totalAmount: totalAmount,
      amountEdited: amountEdited,
      printAttrs: printAttrs,
    );
  }
}

extension PurchaseLineToCompanionExt on PurchaseLine {
  PurchaseLinesCompanion toCompanion() {
    final cleanedPrintAttrs = printAttrs
        .where((attr) =>
            attr.label.trim().isNotEmpty && attr.value.trim().isNotEmpty)
        .map((attr) => attr.toJson())
        .toList(growable: false);
    return PurchaseLinesCompanion(
      id: Value(id),
      orderId: Value(orderId),
      itemId: Value(itemId),
      name: Value(name),
      unit: Value(unit),
      qty: Value(qty),
      note: Value(note),
      memo: Value(memo),
      colorNo: Value(colorNo),
      printAttrsJson: Value(
        cleanedPrintAttrs.isEmpty ? null : jsonEncode(cleanedPrintAttrs),
      ),
      unitPrice: Value(unitPrice),
      vatType: Value(vatType.index),
      supplyAmount: Value(supplyAmount),
      vatAmount: Value(vatAmount),
      totalAmount: Value(totalAmount),
      amountEdited: Value(amountEdited),
    );
  }
}

/// =======================
///  Row ↔ Quote / QuoteLine
/// =======================

extension QuoteRowMapping on QuoteRow {
  Quote toDomain() => Quote(
        id: id,
        customerName: customerName,
        customerId: customerId,
        quoteDate: DateTime.parse(quoteDate),
        validUntil: validUntil == null ? null : DateTime.parse(validUntil!),
        status: QuoteStatus.values.firstWhere(
          (e) => e.name == status,
          orElse: () => QuoteStatus.draft,
        ),
        memo: memo,
        discountAmount: discountAmount,
        shippingCost: shippingCost,
        vatType: QuoteVatType
            .values[vatType.clamp(0, QuoteVatType.values.length - 1)],
        supplierProfileId: supplierProfileId,
        supplierProfileName: supplierProfileName,
        supplierBusinessNumber: supplierBusinessNumber,
        supplierCompanyName: supplierCompanyName,
        supplierRepresentative: supplierRepresentative,
        supplierAddress: supplierAddress,
        supplierBusinessType: supplierBusinessType,
        supplierBusinessItem: supplierBusinessItem,
        supplierPhoneFax: supplierPhoneFax,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        isDeleted: isDeleted,
      );
}

extension QuoteToCompanion on Quote {
  QuotesCompanion toCompanion() => QuotesCompanion(
        id: Value(id),
        customerName: Value(customerName),
        customerId: Value(customerId),
        quoteDate: Value(quoteDate.toIso8601String()),
        validUntil: Value(validUntil?.toIso8601String()),
        status: Value(status.name),
        memo: Value(memo),
        discountAmount: Value(discountAmount),
        shippingCost: Value(shippingCost),
        vatType: Value(vatType.index),
        supplierProfileId: Value(supplierProfileId),
        supplierProfileName: Value(supplierProfileName),
        supplierBusinessNumber: Value(supplierBusinessNumber),
        supplierCompanyName: Value(supplierCompanyName),
        supplierRepresentative: Value(supplierRepresentative),
        supplierAddress: Value(supplierAddress),
        supplierBusinessType: Value(supplierBusinessType),
        supplierBusinessItem: Value(supplierBusinessItem),
        supplierPhoneFax: Value(supplierPhoneFax),
        createdAt: Value(createdAt.toIso8601String()),
        updatedAt: Value(updatedAt.toIso8601String()),
        isDeleted: Value(isDeleted),
      );
}

extension QuoteLineRowMapping on QuoteLineRow {
  QuoteLine toDomain() => QuoteLine(
        id: id,
        quoteId: quoteId,
        itemId: itemId,
        name: name,
        unit: unit,
        qty: qty,
        unitPrice: unitPrice,
        vatType:
            VatType.values[vatType.clamp(0, VatType.values.length - 1).toInt()],
        supplyAmount: supplyAmount,
        vatAmount: vatAmount,
        totalAmount: totalAmount,
        amountEdited: amountEdited,
        memo: memo,
      );
}

extension QuoteLineToCompanion on QuoteLine {
  QuoteLinesCompanion toCompanion() => QuoteLinesCompanion(
        id: Value(id),
        quoteId: Value(quoteId),
        itemId: Value(itemId),
        name: Value(name),
        unit: Value(unit),
        qty: Value(qty),
        unitPrice: Value(unitPrice),
        vatType: Value(vatType.index),
        supplyAmount: Value(supplyAmount),
        vatAmount: Value(vatAmount),
        totalAmount: Value(totalAmount),
        amountEdited: Value(amountEdited),
        memo: Value(memo),
      );
}

/// =======================
///  Row ↔ AppSchedule
/// =======================

extension AppScheduleRowMapping on AppScheduleRow {
  AppSchedule toDomain() => AppSchedule(
        id: id,
        title: title,
        body: body,
        tags: _decodeStringList(tagsJson),
        date: DateTime.parse(date),
        status: AppScheduleStatus.values.firstWhere(
          (e) => e.name == status,
          orElse: () => AppScheduleStatus.pending,
        ),
        isPinned: isPinned ?? false,
        sourceMemoId: sourceMemoId,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
      );
}

extension AppScheduleToCompanion on AppSchedule {
  AppSchedulesCompanion toCompanion() => AppSchedulesCompanion(
        id: Value(id),
        title: Value(title),
        body: Value(body),
        tagsJson: Value(jsonEncode(tags)),
        date: Value(date.toIso8601String()),
        status: Value(status.name),
        isPinned: Value(isPinned),
        sourceMemoId: Value(sourceMemoId),
        createdAt: Value(createdAt.toIso8601String()),
        updatedAt: Value(updatedAt.toIso8601String()),
      );
}

List<String> _decodeStringList(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().toList(growable: false);
  } catch (_) {
    return const [];
  }
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
