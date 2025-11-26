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
    ..where((t) => t.refType.equals(refType))
    ..where((t) => t.refId.equals(refId))
    ..where((t) => t.status.equals(TxnStatus.planned.name)))
      .go();
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


@override
Future<void> adjustQty({
  required String itemId,
  required int delta,
  String? refType,
  String? refId,
  String? note,
  String? memo,
}) async {
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
