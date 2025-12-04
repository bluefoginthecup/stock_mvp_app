enum PurchaseOrderStatus { draft, ordered, received, canceled }

class PurchaseOrder {
  final String id;
  final String supplierName;
  final DateTime eta;                 // 예상 입고(2단계 점선에 사용)
  final PurchaseOrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? memo;

  // ✅ 추가
  final String? orderId;              // 주문 연동 발주만 주문 상세 타임라인에 표시
  final DateTime? receivedAt;         // 실제 입고 완료일(막대 종료)

  PurchaseOrder({
    required this.id,
    required this.supplierName,
    required this.eta,
    this.status = PurchaseOrderStatus.draft,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.memo,
    this.orderId,                     // ✅
    this.receivedAt,                  // ✅
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PurchaseOrder copyWith({
    String? supplierName,
    DateTime? eta,
    PurchaseOrderStatus? status,
    bool? isDeleted,
    DateTime? updatedAt,
    String? memo,
    String? orderId,                  // ✅
    DateTime? receivedAt,             // ✅
  }) => PurchaseOrder(
    id: id,
    supplierName: supplierName ?? this.supplierName,
    eta: eta ?? this.eta,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    isDeleted: isDeleted ?? this.isDeleted,
    memo: memo ?? this.memo,
    orderId: orderId ?? this.orderId,             // ✅
    receivedAt: receivedAt ?? this.receivedAt,     // ✅
  );

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
    id: j['id'] as String,
    supplierName: j['supplierName'] as String? ?? '',
    eta: DateTime.parse(j['eta'] as String),
    status: PurchaseOrderStatus.values.firstWhere((e) => e.name == j['status']),
    createdAt: DateTime.parse(j['createdAt']),
    updatedAt: DateTime.parse(j['updatedAt']),
    isDeleted: j['isDeleted'] == true,
    memo: j['memo'] as String?,
    orderId: j['orderId'] as String?,                         // ✅
    receivedAt: (j['receivedAt'] as String?) != null          // ✅
        ? DateTime.parse(j['receivedAt'])
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'supplierName': supplierName,
    'eta': eta.toIso8601String(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'memo': memo,
    'orderId': orderId,                           // ✅
    'receivedAt': receivedAt?.toIso8601String(),  // ✅
  };
}
