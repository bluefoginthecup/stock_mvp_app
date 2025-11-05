class CartMode { static const sales = 'sales'; static const purchase = 'purchase'; }

class CartItem {
  final String itemId;
  final String name;
  final String unit;
  final double qty;
  final String supplierName; // 빈 문자열 허용

  const CartItem({
    required this.itemId,
    required this.name,
    required this.unit,
    required this.qty,
    this.supplierName = '',
  });

  CartItem copyWith({double? qty, String? supplierName}) => CartItem(
    itemId: itemId,
    name: name,
    unit: unit,
    qty: qty ?? this.qty,
    supplierName: supplierName ?? this.supplierName,
  );
}
