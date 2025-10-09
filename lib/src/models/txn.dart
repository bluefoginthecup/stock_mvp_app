// lib/models/txn.dart
// Transaction record model to track stock movements and their origins.
import 'types.dart';

class Txn {
  final String id;        // unique id
  final DateTime ts;      // timestamp (UTC recommended)
  final TxnType type;     // in_ (inbound) / out_ (outbound)
  final String itemId;    // target item id
  final int qty;          // positive quantity
  final RefType refType;  // origin kind: order/work/purchase
  final String refId;     // origin id
  final String? note;     // optional memo

  const Txn({
    required this.id,
    required this.ts,
    required this.type,
    required this.itemId,
    required this.qty,
    required this.refType,
    required this.refId,
    this.note,
  }) : assert(qty > 0, 'qty must be > 0');

  Txn copyWith({
    String? id,
    DateTime? ts,
    TxnType? type,
    String? itemId,
    int? qty,
    RefType? refType,
    String? refId,
    String? note,
  }) {
    return Txn(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      refType: refType ?? this.refType,
      refId: refId ?? this.refId,
      note: note ?? this.note,
    );
  }

  // ── JSON (de)serialization ─────────────────────────────────────────────────

  factory Txn.fromJson(Map<String, dynamic> json) {
    return Txn(
      id: json['id'] as String,
      ts: DateTime.parse(json['ts'] as String),
      type: TxnType.values.firstWhere((e) => e.name == (json['type'] as String)),
      itemId: json['itemId'] as String,
      qty: (json['qty'] as num).toInt(),
      refType: RefType.values.firstWhere((e) => e.name == (json['refType'] as String)),
      refId: json['refId'] as String,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts.toIso8601String(),
        'type': type.name,
        'itemId': itemId,
        'qty': qty,
        'refType': refType.name,
        'refId': refId,
        'note': note,
      };

  @override
  String toString() =>
      'Txn(id: $id, ts: ${ts.toIso8601String()}, type: ${type.name}, itemId: $itemId, qty: $qty, ref: ${refType.name}/$refId)';
}
