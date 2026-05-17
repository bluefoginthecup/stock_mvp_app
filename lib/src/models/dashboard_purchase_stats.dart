class DashboardPurchaseStats {
  final int monthlyCount;
  final double monthlyAmount;
  final int incompleteCount;
  final double incompleteAmount;
  final DateTime? recentCreatedAt;
  final String? recentSupplierName;
  final List<DashboardPurchaseSupplierStat> topSuppliers;
  final List<DashboardPurchaseItemStat> topItems;

  const DashboardPurchaseStats({
    required this.monthlyCount,
    required this.monthlyAmount,
    required this.incompleteCount,
    required this.incompleteAmount,
    required this.recentCreatedAt,
    required this.recentSupplierName,
    required this.topSuppliers,
    required this.topItems,
  });

  static const empty = DashboardPurchaseStats(
    monthlyCount: 0,
    monthlyAmount: 0,
    incompleteCount: 0,
    incompleteAmount: 0,
    recentCreatedAt: null,
    recentSupplierName: null,
    topSuppliers: [],
    topItems: [],
  );
}

class DashboardPurchaseSupplierStat {
  final String name;
  final int count;
  final double amount;

  const DashboardPurchaseSupplierStat({
    required this.name,
    required this.count,
    required this.amount,
  });
}

class DashboardPurchaseItemStat {
  final String name;
  final int count;
  final double amount;

  const DashboardPurchaseItemStat({
    required this.name,
    required this.count,
    required this.amount,
  });
}
