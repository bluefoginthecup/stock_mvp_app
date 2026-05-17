// ignore_for_file: library_private_types_in_public_api

part of '../drift_unified_repo.dart';

mixin ScheduleRepoMixin on _RepoCore implements ScheduleRepo {
  DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Expression<bool> _dateWhere($AppSchedulesTable t, DateTime date) {
    final day = _dayStart(date);
    final month = day.month.toString().padLeft(2, '0');
    final datePart = day.day.toString().padLeft(2, '0');
    return t.date.like('${day.year}-$month-$datePart%');
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
    final attachments = await getScheduleAttachments(id);
    const paths = AppPathService();
    for (final attachment in attachments) {
      try {
        final file = await paths.resolveAppFile(attachment.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    await (db.delete(db.appSchedules)..where((t) => t.id.equals(id))).go();
    await db.customStatement(
      'DELETE FROM schedule_attachments WHERE schedule_id = ?',
      [id],
    );

    try {
      final dir = await paths.scheduleAttachmentDirectory(id);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}

    notifyListeners();
    db.notifyUpdates({const TableUpdate('schedule_attachments')});
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

  @override
  Future<void> addScheduleAttachment(ScheduleAttachment attachment) async {
    final filePath = await const AppPathService()
        .normalizeToRelativePath(attachment.filePath);
    await db.customStatement(
      '''
      INSERT OR REPLACE INTO schedule_attachments
        (id, schedule_id, file_name, file_path, mime_type, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        attachment.id,
        attachment.scheduleId,
        attachment.fileName,
        filePath,
        attachment.mimeType,
        attachment.createdAt.toIso8601String(),
      ],
    );
    db.notifyUpdates({const TableUpdate('schedule_attachments')});
    notifyListeners();
  }

  @override
  Future<List<ScheduleAttachment>> getScheduleAttachments(
      String scheduleId) async {
    final rows = await db.customSelect(
      '''
      SELECT id, schedule_id, file_name, file_path, mime_type, created_at
      FROM schedule_attachments
      WHERE schedule_id = ?
      ORDER BY created_at DESC
      ''',
      variables: [Variable.withString(scheduleId)],
    ).get();
    return rows.map(_scheduleAttachmentFromRow).toList();
  }

  @override
  Stream<List<ScheduleAttachment>> watchScheduleAttachments(
      String scheduleId) async* {
    yield await getScheduleAttachments(scheduleId);

    final updates = db
        .tableUpdates(
            const TableUpdateQuery.onTableName('schedule_attachments'))
        .map((_) => null);
    await for (final _ in updates) {
      yield await getScheduleAttachments(scheduleId);
    }
  }

  @override
  Future<void> deleteScheduleAttachment(String id) async {
    final rows = await db.customSelect(
      '''
      SELECT file_path
      FROM schedule_attachments
      WHERE id = ?
      ''',
      variables: [Variable.withString(id)],
    ).get();

    if (rows.isNotEmpty) {
      final filePath = rows.first.data['file_path'] as String;
      try {
        final file = await const AppPathService().resolveAppFile(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    await db.customStatement(
      'DELETE FROM schedule_attachments WHERE id = ?',
      [id],
    );
    db.notifyUpdates({const TableUpdate('schedule_attachments')});
    notifyListeners();
  }

  ScheduleAttachment _scheduleAttachmentFromRow(QueryRow row) {
    final data = row.data;
    return ScheduleAttachment(
      id: data['id'] as String,
      scheduleId: data['schedule_id'] as String,
      fileName: data['file_name'] as String,
      filePath: data['file_path'] as String,
      mimeType: data['mime_type'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}
