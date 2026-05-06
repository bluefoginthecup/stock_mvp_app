import 'dart:async';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/app_schedule.dart';
import '../models/today_activity_summary.dart';
import '../models/types.dart';

class DashboardActivityService {
  final AppDatabase db;

  const DashboardActivityService(this.db);

  DateTime _dayStart(DateTime day) => DateTime(day.year, day.month, day.day);

  bool _isSameDay(DateTime value, DateTime day) {
    return value.year == day.year &&
        value.month == day.month &&
        value.day == day.day;
  }

  bool _isSameDayText(String value, DateTime day) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    return _isSameDay(parsed, day);
  }

  Future<int> _safeCount(Future<int> Function() count) async {
    try {
      return await count();
    } catch (_) {
      return 0;
    }
  }

  Future<TodayActivitySummary> loadTodaySummary({DateTime? day}) async {
    final target = _dayStart(day ?? DateTime.now());

    final newOrders = await _safeCount(() async {
      final rows = await (db.select(db.orders)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      return rows.where((row) => _isSameDayText(row.date, target)).length;
    });

    final purchases = await _safeCount(() async {
      // 발주 생성일을 "오늘 챙긴 발주" 기준으로 사용합니다.
      final rows = await (db.select(db.purchaseOrders)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      return rows.where((row) => _isSameDayText(row.createdAt, target)).length;
    });

    final inbound = await _safeCount(() async {
      final rows = await (db.select(db.txns)
            ..where((t) =>
                t.type.equals(TxnType.in_.name) &
                t.status.equals(TxnStatus.actual.name)))
          .get();
      return rows.where((row) => _isSameDayText(row.ts, target)).length;
    });

    final outbound = await _safeCount(() async {
      final rows = await (db.select(db.txns)
            ..where((t) =>
                t.type.equals(TxnType.out_.name) &
                t.status.equals(TxnStatus.actual.name)))
          .get();
      return rows.where((row) => _isSameDayText(row.ts, target)).length;
    });

    final pendingTodos = await _safeCount(() async {
      final rows = await (db.select(db.appSchedules)
            ..where((t) => t.status.equals(AppScheduleStatus.pending.name)))
          .get();
      return rows.where((row) => _isSameDayText(row.date, target)).length;
    });

    final doneTodos = await _safeCount(() async {
      // MVP 기준: completedAt 컬럼이 아직 없으므로 date == 오늘 && done을 "한일"로 집계합니다.
      final rows = await (db.select(db.appSchedules)
            ..where((t) => t.status.equals(AppScheduleStatus.done.name)))
          .get();
      return rows.where((row) => _isSameDayText(row.date, target)).length;
    });

    final inProgressWorks = await _safeCount(() async {
      final rows = await (db.select(db.works)
            ..where((t) =>
                t.isDeleted.equals(false) &
                t.status.equals(WorkStatus.inProgress.name)))
          .get();
      return rows.length;
    });

    return TodayActivitySummary(
      newOrders: newOrders,
      purchases: purchases,
      inbound: inbound,
      outbound: outbound,
      pendingTodos: pendingTodos,
      doneTodos: doneTodos,
      inProgressWorks: inProgressWorks,
    );
  }

  Stream<TodayActivitySummary> watchTodaySummary({DateTime? day}) {
    final target = day ?? DateTime.now();
    late final StreamController<TodayActivitySummary> controller;
    final subscriptions = <StreamSubscription>[];
    var queued = false;

    Future<void> emit() async {
      if (queued || controller.isClosed) return;
      queued = true;
      scheduleMicrotask(() async {
        queued = false;
        if (controller.isClosed) return;
        try {
          controller.add(await loadTodaySummary(day: target));
        } catch (e, st) {
          if (!controller.isClosed) {
            controller.addError(e, st);
          }
        }
      });
    }

    controller = StreamController<TodayActivitySummary>(
      onListen: () {
        subscriptions
          ..add(db.select(db.orders).watch().listen((_) => emit()))
          ..add(db.select(db.purchaseOrders).watch().listen((_) => emit()))
          ..add(db.select(db.txns).watch().listen((_) => emit()))
          ..add(db.select(db.appSchedules).watch().listen((_) => emit()))
          ..add(db.select(db.works).watch().listen((_) => emit()));
        emit();
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }
}
