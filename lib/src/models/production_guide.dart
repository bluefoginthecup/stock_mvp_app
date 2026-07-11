import 'dart:convert';

enum ProductionGuideBlockType { step, note, image }

class ProductionGuide {
  final String id;
  final String itemId;
  final String title;
  final bool isPrimary;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductionGuide({
    required this.id,
    required this.itemId,
    required this.title,
    required this.isPrimary,
    required this.sortOrder,
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

  int get imageCount => blocks.fold<int>(
        0,
        (count, block) =>
            count +
            (block.type == ProductionGuideBlockType.image
                ? 1
                : _embeddedImageCount(block.text)),
      );

  int get noteCount => blocks
      .where((block) => block.type == ProductionGuideBlockType.note)
      .length;

  static int _embeddedImageCount(String? text) {
    const marker = '__guide_quill_delta_v1__';
    if (text == null || !text.startsWith(marker)) return 0;
    try {
      final decoded = jsonDecode(text.substring(marker.length));
      if (decoded is! List) return 0;
      return decoded.where((op) {
        if (op is! Map<String, dynamic>) return false;
        final insert = op['insert'];
        return insert is Map && insert.containsKey('image');
      }).length;
    } catch (_) {
      return 0;
    }
  }
}
