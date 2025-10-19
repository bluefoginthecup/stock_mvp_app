// lib/models/work.dart
// Production (work) order model.
import 'types.dart';

class Work {
  final String id;        // unique id
  final String itemId;    // item to produce (finished/semi)
  final int qty;          // planned quantity (positive)
  final String? orderId;   // originating sales order id
  final WorkStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  Work({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.orderId,
    this.status = WorkStatus.planned,
      this.isDeleted = false,
    DateTime? createdAt,
    this.updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        assert(qty > 0, 'qty must be > 0');


  Work copyWith({
    String? id,
    String? itemId,
    int? qty,
    String? orderId,
    WorkStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  bool? isDeleted,
  }) {
    return Work(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // ── JSON (de)serialization ─────────────────────────────────────────────────

  factory Work.fromJson(Map<String, dynamic> json) {
    return Work(
      id: json['id'] as String,
      itemId: json['itemId'] as String,
      qty: (json['qty'] as num).toInt(),
      orderId: json['orderId'] as String,
      status: WorkStatus.values.firstWhere((e) => e.name == (json['status'] as String)),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] as String?) != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
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
      };

  @override
  String toString() =>
      'Work(id: $id, itemId: $itemId, qty: $qty, orderId: $orderId, status: ${status.name})';
}
