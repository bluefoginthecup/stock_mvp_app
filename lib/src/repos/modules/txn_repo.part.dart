part of '../drift_unified_repo.dart';


mixin TxnRepoMixin on _RepoCore implements TxnRepo{

@override
Future<List<Txn>> listTxns() async {
  if (_txnSub == null) {
    _txnSub = (db.select(db.txns)..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .watch()
        .listen((rows) {
      _txnSnapshot = rows.map((r) => r.toDomain()).toList();
      notifyListeners();
    });
  }
  return _txnSnapshot;
}

@override
List<Txn> snapshotTxnsDesc() => _txnSnapshot;

Future<void> _refreshTxnSnapshot() async {
  final rows = await (db.select(db.txns)..orderBy([(t) => OrderingTerm.desc(t.ts)])).get();
  _txnSnapshot = rows.map((r) => r.toDomain()).toList();
  notifyListeners();
}

@override
Future<void> deleteTxn(String txnId) async {
  await (db.delete(db.txns)..where((t) => t.id.equals(txnId))).go();
  await _refreshTxnSnapshot();
}

@override
Future<void> deletePlannedByRef({
  required String refType,
  required String refId,
}) async {
  await (db.delete(db.txns)
                ..where((t) => t.status.equals(TxnStatus.actual.name))
            ..where((t) => t.type.equals(TxnType.in_.name))
            ..where((t) => t.refType.equals(refType))
            ..where((t) => t.refId.equals(refId)))
          .go();
  await _refreshTxnSnapshot();
}


// ✅ 완료 롤백용: ref 기준 inActual 삭제
  @override
  Future<void> deleteInActualByRef({required String refType, required String refId}) async {
      // Drift 테이블/컬럼명이 아래 예시와 다르면 같은 패턴으로 맞춰 주세요.
      // 예: txns.type == 'inActual' AND txns.refType == refType AND txns.refId == refId
    // 1) 어떤 아이템에 몇 개가 들어갔는지 먼저 조회(그룹 합계)
        final rows = await (db.select(db.txns)
              ..where((t) => t.status.equals(TxnStatus.actual.name))
              ..where((t) => t.type.equals(TxnType.in_.name))
              ..where((t) => t.refType.equals(refType))
              ..where((t) => t.refId.equals(refId)))
            .get();
        if (rows.isEmpty) return;

        // itemId별 총합 수량
        final Map<String, int> sumByItem = {};
        for (final r in rows) {
          sumByItem[r.itemId] = (sumByItem[r.itemId] ?? 0)+  r.qty;
        }

        await db.transaction(() async {
          // 2) 트랜잭션 로그 삭제
          await (db.delete(db.txns)
                ..where((t) => t.status.equals(TxnStatus.actual.name))
                ..where((t) => t.type.equals(TxnType.in_.name))
                ..where((t) => t.refType.equals(refType))
                ..where((t) => t.refId.equals(refId)))
              .go();

          // 3) 재고 되돌리기: items.qty = qty - 합계
          for (final entry in sumByItem.entries) {
            final itemId = entry.key;
            final delta = entry.value; // 이전에 더했던 수량
            final row = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
            final before = row?.qty ?? 0;
            final after = before - delta;
            await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
              ItemsCompanion(qty: Value(after)),
            );
            _stockCache[itemId] = after;
          }
        });

        await _refreshTxnSnapshot();
    }

@override
Future<void> addInPlanned({
  required String itemId,
  required int qty,
  required String refType,
  required String refId,
  String? note,
}) async {
  if (qty <= 0) return; // 🔒 최후방어
  await db.into(db.txns).insert(
    Txn.in_(
      id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
      itemId: itemId,
      qty: qty,
      refType: RefTypeX.fromString(refType),
      refId: refId,
      status: TxnStatus.planned,
      note: note,
    ).toCompanion(),
  );
  await _refreshTxnSnapshot();
}

@override
Future<void> addInActual({
  required String itemId,
  required int qty,
  required String refType,
  required String refId,
  String? note,
}) async {
  if (qty <= 0) return; // 🔒 최후방어
  final rt = RefTypeX.fromString(refType);
  await db.transaction(() async {
    await db.into(db.txns).insert(
      Txn.in_(
        id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
        itemId: itemId,
        qty: qty,
        refType: rt,
        refId: refId,
        status: TxnStatus.actual,
        note: note,
      ).toCompanion(),
    );

    final row = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    final before = row?.qty ?? 0;
    final after = before + qty;
    await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(qty: Value(after)),
    );
  });

  _stockCache[itemId] = (await getItem(itemId))?.qty ?? _stockCache[itemId] ?? 0;
  await _refreshTxnSnapshot();
}

