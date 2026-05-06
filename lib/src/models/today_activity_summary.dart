class TodayActivitySummary {
  final int newOrders;
  final int purchases;
  final int inbound;
  final int outbound;
  final int pendingTodos;
  final int doneTodos;
  final int inProgressWorks;

  const TodayActivitySummary({
    this.newOrders = 0,
    this.purchases = 0,
    this.inbound = 0,
    this.outbound = 0,
    this.pendingTodos = 0,
    this.doneTodos = 0,
    this.inProgressWorks = 0,
  });

  static const empty = TodayActivitySummary();

  int get total =>
      newOrders +
      purchases +
      inbound +
      outbound +
      pendingTodos +
      doneTodos +
      inProgressWorks;

  bool get hasActivity => total > 0;
}
