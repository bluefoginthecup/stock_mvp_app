import 'package:drift/drift.dart';

import '../db/app_database.dart';

class PurchasePriceBackfillResult {
  final int scannedLines;
  final int insertedHistories;
  final int skippedExisting;
  final int skippedInvalidPrice;
  final int updatedItems;

  const PurchasePriceBackfillResult({
    required this.scannedLines,
    required this.insertedHistories,
    required this.skippedExisting,
    required this.skippedInvalidPrice,
    required this.updatedItems,
  });

  String get message => '발주 단가 백필 완료: 이력 $insertedHistories건 추가, '
      '아이템 $updatedItems개 갱신'
      '${skippedExisting > 0 ? ', 기존 이력 $skippedExisting건 건너뜀' : ''}'
      '${skippedInvalidPrice > 0 ? ', 단가 없음 $skippedInvalidPrice건 제외' : ''}';
}

class PurchasePriceBackfillService {
  final AppDatabase db;

  const PurchasePriceBackfillService(this.db);

  Future<PurchasePriceBackfillResult> backfillFromReceivedPurchases() async {
    final rows = await db.customSelect(
      '''
      SELECT
        po.id AS purchase_id,
        COALESCE(po.received_at, po.updated_at, po.created_at) AS changed_at,
        pl.id AS line_id,
        pl.item_id AS item_id,
        pl.unit_price AS unit_price
      FROM purchase_lines pl
      INNER JOIN purchase_orders po ON po.id = pl.order_id
      WHERE po.status = 'received'
        AND COALESCE(po.is_deleted, 0) = 0
        AND COALESCE(pl.is_deleted, 0) = 0
      ORDER BY changed_at ASC, po.id ASC, pl.id ASC
      ''',
      readsFrom: {db.purchaseOrders, db.purchaseLines},
    ).get();

    var inserted = 0;
    var skippedExisting = 0;
    var skippedInvalidPrice = 0;
    final latestPriceByItem = <String, double>{};
    final rollingPriceByItem = <String, double?>{};

    await db.transaction(() async {
      for (final row in rows) {
        final data = row.data;
        final lineId = data['line_id'] as String;
        final itemId = data['item_id'] as String;
        final purchaseId = data['purchase_id'] as String;
        final changedAt =
            (data['changed_at'] as String?) ?? DateTime.now().toIso8601String();
        final unitPrice = (data['unit_price'] as num?)?.toDouble() ?? 0;

        if (unitPrice <= 0) {
          skippedInvalidPrice++;
          continue;
        }

        final existing = await db.customSelect(
          '''
          SELECT id FROM item_price_histories
          WHERE source = 'purchase'
            AND source_ref_type = 'purchase_line'
            AND source_ref_id = ?
          LIMIT 1
          ''',
          variables: [Variable.withString(lineId)],
          readsFrom: {db.itemPriceHistories},
        ).getSingleOrNull();
        if (existing != null) {
          skippedExisting++;
          latestPriceByItem[itemId] = unitPrice;
          rollingPriceByItem[itemId] = unitPrice;
          continue;
        }

        final oldPrice = rollingPriceByItem.containsKey(itemId)
            ? rollingPriceByItem[itemId]
            : await _latestKnownPurchasePriceBefore(itemId, changedAt);

        rollingPriceByItem[itemId] = unitPrice;
        latestPriceByItem[itemId] = unitPrice;

        if (_samePrice(oldPrice, unitPrice)) {
          continue;
        }

        await db.into(db.itemPriceHistories).insert(
              ItemPriceHistoriesCompanion(
                id: Value(
                  'iph_${DateTime.now().microsecondsSinceEpoch}_purchase_$lineId',
                ),
                itemId: Value(itemId),
                kind: const Value('purchase'),
                changedAt: Value(changedAt),
                oldPrice: Value(oldPrice),
                newPrice: Value(unitPrice),
                source: const Value('purchase'),
                sourceRefType: const Value('purchase_line'),
                sourceRefId: Value(lineId),
                note: Value('발주 단가 백필: $purchaseId'),
              ),
            );
        inserted++;
      }

      for (final entry in latestPriceByItem.entries) {
        await (db.update(db.items)..where((t) => t.id.equals(entry.key))).write(
          ItemsCompanion(defaultPurchasePrice: Value(entry.value)),
        );
      }
    });

    return PurchasePriceBackfillResult(
      scannedLines: rows.length,
      insertedHistories: inserted,
      skippedExisting: skippedExisting,
      skippedInvalidPrice: skippedInvalidPrice,
      updatedItems: latestPriceByItem.length,
    );
  }

  Future<double?> _latestKnownPurchasePriceBefore(
    String itemId,
    String changedAt,
  ) async {
    final row = await db.customSelect(
      '''
      SELECT new_price FROM item_price_histories
      WHERE item_id = ?
        AND kind = 'purchase'
        AND changed_at < ?
        AND new_price IS NOT NULL
      ORDER BY changed_at DESC
      LIMIT 1
      ''',
      variables: [
        Variable.withString(itemId),
        Variable.withString(changedAt),
      ],
      readsFrom: {db.itemPriceHistories},
    ).getSingleOrNull();
    return (row?.data['new_price'] as num?)?.toDouble();
  }

  bool _samePrice(double? a, double b) {
    if (a == null) return false;
    return (a - b).abs() <= 0.0001;
  }
}
