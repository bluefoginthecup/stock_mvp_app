enum OrderStatus { draft, planned, inProgress, done }

class OrderLine {
  final String id;
  final String itemId;
  final int qty;

  OrderLine({required this.id, required this.itemId, required this.qty});
}

class Order {
  final String id;
  final DateTime date;
  final String customer;
  final String? memo;
  final OrderStatus status;
  final List<OrderLine> lines;

  Order({
    required this.id,
    required this.date,
    required this.customer,
    this.memo,
    required this.status,
    required this.lines,
  });

  Order copyWith({OrderStatus? status, List<OrderLine>? lines}) {
    return Order(
      id: id,
      date: date,
      customer: customer,
      memo: memo,
      status: status ?? this.status,
      lines: lines ?? this.lines,
    );
  }
}
