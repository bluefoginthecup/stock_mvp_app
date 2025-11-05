enum PurchaseOrderStatus { draft, ordered, received, canceled }

class PurchaseOrder {
  final String id;
  final String supplierName;          // 상호 (빈문자 허용)
  final DateTime eta;                 // 도착 예정일
  final PurchaseOrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  PurchaseOrder({
    required this.id,
    required this.supplierName,
    required this.eta,
    this.status = PurchaseOrderStatus.draft,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PurchaseOrder copyWith({
    String? supplierName,
    DateTime? eta,
    PurchaseOrderStatus? status,
    bool? isDeleted,
    DateTime? updatedAt,
  }) => PurchaseOrder(
    id: id,
    supplierName: supplierName ?? this.supplierName,
    eta: eta ?? this.eta,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    isDeleted: isDeleted ?? this.isDeleted,
  );

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
    id: j['id'] as String,
    supplierName: j['supplierName'] as String? ?? '',
    eta: DateTime.parse(j['eta'] as String),
    status: PurchaseOrderStatus.values.firstWhere((e) => e.name == j['status']),
    createdAt: DateTime.parse(j['createdAt']),
    updatedAt: DateTime.parse(j['updatedAt']),
    isDeleted: j['isDeleted'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'supplierName': supplierName,
    'eta': eta.toIso8601String(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
  };
}
