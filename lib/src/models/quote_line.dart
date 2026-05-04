class QuoteLine {
  final String id;
  final String quoteId;
  final String itemId;
  final String name;
  final String unit;
  final double qty;
  final double unitPrice;
  final String? memo;

  QuoteLine({
    required this.id,
    required this.quoteId,
    required this.itemId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.memo,
  });

  double get amount => qty * unitPrice;

  QuoteLine copyWith({
    String? itemId,
    String? name,
    String? unit,
    double? qty,
    double? unitPrice,
    String? memo,
  }) =>
      QuoteLine(
        id: id,
        quoteId: quoteId,
        itemId: itemId ?? this.itemId,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        qty: qty ?? this.qty,
        unitPrice: unitPrice ?? this.unitPrice,
        memo: memo ?? this.memo,
      );
}
