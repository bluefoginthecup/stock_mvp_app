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

  Order copyWith({
    String? customer,
    String? memo,
    OrderStatus? status,
    List<OrderLine>? lines
  }) {
    return Order(
      id: id,
      date: date,
      customer: customer ?? this.customer,
      memo: memo ?? this.memo,
      status: status ?? this.status,
      lines: lines ?? this.lines,
    );
  }
}
