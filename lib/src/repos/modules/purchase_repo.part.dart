part of '../drift_unified_repo.dart';

mixin PurchaseRepoMixin on _RepoCore implements PurchaseOrderRepo {
  @override
  Future<String> createPurchaseOrder(PurchaseOrder po) async {
    await db.into(db.purchaseOrders).insertOnConflictUpdate(po.toCompanion());
    return po.id;
  }

  Future<void> updatePurchaseOrder(PurchaseOrder po) async {
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(po.id)))
        .write(po.toCompanion());
  }

  @override
  Future<void> updatePurchaseOrderStatus(
      String id, PurchaseOrderStatus status) async {
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Stream<List<PurchaseOrder>> watchAllPurchaseOrders() {
    final q = db.select(db.purchaseOrders)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  @override
  Stream<PurchaseOrder?> watchPurchaseOrderById(String id) {
    final q = db.select(db.purchaseOrders)..where((t) => t.id.equals(id));

    return q.watchSingleOrNull().map((row) => row?.toDomain());
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    final row = await (db.select(db.purchaseOrders)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> softDeletePurchaseOrder(String id) async {
    final nowIso = DateTime.now().toIso8601String();
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(nowIso),
        updatedAt: Value(nowIso),
      ),
    );
  }

  @override
  Future<void> hardDeletePurchaseOrder(String id) async {
    final receiptRows = await db.customSelect(
      'SELECT file_path FROM purchase_receipts WHERE purchase_order_id = ?',
      variables: [Variable.withString(id)],
    ).get();
    final receiptPaths =
        receiptRows.map((r) => r.data['file_path'] as String).toList();

    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM purchase_receipts WHERE purchase_order_id = ?',
        [id],
      );
      await (db.delete(db.purchaseLines)..where((l) => l.orderId.equals(id)))
          .go();
      await (db.delete(db.purchaseOrders)..where((t) => t.id.equals(id))).go();
    });

    for (final path in receiptPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // DB 삭제가 우선이며, 파일 정리는 실패해도 발주 삭제 흐름을 막지 않는다.
      }
    }
  }

  @override
  Future<void> restorePurchaseOrder(String id) async {
    final nowIso = DateTime.now().toIso8601String();
    await (db.update(db.purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(nowIso),
      ),
    );
  }

  @override
  Future<void> upsertLines(String orderId, List<PurchaseLine> lines) async {
    await db.transaction(() async {
      await (db.delete(db.purchaseLines)
            ..where((l) => l.orderId.equals(orderId)))
          .go();
      for (final line in lines) {
        final safeLine = line.copyWith(
          unitPrice: line.unitPrice <= 0
              ? await _resolvePrice(line.itemId)
              : line.unitPrice,
        );
        await db.into(db.purchaseLines).insert(safeLine.toCompanion());
      }
    });
  }

  Future<double> _resolvePrice(String itemId) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();

    return row?.defaultPurchasePrice ?? 0;
  }

  @override
  Future<List<PurchaseLine>> getLines(String orderId) async {
    final rows = await (db.select(db.purchaseLines)
          ..where((l) => l.orderId.equals(orderId)))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<Map<String, List<PurchaseLine>>> getLinesMap() async {
    final rows = await db.select(db.purchaseLines).get();

    final map = <String, List<PurchaseLine>>{};

    for (final r in rows) {
      final line = r.toDomain();
      map.putIfAbsent(line.orderId, () => []).add(line);
    }

    return map;
  }

  @override
  Future<void> addPurchaseReceipt(PurchaseReceipt receipt) async {
    await db.customStatement(
      '''
      INSERT OR REPLACE INTO purchase_receipts
        (id, purchase_order_id, file_name, file_path, mime_type, created_at, memo)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        receipt.id,
        receipt.purchaseOrderId,
        receipt.fileName,
        receipt.filePath,
        receipt.mimeType,
        receipt.createdAt.toIso8601String(),
        receipt.memo,
      ],
    );
  }

  @override
  Future<List<PurchaseReceipt>> getPurchaseReceipts(
      String purchaseOrderId) async {
    final rows = await db.customSelect(
      '''
      SELECT id, purchase_order_id, file_name, file_path, mime_type, created_at, memo
      FROM purchase_receipts
      WHERE purchase_order_id = ?
      ORDER BY created_at DESC
      ''',
      variables: [Variable.withString(purchaseOrderId)],
    ).get();
    return rows.map(_purchaseReceiptFromRow).toList();
  }

  @override
  Stream<List<PurchaseReceipt>> watchPurchaseReceipts(String purchaseOrderId) {
    return Stream.fromFuture(getPurchaseReceipts(purchaseOrderId));
  }

  @override
  Future<void> deletePurchaseReceipt(String id) async {
    await db.customStatement(
      'DELETE FROM purchase_receipts WHERE id = ?',
      [id],
    );
  }

  PurchaseReceipt _purchaseReceiptFromRow(QueryRow row) {
    final data = row.data;
    return PurchaseReceipt(
      id: data['id'] as String,
      purchaseOrderId: data['purchase_order_id'] as String,
      fileName: data['file_name'] as String,
      filePath: data['file_path'] as String,
      mimeType: data['mime_type'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      memo: data['memo'] as String?,
    );
  }
}