@override
Future<void> addOutPlanned({
  required String itemId,
  required int qty,
  required String refType,
  required String refId,
  String? note,
  String? memo,
}) async {
  if (qty <= 0) return; // 🔒 최후방어
  await db.into(db.txns).insert(
    Txn.out_(
      id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
      itemId: itemId,
      qty: qty,
      refType: RefTypeX.fromString(refType),
      refId: refId,
      status: TxnStatus.planned,
      note: note,
      memo: memo,
    ).toCompanion(),
  );
  await _refreshTxnSnapshot();
}

@override
Future<void> addOutActual({
  required String itemId,
  required int qty,
  required String refType,
  required String refId,
  String? note,
  String? memo,
}) async {
  if (qty <= 0) return; // 🔒 최후방어
  final rt = RefTypeX.fromString(refType);
  await db.transaction(() async {
    await db.into(db.txns).insert(
      Txn.out_(
        id: 'txn_${DateTime.now().microsecondsSinceEpoch}',
        itemId: itemId,
        qty: qty,
        refType: rt,
        refId: refId,
        status: TxnStatus.actual,
        note: note,
        memo: memo,
      ).toCompanion(),
    );

    final row = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    final before = row?.qty ?? 0;
    final after = before - qty;
    await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(qty: Value(after)),
    );
  });

  _stockCache[itemId] = (await getItem(itemId))?.qty ?? _stockCache[itemId] ?? 0;
  await _refreshTxnSnapshot();
}

Stream<List<Txn>> watchTxns() {
  final q = db.select(db.txns)..orderBy([(t) => OrderingTerm.desc(t.ts)]);
  return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
}
  // ✅ refType/refId 기준 트랜잭션 스트림
    @override
    Stream<List<Txn>> watchTxnsByRef({required String refType, required String refId}) {
        final q = db.select(db.txns)
          ..where((t) => t.refType.equals(refType))
          ..where((t) => t.refId.equals(refId))
          ..orderBy([(t) => OrderingTerm.desc(t.ts)]);
        return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
      }

@override
Future<void> adjustQty({
  required String itemId,
  required int delta,
  String? refType,
  String? refId,
  String? note,
  String? memo,
}) async {
  if (delta == 0) return; // 🔒 0 조정은 기록/반영하지 않음
  final now = DateTime.now();
  await db.transaction(() async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (row == null) return;

    await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(qty: Value((row.qty) + delta)),
    );

    await db.into(db.txns).insert(
      Txn(
        id: 'txn_${now.microsecondsSinceEpoch}',
        ts: now,
        type: delta > 0 ? TxnType.in_ : TxnType.out_,
        status: TxnStatus.actual,
        itemId: itemId,
        qty: delta.abs(),
        refType: refType != null ? RefTypeX.fromString(refType) : RefType.manual,
        refId: refId ?? 'manual',
        note: note,
        memo: memo,
        sourceKey: null,
      ).toCompanion(),
    );
  });
  _stockCache[itemId] = (await getItem(itemId))?.qty ?? _stockCache[itemId] ?? 0;
  await _refreshTxnSnapshot();
}

@override
Future<void> updateUnits({
  required String itemId,
  String? unitIn,
  String? unitOut,
  double? conversionRate,
}) async {
  await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
    ItemsCompanion(
      unitIn: unitIn != null ? Value(unitIn) : const Value.absent(),
      unitOut: unitOut != null ? Value(unitOut) : const Value.absent(),
      conversionRate: conversionRate != null ? Value(conversionRate) : const Value.absent(),
    ),
  );
  final fresh = await getItem(itemId);
  if (fresh != null) _cacheItem(fresh);
}
}
