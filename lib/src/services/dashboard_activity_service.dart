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

  DateTime _monthStart(DateTime day) => DateTime(day.year, day.month);

  DateTime _nextMonth(DateTime day) => DateTime(day.year, day.month + 1);

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

  bool _isInRangeText(String value, DateTime start, DateTime end) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    return !parsed.isBefore(start) && parsed.isBefore(end);
  }

  Future<int> _safeCount(Future<int> Function() count) async {
    try {
      return await count();
    } catch (_) {
      return 0;
    }
  }

  Future<double> _safeAmount(Future<double> Function() amount) async {
    try {
      return await amount();
    } catch (_) {
      return 0;
    }
  }

  Future<double> _orderSalesAmount(Iterable<OrderRow> orders) async {
    final orderIds = orders.map((order) => order.id).toSet();
    if (orderIds.isEmpty) return 0;

    final lines = (await (db.select(db.orderLines)
              ..where((t) => t.isDeleted.equals(false)))
            .get())
        .where((line) => orderIds.contains(line.orderId))
        .toList();
    if (lines.isEmpty) return 0;

    final items = await db.select(db.items).get();
    final salePriceByItem = {
      for (final item in items) item.id: item.defaultSalePrice ?? 0,
    };

    return lines.fold<double>(
      0,
      (sum, line) => sum + line.qty * (salePriceByItem[line.itemId] ?? 0),
    );
  }

  Future<double> _purchaseExpenseAmount(
      Iterable<PurchaseOrderRow> orders) async {
    final orderList = orders.toList(growable: false);
    final orderIds = orderList.map((order) => order.id).toSet();
    if (orderIds.isEmpty) return 0;

    final lines = (await (db.select(db.purchaseLines)
              ..where((t) => t.isDeleted.equals(false)))
            .get())
        .where((line) => orderIds.contains(line.orderId))
        .toList();
    final lineTotal = lines.fold<double>(
      0,
      (sum, line) => sum + line.totalAmount,
    );
    final orderCosts = orderList.fold<double>(
      0,
      (sum, order) => sum + order.shippingCost + order.extraCost,
    );
    return lineTotal + orderCosts;
  }

  Future<TodayActivitySummary> loadTodaySummary({DateTime? day}) async {
    final target = _dayStart(day ?? DateTime.now());
    final monthStart = _monthStart(target);
    final nextMonth = _nextMonth(target);

    final activeOrders = await (db.select(db.orders)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final activePurchases = await (db.select(db.purchaseOrders)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final todayOrders =
        activeOrders.where((row) => _isSameDayText(row.date, target)).toList();
    final monthlyOrders = activeOrders
        .where((row) => _isInRangeText(row.date, monthStart, nextMonth))
        .toList();
    final todayPurchases = activePurchases
        .where((row) => _isSameDayText(row.createdAt, target))
        .toList();

    final newOrders = await _safeCount(() async {
      return todayOrders.length;
    });

    final purchases = await _safeCount(() async {
      // 발주 생성일을 "오늘 챙긴 발주" 기준으로 사용합니다.
      return todayPurchases.length;
    });

    final todaySales = await _safeAmount(() => _orderSalesAmount(todayOrders));
    final monthSales =
        await _safeAmount(() => _orderSalesAmount(monthlyOrders));
    final todayExpenses =
        await _safeAmount(() => _purchaseExpenseAmount(todayPurchases));

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
      todaySales: todaySales,
      monthSales: monthSales,
      todayExpenses: todayExpenses,
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
          ..add(db.select(db.orderLines).watch().listen((_) => emit()))
          ..add(db.select(db.items).watch().listen((_) => emit()))
          ..add(db.select(db.purchaseOrders).watch().listen((_) => emit()))
          ..add(db.select(db.purchaseLines).watch().listen((_) => emit()))
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
