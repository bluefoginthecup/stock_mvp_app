import '../models/item.dart';

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

  PurchaseLine copyWith({double? qty, String? note, String? memo, }) => PurchaseLine(
    id: id,
    orderId: orderId,
    itemId: itemId,
    name: name,
    unit: unit,
    qty: qty ?? this.qty,
    note: note ?? this.note,
    memo: memo ?? this.memo,
    colorNo: colorNo,
  );

  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
    id: j['id'], orderId: j['orderId'], itemId: j['itemId'],
    name: j['name'], unit: j['unit'], qty: (j['qty'] as num).toDouble(),
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'orderId': orderId, 'itemId': itemId,
    'name': name, 'unit': unit, 'qty': qty, 'note': note, 'memo':memo,
  };


}

extension PurchaseLineView on PurchaseLine {
  /// name 우선, 없으면 Item의 displayName/name, 그래도 없으면 기본값
  String displayNameWith(Item? it) {
    final n = name.trim();
    if (n.isNotEmpty) return n;

    if (it != null) {
      final dn = (it.displayName ?? it.name).trim();
      if (dn.isNotEmpty) return dn;
    }
    return '(이름없음)';
  }
}

