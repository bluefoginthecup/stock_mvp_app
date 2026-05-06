// ignore_for_file: library_private_types_in_public_api

part of '../drift_unified_repo.dart';

mixin ScheduleRepoMixin on _RepoCore implements ScheduleRepo {
  DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _dayEnd(DateTime date) =>
      _dayStart(date).add(const Duration(days: 1));

  Expression<bool> _dateWhere(dynamic t, DateTime date) {
    final start = _dayStart(date).toIso8601String();
    final end = _dayEnd(date).toIso8601String();
    return t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end);
  }

  @override
  Future<String> createSchedule(AppSchedule schedule) async {
    await db.into(db.appSchedules).insert(schedule.toCompanion());
    notifyListeners();
    return schedule.id;
  }

  @override
  Future<void> updateSchedule(AppSchedule schedule) async {
    await (db.update(db.appSchedules)..where((t) => t.id.equals(schedule.id)))
        .write(schedule.toCompanion());
    notifyListeners();
  }

  @override
  Future<void> deleteSchedule(String id) async {
    await (db.delete(db.appSchedules)..where((t) => t.id.equals(id))).go();
    notifyListeners();
  }

  @override
  Future<AppSchedule?> getScheduleById(String id) async {
    final row = await (db.select(db.appSchedules)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Stream<List<AppSchedule>> watchSchedules({
    DateTime? date,
    AppScheduleStatus? status,
  }) {
    final q = db.select(db.appSchedules)
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);

    if (date != null || status != null) {
      q.where((t) {
        Expression<bool>? expr;
        if (date != null) {
          expr = _dateWhere(t, date);
        }
        if (status != null) {
          final statusExpr = t.status.equals(status.name);
          expr = expr == null ? statusExpr : expr & statusExpr;
        }
        return expr ?? const Constant(true);
      });
    }

    return q.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  @override
  Future<List<AppSchedule>> listSchedulesByDate(DateTime date) async {
    final rows = await (db.select(db.appSchedules)
          ..where((t) => _dateWhere(t, date))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc),
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<void> updateScheduleStatus(String id, AppScheduleStatus status) async {
    await (db.update(db.appSchedules)..where((t) => t.id.equals(id))).write(
      AppSchedulesCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> toggleScheduleStatus(String id) async {
    final schedule = await getScheduleById(id);
    if (schedule == null) return;
    final next = schedule.status == AppScheduleStatus.pending
        ? AppScheduleStatus.done
        : AppScheduleStatus.pending;
    await updateScheduleStatus(id, next);
  }
}
