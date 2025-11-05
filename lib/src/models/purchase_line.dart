class PurchaseLine {
  final String id;
  final String orderId;     // FK → PurchaseOrder.id
  final String itemId;
  final String name;        // 표시용 (옵션)
  final String unit;
  final double qty;         // 소수 허용, 필요시 int로 바꿔도 됨
  final String? note;

  PurchaseLine({
    required this.id,
    required this.orderId,
    required this.itemId,
    required this.name,
    required this.unit,
    required this.qty,
    this.note,
  });

  PurchaseLine copyWith({double? qty, String? note}) => PurchaseLine(
    id: id, orderId: orderId, itemId: itemId, name: name, unit: unit,
    qty: qty ?? this.qty, note: note ?? this.note,
  );

  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
    id: j['id'], orderId: j['orderId'], itemId: j['itemId'],
    name: j['name'], unit: j['unit'], qty: (j['qty'] as num).toDouble(),
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'orderId': orderId, 'itemId': itemId,
    'name': name, 'unit': unit, 'qty': qty, 'note': note,
  };
}
