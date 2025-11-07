class CartMode { static const sales = 'sales'; static const purchase = 'purchase'; }

class CartItem {
  final String itemId;
  final String name;
  final String unit;
  final double qty;
  final String supplierName; // 빈 문자열 허용
  final String? colorNo; // NEW

  const CartItem({
    required this.itemId,
    required this.name,
    required this.unit,
    required this.qty,
    this.supplierName = '',
    this.colorNo,
  });

  CartItem copyWith({double? qty, String? supplierName, String? colorNo,}) => CartItem(
    itemId: itemId,
    name: name,
    unit: unit,
    qty: qty ?? this.qty,
    supplierName: supplierName ?? this.supplierName,
    colorNo: colorNo ?? this.colorNo, // NEW
  );
}
