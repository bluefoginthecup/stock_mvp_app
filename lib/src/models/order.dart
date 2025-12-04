// lib/src/models/order.dart

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

  // 🔒 삭제/동기화 표준 필드
  final bool isDeleted;           // soft delete 플래그
  final DateTime? deletedAt;      // soft delete 타임스탬프(없으면 null)
  final DateTime updatedAt;       // LWW 동기화 기준
  final DateTime? shippedAt;   // ✅ 출고(주문완료)일
  final DateTime? dueDate;     // ✅ 납기(출고 예정)일

  Order({
    required this.id,
    required this.date,
    required this.customer,
    this.memo,
    required this.status,
    required this.lines,
    this.isDeleted = false,
    this.deletedAt,
    this.shippedAt,
    this.dueDate,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// copyWith: id/date 포함(유연성↑)
  Order copyWith({
    String? id,
    DateTime? date,
    String? customer,
    String? memo,
    OrderStatus? status,
    List<OrderLine>? lines,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? updatedAt,
    DateTime? shippedAt,
    DateTime? dueDate,
  }) {
    return Order(
      id: id ?? this.id,
      date: date ?? this.date,
      customer: customer ?? this.customer,
      memo: memo ?? this.memo,
      status: status ?? this.status,
      lines: lines ?? this.lines,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      shippedAt: shippedAt ?? this.shippedAt,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  /// 직렬화 (Firestore/SQLite 공용)
  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'customer': customer,
    'memo': memo,
    'status': status.name,
    'lines': lines.map((l) => l.toMap()).toList(),
    // 👇 삭제/동기화 메타 포함
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'shippedAt': shippedAt?.toIso8601String(),
    'dueDate':   dueDate?.toIso8601String(),
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
    isDeleted: (map['isDeleted'] as bool?) ?? false,
    deletedAt: (map['deletedAt'] as String?) != null
        ? DateTime.parse(map['deletedAt'] as String)
        : null,
    updatedAt: (map['updatedAt'] as String?) != null
        ? DateTime.parse(map['updatedAt'] as String)
        : DateTime
        .now(), // 과거 데이터 호환: 없으면 지금 시각으로 보정
    shippedAt: (map['shippedAt'] as String?) != null ? DateTime.parse(map['shippedAt']) : null,
    dueDate:   (map['dueDate']   as String?) != null ? DateTime.parse(map['dueDate'])   : null,

  );

  /// 편의: 지금 시각으로 updatedAt 갱신한 사본
  Order touch() => copyWith(updatedAt: DateTime.now());

  /// 편의: soft delete 적용 사본
  Order softDeleted() => copyWith(
    isDeleted: true,
    deletedAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// 편의: soft delete 해제(복구) 사본
  Order restored() => copyWith(
    isDeleted: false,
    deletedAt: null,
    updatedAt: DateTime.now(),
  );
}
