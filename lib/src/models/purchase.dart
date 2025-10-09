// lib/models/purchase.dart
// Purchase order model.
import 'types.dart';

class Purchase {
  final String id;         // unique id
  final String itemId;     // item/material to buy (raw/sub)
  final int qty;           // planned quantity (positive)
  final String orderId;    // originating sales order id
  final PurchaseStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? vendorId;  // optional: supplier reference
  final String? note;      // optional memo

  Purchase({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.orderId,
    this.status = PurchaseStatus.planned,
    DateTime? createdAt,
    this.updatedAt,
    this.vendorId,
    this.note,
  })  : createdAt = createdAt ?? DateTime.now(),
        assert(qty > 0, 'qty must be > 0');

  Purchase copyWith({
    String? id,
    String? itemId,
    int? qty,
    String? orderId,
    PurchaseStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? vendorId,
    String? note,
  }) {
    return Purchase(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vendorId: vendorId ?? this.vendorId,
      note: note ?? this.note,
    );
  }

  // ── JSON (de)serialization ─────────────────────────────────────────────────

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as String,
      itemId: json['itemId'] as String,
      qty: (json['qty'] as num).toInt(),
      orderId: json['orderId'] as String,
      status: PurchaseStatus.values.firstWhere((e) => e.name == (json['status'] as String)),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] as String?) != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      vendorId: json['vendorId'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'qty': qty,
        'orderId': orderId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'vendorId': vendorId,
        'note': note,
      };

  @override
  String toString() =>
      'Purchase(id: $id, itemId: $itemId, qty: $qty, orderId: $orderId, status: ${status.name}, vendorId: $vendorId)';
}
