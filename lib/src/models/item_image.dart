class ItemImage {
  final String id;
  final String itemId;
  final String fileName;
  final String filePath;
  final String mimeType;
  final DateTime createdAt;
  final int sortOrder;
  final bool isPrimary;

  const ItemImage({
    required this.id,
    required this.itemId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.createdAt,
    this.sortOrder = 0,
    this.isPrimary = true,
  });
}
