class PurchaseLine {
  final String id;
  final String orderId;     // FK → PurchaseOrder.id
  final String itemId;
  final String name;        // 표시용 (옵션)
  final String unit;
  final double qty;         // 소수 허용, 필요시 int로 바꿔도 됨
  final String? note;
  final String? memo;
  final String? colorNo;

  PurchaseLine({
    required this.id,
    required this.orderId,
    required this.itemId,
    required this.name,
    this.colorNo,
    required this.unit,
    required this.qty,
    this.note,
    this.memo,
  });

  // ✅ 확장된 copyWith
  PurchaseLine copyWith({
    String? itemId,
    String? name,
    String? unit,
    String? colorNo,
    double? qty,
    String? note,
    String? memo,
  }) =>
      PurchaseLine(
        id: id,
        orderId: orderId,
        itemId: itemId ?? this.itemId,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        qty: qty ?? this.qty,
        note: note ?? this.note,
        memo: memo ?? this.memo,
        colorNo: colorNo ?? this.colorNo,
      );

  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
    id: j['id'],
    orderId: j['orderId'],
    itemId: j['itemId'],
    name: j['name'],
    unit: j['unit'],
    qty: (j['qty'] as num).toDouble(),
    note: j['note'] as String?,
    memo: j['memo'] as String?,
    colorNo: j['colorNo'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'itemId': itemId,
    'name': name,
    'unit': unit,
    'qty': qty,
    'note': note,
    'memo': memo,
    'colorNo': colorNo,
  };
}
