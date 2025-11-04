// lib/src/models/lot.dart
class Lot {
  final String itemId;
  final String lotNo;
  final double receivedQtyRoll;   // 보통 1
  final double measuredLengthM;   // 최초 실측 길이
  double usableQtyM;              // 현재 사용 가능 잔량
  final String status;            // 'active' | 'closed'
  final DateTime receivedAt;

  Lot({
    required this.itemId,
    required this.lotNo,
    required this.receivedQtyRoll,
    required this.measuredLengthM,
    required this.usableQtyM,
    this.status = 'active',
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory Lot.fromJson(Map<String, dynamic> j) => Lot(
    itemId: j['item_id'] as String,
    lotNo: j['lot_no'] as String,
    receivedQtyRoll: (j['received_qty_roll'] ?? 1).toDouble(),
    measuredLengthM: (j['measured_length_m'] ?? j['length_m'] ?? 0).toDouble(),
    usableQtyM: (j['usable_qty_m'] ?? j['measured_length_m'] ?? 0).toDouble(),
    status: (j['status'] as String?) ?? 'active',
    receivedAt: DateTime.tryParse(j['received_at'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'lot_no': lotNo,
    'received_qty_roll': receivedQtyRoll,
    'measured_length_m': measuredLengthM,
    'usable_qty_m': usableQtyM,
    'status': status,
    'received_at': receivedAt.toIso8601String(),
  };
}
