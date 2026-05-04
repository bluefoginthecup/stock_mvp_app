class PurchaseLinePrintAttr {
  final String key;
  final String label;
  final String value;

  const PurchaseLinePrintAttr({
    required this.key,
    required this.label,
    required this.value,
  });

  factory PurchaseLinePrintAttr.fromJson(Map<String, dynamic> json) =>
      PurchaseLinePrintAttr(
        key: (json['key'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        value: (json['value'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'value': value,
      };
}

class PurchaseLine {
  final String id;
  final String orderId; // FK → PurchaseOrder.id
  final String itemId;
  final String name; // 표시용 (옵션)
  final String unit;
  final double qty; // 소수 허용, 필요시 int로 바꿔도 됨
  final String? note;
  final String? memo;
  final String? colorNo;
  final double unitPrice;
  final List<PurchaseLinePrintAttr> printAttrs;

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
    required this.unitPrice,
    this.printAttrs = const [],
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
    double? unitPrice,
    List<PurchaseLinePrintAttr>? printAttrs,
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
        unitPrice: unitPrice ?? this.unitPrice,
        printAttrs: printAttrs ?? this.printAttrs,
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
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
        printAttrs: _printAttrsFromJson(j['printAttrs'] ?? j['print_attrs']),
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
        'unitPrice': unitPrice,
        'printAttrs': printAttrs.map((attr) => attr.toJson()).toList(),
      };

  static List<PurchaseLinePrintAttr> _printAttrsFromJson(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => PurchaseLinePrintAttr.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) =>
            item.label.trim().isNotEmpty && item.value.trim().isNotEmpty)
        .toList(growable: false);
  }
}
