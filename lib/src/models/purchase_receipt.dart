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

  bool get canPreviewInApp {
    final lowerMime = mimeType.toLowerCase();
    if (const {
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/bmp',
    }.contains(lowerMime)) {
      return true;
    }

    final lowerName = fileName.toLowerCase();
    return const ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].any(
      lowerName.endsWith,
    );
  }

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
