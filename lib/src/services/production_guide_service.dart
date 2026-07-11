import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/production_guide.dart';
import 'app_path_service.dart';

class ProductionGuideService {
  final AppDatabase db;

  const ProductionGuideService(this.db);

  static const _uuid = Uuid();

  Future<List<ProductionGuideData>> listGuideData(String itemId) async {
    final guides = await listGuides(itemId);
    final result = <ProductionGuideData>[];
    for (final guide in guides) {
      result.add(ProductionGuideData(
        guide: guide,
        blocks: await listBlocks(guide.id),
      ));
    }
    return result;
  }

  Stream<List<ProductionGuideData>> watchGuideList(String itemId) async* {
    yield await listGuideData(itemId);
    final updates =
        db.tableUpdates(const TableUpdateQuery.any()).map((_) => null);
    await for (final _ in updates) {
      yield await listGuideData(itemId);
    }
  }

  Future<List<ProductionGuide>> listGuides(String itemId) async {
    final rows = await db.customSelect(
      '''
      SELECT id, item_id, title, is_primary, sort_order, created_at, updated_at
      FROM item_production_guides
      WHERE item_id = ?
      ORDER BY is_primary DESC, sort_order ASC, updated_at DESC
      ''',
      variables: [Variable.withString(itemId)],
    ).get();
    return rows.map(_guideFromRow).toList();
  }

  Future<ProductionGuideData> getOrCreateGuide(String itemId) async {
    final existing = await _getGuide(itemId);
    if (existing != null) {
      return ProductionGuideData(
        guide: existing,
        blocks: await listBlocks(existing.id),
      );
    }

    final now = DateTime.now();
    final guide = ProductionGuide(
      id: _uuid.v4(),
      itemId: itemId,
      title: '기본 제작 가이드',
      isPrimary: true,
      sortOrder: await _nextGuideSortOrder(itemId),
      createdAt: now,
      updatedAt: now,
    );
    await db.customStatement(
      '''
      INSERT INTO item_production_guides (
        id, item_id, title, is_primary, sort_order, created_at, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        guide.id,
        guide.itemId,
        guide.title,
        guide.isPrimary ? 1 : 0,
        guide.sortOrder,
        guide.createdAt.toIso8601String(),
        guide.updatedAt.toIso8601String(),
      ],
    );
    db.notifyUpdates({const TableUpdate('item_production_guides')});
    return ProductionGuideData(guide: guide, blocks: const []);
  }

  Future<ProductionGuideData> createGuide({
    required String itemId,
    required String title,
  }) async {
    final existing = await listGuides(itemId);
    final now = DateTime.now();
    final guide = ProductionGuide(
      id: _uuid.v4(),
      itemId: itemId,
      title: title.trim().isEmpty ? '새 제작 가이드' : title.trim(),
      isPrimary: existing.isEmpty,
      sortOrder: await _nextGuideSortOrder(itemId),
      createdAt: now,
      updatedAt: now,
    );
    await db.customStatement(
      '''
      INSERT INTO item_production_guides (
        id, item_id, title, is_primary, sort_order, created_at, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        guide.id,
        guide.itemId,
        guide.title,
        guide.isPrimary ? 1 : 0,
        guide.sortOrder,
        guide.createdAt.toIso8601String(),
        guide.updatedAt.toIso8601String(),
      ],
    );
    db.notifyUpdates({const TableUpdate('item_production_guides')});
    return ProductionGuideData(guide: guide, blocks: const []);
  }

  Future<ProductionGuideData?> getGuideData(String itemId) async {
    final guide = await _getGuide(itemId);
    if (guide == null) return null;
    return ProductionGuideData(
      guide: guide,
      blocks: await listBlocks(guide.id),
    );
  }

  Future<ProductionGuideData?> getGuideDataById(String guideId) async {
    final guide = await _getGuideById(guideId);
    if (guide == null) return null;
    return ProductionGuideData(
      guide: guide,
      blocks: await listBlocks(guide.id),
    );
  }

  Stream<ProductionGuideData?> watchGuideData(String itemId) async* {
    yield await getGuideData(itemId);
    final updates =
        db.tableUpdates(const TableUpdateQuery.any()).map((_) => null);
    await for (final _ in updates) {
      yield await getGuideData(itemId);
    }
  }

