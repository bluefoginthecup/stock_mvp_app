import 'dart:async';

import '../db/app_database.dart';
import '../models/dashboard_purchase_stats.dart';
import '../models/purchase_order.dart';

class DashboardPurchaseStatsService {
  final AppDatabase db;

  const DashboardPurchaseStatsService(this.db);

  DateTime _monthStart(DateTime day) => DateTime(day.year, day.month);

  DateTime _nextMonth(DateTime day) => DateTime(day.year, day.month + 1);

  bool _isInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  String _supplierName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '(미지정)' : trimmed;
  }

  double _orderAmount(
    PurchaseOrderRow order,
    Map<String, List<PurchaseLineRow>> linesByOrder,
  ) {
    final linesTotal = (linesByOrder[order.id] ?? const <PurchaseLineRow>[])
        .fold<double>(0, (sum, line) => sum + line.totalAmount);
    return linesTotal + order.shippingCost + order.extraCost;
  }

  bool _isIncomplete(PurchaseOrderRow order) {
    return order.status != PurchaseOrderStatus.received.name &&
        order.status != PurchaseOrderStatus.canceled.name;
  }

  Future<DashboardPurchaseStats> loadStats({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final monthStart = _monthStart(today);
    final nextMonth = _nextMonth(today);

    final orders = await (db.select(db.purchaseOrders)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final orderIds = orders.map((order) => order.id).toSet();
    final lines = (await (db.select(db.purchaseLines)
              ..where((t) => t.isDeleted.equals(false)))
            .get())
        .where((line) => orderIds.contains(line.orderId))
        .toList();

    final linesByOrder = <String, List<PurchaseLineRow>>{};
    for (final line in lines) {
      linesByOrder.putIfAbsent(line.orderId, () => []).add(line);
    }

    final amountsByOrder = {
      for (final order in orders) order.id: _orderAmount(order, linesByOrder),
    };

    final monthlyOrders = orders
        .where((order) =>
            _isInRange(DateTime.parse(order.createdAt), monthStart, nextMonth))
        .toList();
    final incompleteOrders = orders.where(_isIncomplete).toList();
    final sortedOrders = [...orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final supplierStats = <String, _MutablePurchaseStat>{};
    for (final order in orders) {
      final key = _supplierName(order.supplierName);
      final stat = supplierStats.putIfAbsent(key, _MutablePurchaseStat.new);
      stat.count += 1;
      stat.amount += amountsByOrder[order.id] ?? 0;
    }

    final itemStats = <String, _MutablePurchaseStat>{};
    for (final line in lines) {
      final name = line.name.trim().isEmpty ? '(이름 없음)' : line.name.trim();
      final stat = itemStats.putIfAbsent(name, _MutablePurchaseStat.new);
      stat.count += 1;
      stat.amount += line.totalAmount;
    }

    final topSuppliers = supplierStats.entries
        .map((entry) => DashboardPurchaseSupplierStat(
              name: entry.key,
              count: entry.value.count,
              amount: entry.value.amount,
            ))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : b.amount.compareTo(a.amount);
      });

    final topItems = itemStats.entries
        .map((entry) => DashboardPurchaseItemStat(
              name: entry.key,
              count: entry.value.count,
              amount: entry.value.amount,
            ))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : b.amount.compareTo(a.amount);
      });

    return DashboardPurchaseStats(
      monthlyCount: monthlyOrders.length,
      monthlyAmount: monthlyOrders.fold<double>(
        0,
        (sum, order) => sum + (amountsByOrder[order.id] ?? 0),
      ),
      incompleteCount: incompleteOrders.length,
      incompleteAmount: incompleteOrders.fold<double>(
        0,
        (sum, order) => sum + (amountsByOrder[order.id] ?? 0),
      ),
      recentCreatedAt: sortedOrders.isEmpty
          ? null
          : DateTime.tryParse(sortedOrders.first.createdAt),
      recentSupplierName: sortedOrders.isEmpty
          ? null
          : _supplierName(sortedOrders.first.supplierName),
      topSuppliers: topSuppliers.take(3).toList(growable: false),
      topItems: topItems.take(3).toList(growable: false),
    );
  }

  Stream<DashboardPurchaseStats> watchStats() {
    late final StreamController<DashboardPurchaseStats> controller;
    final subscriptions = <StreamSubscription>[];
    var queued = false;

    Future<void> emit() async {
      if (queued || controller.isClosed) return;
      queued = true;
      scheduleMicrotask(() async {
        queued = false;
        if (controller.isClosed) return;
        try {
          controller.add(await loadStats());
        } catch (e, st) {
          if (!controller.isClosed) {
            controller.addError(e, st);
          }
        }
      });
    }

    controller = StreamController<DashboardPurchaseStats>(
      onListen: () {
        subscriptions
          ..add(db.select(db.purchaseOrders).watch().listen((_) => emit()))
          ..add(db.select(db.purchaseLines).watch().listen((_) => emit()));
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

class _MutablePurchaseStat {
  int count = 0;
  double amount = 0;
}
