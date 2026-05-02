class PurchaseReceipt {
  final String id;
  final String purchaseOrderId;
  final String fileName;
  final String filePath;
  final String mimeType;
  final DateTime createdAt;
  final String? memo;

  const PurchaseReceipt({
    required this.id,
    required this.purchaseOrderId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.createdAt,
    this.memo,
  });

  bool get isImage => mimeType.startsWith('image/');

  PurchaseReceipt copyWith({
    String? id,
    String? purchaseOrderId,
    String? fileName,
    String? filePath,
    String? mimeType,
    DateTime? createdAt,
    String? memo,
  }) {
    return PurchaseReceipt(
      id: id ?? this.id,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      memo: memo ?? this.memo,
    );
  }
}
