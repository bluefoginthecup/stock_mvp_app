enum ProductionGuideBlockType { step, note, image }

class ProductionGuide {
  final String id;
  final String itemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductionGuide({
    required this.id,
    required this.itemId,
    required this.createdAt,
    required this.updatedAt,
  });
}

class ProductionGuideBlock {
  final String id;
  final String guideId;
  final int sortOrder;
  final ProductionGuideBlockType type;
  final String? text;
  final String? fileName;
  final String? filePath;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductionGuideBlock({
    required this.id,
    required this.guideId,
    required this.sortOrder,
    required this.type,
    this.text,
    this.fileName,
    this.filePath,
    this.mimeType,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage => type == ProductionGuideBlockType.image;
}

class ProductionGuideData {
  final ProductionGuide guide;
  final List<ProductionGuideBlock> blocks;

  const ProductionGuideData({
    required this.guide,
    required this.blocks,
  });

  int get stepCount => blocks
      .where((block) => block.type == ProductionGuideBlockType.step)
      .length;

  int get imageCount => blocks
      .where((block) => block.type == ProductionGuideBlockType.image)
      .length;

  int get noteCount => blocks
      .where((block) => block.type == ProductionGuideBlockType.note)
      .length;
}
