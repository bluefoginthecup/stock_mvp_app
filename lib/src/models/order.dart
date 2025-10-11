enum OrderStatus { draft, planned, inProgress, done }

class OrderLine {
  final String id;
  final String itemId;
  final int qty;

  OrderLine({
    required this.id,
    required this.itemId,
    required this.qty,
  });

  // ✅ copyWith 메서드 (OrderFormScreen에서 사용)
  OrderLine copyWith({
    String? id,
    String? itemId,
    int? qty,
  }) {
    return OrderLine(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
    );
  }

  // ✅ 직렬화 지원 (Firestore/Hive 저장용)
  Map<String, dynamic> toMap() => {
    'id': id,
    'itemId': itemId,
    'qty': qty,
  };

  factory OrderLine.fromMap(Map<String, dynamic> map) => OrderLine(
    id: map['id'] as String,
    itemId: map['itemId'] as String,
    qty: map['qty'] as int,
  );
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

  // ✅ Order copyWith
  Order copyWith({
    String? customer,
    String? memo,
    OrderStatus? status,
    List<OrderLine>? lines,
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

  // ✅ 직렬화 지원
  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'customer': customer,
    'memo': memo,
    'status': status.name,
    'lines': lines.map((l) => l.toMap()).toList(),
  };

  factory Order.fromMap(Map<String, dynamic> map) => Order(
    id: map['id'] as String,
    date: DateTime.parse(map['date'] as String),
    customer: map['customer'] as String,
    memo: map['memo'] as String?,
    status: OrderStatus.values
        .firstWhere((e) => e.name == (map['status'] ?? 'draft')),
    lines: (map['lines'] as List<dynamic>)
        .map((l) => OrderLine.fromMap(Map<String, dynamic>.from(l)))
        .toList(),
  );
}
