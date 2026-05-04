part of '../drift_unified_repo.dart';

mixin QuoteRepoMixin on _RepoCore implements QuoteRepo {
  @override
  Future<String> createQuote(Quote quote) async {
    await db.into(db.quotes).insertOnConflictUpdate(quote.toCompanion());
    return quote.id;
  }

  @override
  Future<void> updateQuote(Quote quote) async {
    await (db.update(db.quotes)..where((t) => t.id.equals(quote.id)))
        .write(quote.toCompanion());
  }

  @override
  Future<void> updateQuoteStatus(String id, QuoteStatus status) async {
    await (db.update(db.quotes)..where((t) => t.id.equals(id))).write(
      QuotesCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  @override
  Stream<List<Quote>> watchAllQuotes() {
    final q = db.select(db.quotes)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.quoteDate)]);
    return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  @override
  Future<Quote?> getQuoteById(String id) async {
    final row = await (db.select(db.quotes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> softDeleteQuote(String id) async {
    final nowIso = DateTime.now().toIso8601String();
    await (db.update(db.quotes)..where((t) => t.id.equals(id))).write(
      QuotesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(nowIso),
        updatedAt: Value(nowIso),
      ),
    );
  }

  @override
  Future<void> restoreQuote(String id) async {
    final nowIso = DateTime.now().toIso8601String();
    await (db.update(db.quotes)..where((t) => t.id.equals(id))).write(
      QuotesCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(nowIso),
      ),
    );
  }

  @override
  Future<void> upsertQuoteLines(String quoteId, List<QuoteLine> lines) async {
    await db.transaction(() async {
      await (db.delete(db.quoteLines)..where((l) => l.quoteId.equals(quoteId)))
          .go();
      for (final line in lines) {
        await db.into(db.quoteLines).insert(line.toCompanion());
      }
    });
  }

  @override
  Future<List<QuoteLine>> getQuoteLines(String quoteId) async {
    final rows = await (db.select(db.quoteLines)
          ..where((l) => l.quoteId.equals(quoteId)))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<Map<String, List<QuoteLine>>> getQuoteLinesMap() async {
    final rows = await db.select(db.quoteLines).get();
    final map = <String, List<QuoteLine>>{};
    for (final row in rows) {
      final line = row.toDomain();
      map.putIfAbsent(line.quoteId, () => <QuoteLine>[]).add(line);
    }
    return map;
  }
}