  Stream<ProductionGuideData?> watchGuideDataById(String guideId) async* {
    yield await getGuideDataById(guideId);
    final updates =
        db.tableUpdates(const TableUpdateQuery.any()).map((_) => null);
    await for (final _ in updates) {
      yield await getGuideDataById(guideId);
    }
  }

  Future<List<ProductionGuideBlock>> listBlocks(String guideId) async {
    final rows = await db.customSelect(
      '''
      SELECT id, guide_id, sort_order, type, text, file_name, file_path,
        mime_type, created_at, updated_at
      FROM item_production_guide_blocks
      WHERE guide_id = ?
      ORDER BY sort_order ASC, created_at ASC
      ''',
      variables: [Variable.withString(guideId)],
      readsFrom: const {},
    ).get();
    return rows.map(_blockFromRow).toList();
  }

  Future<ProductionGuideBlock> addTextBlock({
    required String itemId,
    required ProductionGuideBlockType type,
    required String text,
    String? guideId,
    String? afterBlockId,
  }) async {
    if (type == ProductionGuideBlockType.image) {
      throw ArgumentError.value(
          type, 'type', 'image type requires addImageBlock');
    }
    final data = guideId == null
        ? await getOrCreateGuide(itemId)
        : (await getGuideDataById(guideId))!;
    final now = DateTime.now();
    final block = ProductionGuideBlock(
      id: _uuid.v4(),
      guideId: data.guide.id,
      sortOrder: await _nextSortOrderForInsert(
        data.guide.id,
        afterBlockId: afterBlockId,
      ),
      type: type,
      text: text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _insertBlock(block);
    await _touchGuide(data.guide.id);
    return block;
  }

  Future<ProductionGuideBlock> addImageBlock({
    required String itemId,
    required String fileName,
    required String filePath,
    required String mimeType,
    String? caption,
    String? guideId,
    String? afterBlockId,
  }) async {
    final data = guideId == null
        ? await getOrCreateGuide(itemId)
        : (await getGuideDataById(guideId))!;
    final now = DateTime.now();
    final relativePath =
        await const AppPathService().normalizeToRelativePath(filePath);
    final block = ProductionGuideBlock(
      id: _uuid.v4(),
      guideId: data.guide.id,
      sortOrder: await _nextSortOrderForInsert(
        data.guide.id,
        afterBlockId: afterBlockId,
      ),
      type: ProductionGuideBlockType.image,
      text: caption?.trim().isEmpty == true ? null : caption?.trim(),
      fileName: fileName,
      filePath: relativePath,
      mimeType: mimeType,
      createdAt: now,
      updatedAt: now,
    );
    await _insertBlock(block);
    await _touchGuide(data.guide.id);
    return block;
  }

  Future<void> updateGuideTitle(String guideId, String title) async {
    await db.customStatement(
      '''
      UPDATE item_production_guides
      SET title = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        title.trim().isEmpty ? '제작 가이드' : title.trim(),
        DateTime.now().toIso8601String(),
        guideId
      ],
    );
    db.notifyUpdates({const TableUpdate('item_production_guides')});
  }

  Future<void> setPrimaryGuide({
    required String itemId,
    required String guideId,
  }) async {
    await db.transaction(() async {
      await db.customStatement(
        'UPDATE item_production_guides SET is_primary = 0 WHERE item_id = ?',
        [itemId],
      );
      await db.customStatement(
        '''
        UPDATE item_production_guides
        SET is_primary = 1, updated_at = ?
        WHERE id = ?
        ''',
        [DateTime.now().toIso8601String(), guideId],
      );
    });
    db.notifyUpdates({const TableUpdate('item_production_guides')});
  }

  Future<void> deleteGuide(String guideId) async {
    final data = await getGuideDataById(guideId);
    if (data == null) return;
    for (final block in data.blocks) {
      final filePath = block.filePath;
      if (filePath != null && filePath.trim().isNotEmpty) {
        try {
          final file = await const AppPathService().resolveAppFile(filePath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
    await db.customStatement(
      'DELETE FROM item_production_guides WHERE id = ?',
      [guideId],
    );
    final remaining = await listGuides(data.guide.itemId);
    if (data.guide.isPrimary && remaining.isNotEmpty) {
      await setPrimaryGuide(
        itemId: data.guide.itemId,
        guideId: remaining.first.id,
      );
    }
    db.notifyUpdates({
      const TableUpdate('item_production_guides'),
      const TableUpdate('item_production_guide_blocks'),
    });
  }

  Future<void> updateBlockText(String blockId, String text) async {
    final nowIso = DateTime.now().toIso8601String();
    final guideId = await _guideIdForBlock(blockId);
    await db.customStatement(
      '''
      UPDATE item_production_guide_blocks
      SET text = ?, updated_at = ?
      WHERE id = ?
      ''',
      [text.trim(), nowIso, blockId],
    );
    if (guideId != null) await _touchGuide(guideId);
    db.notifyUpdates({const TableUpdate('item_production_guide_blocks')});
  }

  Future<void> deleteBlock(String blockId) async {
    final row = await db.customSelect(
      '''
      SELECT guide_id, file_path
      FROM item_production_guide_blocks
      WHERE id = ?
      ''',
      variables: [Variable.withString(blockId)],
    ).getSingleOrNull();
    if (row == null) return;

    final guideId = row.data['guide_id'] as String;
    final filePath = row.data['file_path'] as String?;
    if (filePath != null && filePath.trim().isNotEmpty) {
      try {
        final file = await const AppPathService().resolveAppFile(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    await db.customStatement(
      'DELETE FROM item_production_guide_blocks WHERE id = ?',
      [blockId],
    );
    await _renumberBlocks(guideId);
    await _touchGuide(guideId);
    db.notifyUpdates({const TableUpdate('item_production_guide_blocks')});
  }

  Future<void> moveBlock({
    required String guideId,
    required String blockId,
    required int delta,
  }) async {
    final blocks = await listBlocks(guideId);
    final index = blocks.indexWhere((block) => block.id == blockId);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= blocks.length) return;

    final reordered = [...blocks];
    final block = reordered.removeAt(index);
    reordered.insert(target, block);
    await db.transaction(() async {
      for (var i = 0; i < reordered.length; i++) {
        await db.customStatement(
          '''
          UPDATE item_production_guide_blocks
          SET sort_order = ?, updated_at = ?
          WHERE id = ?
          ''',
          [i, DateTime.now().toIso8601String(), reordered[i].id],
        );
      }
      await _touchGuide(guideId);
    });
    db.notifyUpdates({const TableUpdate('item_production_guide_blocks')});
  }

  Future<void> moveStep({
    required String guideId,
    required String stepBlockId,
    required int delta,
  }) async {
    final blocks = await listBlocks(guideId);
    final groups = <List<ProductionGuideBlock>>[];
    var looseBlocks = <ProductionGuideBlock>[];

    for (final block in blocks) {
      if (block.type == ProductionGuideBlockType.step) {
        if (looseBlocks.isNotEmpty) {
          groups.add(looseBlocks);
        }
        looseBlocks = [block];
      } else if (looseBlocks.isEmpty) {
        groups.add([block]);
      } else {
        looseBlocks.add(block);
      }
    }
    if (looseBlocks.isNotEmpty) {
      groups.add(looseBlocks);
    }

    final index = groups.indexWhere(
      (group) => group.any((block) => block.id == stepBlockId),
    );
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= groups.length) return;

    final reorderedGroups = [...groups];
    final group = reorderedGroups.removeAt(index);
    reorderedGroups.insert(target, group);
    final reordered = reorderedGroups.expand((group) => group).toList();

    await db.transaction(() async {
      for (var i = 0; i < reordered.length; i++) {
        await db.customStatement(
          '''
          UPDATE item_production_guide_blocks
          SET sort_order = ?, updated_at = ?
          WHERE id = ?
          ''',
          [i, DateTime.now().toIso8601String(), reordered[i].id],
        );
      }
      await _touchGuide(guideId);
    });
    db.notifyUpdates({const TableUpdate('item_production_guide_blocks')});
  }

  Future<ProductionGuide?> _getGuide(String itemId) async {
    final row = await db.customSelect(
      '''
      SELECT id, item_id, title, is_primary, sort_order, created_at, updated_at
      FROM item_production_guides
      WHERE item_id = ?
      ORDER BY is_primary DESC, sort_order ASC, updated_at DESC
      LIMIT 1
      ''',
      variables: [Variable.withString(itemId)],
    ).getSingleOrNull();
    return row == null ? null : _guideFromRow(row);
  }

  Future<ProductionGuide?> _getGuideById(String guideId) async {
    final row = await db.customSelect(
      '''
      SELECT id, item_id, title, is_primary, sort_order, created_at, updated_at
      FROM item_production_guides
      WHERE id = ?
      LIMIT 1
      ''',
      variables: [Variable.withString(guideId)],
    ).getSingleOrNull();
    return row == null ? null : _guideFromRow(row);
  }

  Future<int> _nextGuideSortOrder(String itemId) async {
    final row = await db.customSelect(
      '''
      SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order
      FROM item_production_guides
      WHERE item_id = ?
      ''',
      variables: [Variable.withString(itemId)],
    ).getSingle();
    return (row.data['next_order'] as int?) ?? 0;
  }

  Future<int> _nextSortOrder(String guideId) async {
    final row = await db.customSelect(
      '''
      SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order
      FROM item_production_guide_blocks
      WHERE guide_id = ?
      ''',
      variables: [Variable.withString(guideId)],
    ).getSingle();
    return (row.data['next_order'] as int?) ?? 0;
  }

  Future<int> _nextSortOrderForInsert(
    String guideId, {
    String? afterBlockId,
  }) async {
    if (afterBlockId == null) {
      return _nextSortOrder(guideId);
    }

    final row = await db.customSelect(
      '''
      SELECT sort_order
      FROM item_production_guide_blocks
      WHERE id = ? AND guide_id = ?
      LIMIT 1
      ''',
      variables: [
        Variable.withString(afterBlockId),
        Variable.withString(guideId),
      ],
    ).getSingleOrNull();
    if (row == null) return _nextSortOrder(guideId);

    final insertOrder = ((row.data['sort_order'] as int?) ?? -1) + 1;
    await db.customStatement(
      '''
      UPDATE item_production_guide_blocks
      SET sort_order = sort_order + 1
      WHERE guide_id = ? AND sort_order >= ?
      ''',
      [guideId, insertOrder],
    );
    return insertOrder;
  }

  Future<String?> _guideIdForBlock(String blockId) async {
    final row = await db.customSelect(
      'SELECT guide_id FROM item_production_guide_blocks WHERE id = ?',
      variables: [Variable.withString(blockId)],
    ).getSingleOrNull();
    return row?.data['guide_id'] as String?;
  }

  Future<void> _insertBlock(ProductionGuideBlock block) async {
    await db.customStatement(
      '''
      INSERT INTO item_production_guide_blocks (
        id, guide_id, sort_order, type, text, file_name, file_path, mime_type,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        block.id,
        block.guideId,
        block.sortOrder,
        block.type.name,
        block.text,
        block.fileName,
        block.filePath,
        block.mimeType,
        block.createdAt.toIso8601String(),
        block.updatedAt.toIso8601String(),
      ],
    );
    db.notifyUpdates({const TableUpdate('item_production_guide_blocks')});
  }

  Future<void> _touchGuide(String guideId) async {
    await db.customStatement(
      'UPDATE item_production_guides SET updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), guideId],
    );
    db.notifyUpdates({const TableUpdate('item_production_guides')});
  }

  Future<void> _renumberBlocks(String guideId) async {
    final blocks = await listBlocks(guideId);
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].sortOrder == i) continue;
      await db.customStatement(
        'UPDATE item_production_guide_blocks SET sort_order = ? WHERE id = ?',
        [i, blocks[i].id],
      );
    }
  }

  ProductionGuide _guideFromRow(QueryRow row) {
    final data = row.data;
    return ProductionGuide(
      id: data['id'] as String,
      itemId: data['item_id'] as String,
      title: data['title'] as String? ?? '기본 제작 가이드',
      isPrimary: ((data['is_primary'] as int?) ?? 0) == 1,
      sortOrder: (data['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  ProductionGuideBlock _blockFromRow(QueryRow row) {
    final data = row.data;
    final typeName = data['type'] as String;
    return ProductionGuideBlock(
      id: data['id'] as String,
      guideId: data['guide_id'] as String,
      sortOrder: data['sort_order'] as int,
      type: ProductionGuideBlockType.values.firstWhere(
        (type) => type.name == typeName,
        orElse: () => ProductionGuideBlockType.note,
      ),
      text: data['text'] as String?,
      fileName: data['file_name'] as String?,
      filePath: data['file_path'] as String?,
      mimeType: data['mime_type'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }
}
