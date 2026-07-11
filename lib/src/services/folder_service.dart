import 'package:uuid/uuid.dart';

import '../repos/drift_unified_repo.dart';
import '../models/folder_node.dart';
import '../models/item.dart';

class FolderCloneOptions {
  final String replaceFrom;
  final String replaceTo;
  final String skuReplaceFrom;
  final String skuReplaceTo;
  final bool resetQty;
  final bool replaceSku;
  final bool copyBom;

  const FolderCloneOptions({
    required this.replaceFrom,
    required this.replaceTo,
    this.skuReplaceFrom = '',
    this.skuReplaceTo = '',
    this.resetQty = true,
    this.replaceSku = true,
    this.copyBom = true,
  });
}

class FolderCloneResult {
  final String sourceFolderName;
  final String newFolderName;
  final int folderCount;
  final int itemCount;
  final int bomRowCount;

  const FolderCloneResult({
    required this.sourceFolderName,
    required this.newFolderName,
    required this.folderCount,
    required this.itemCount,
    required this.bomRowCount,
  });
}

class FolderService {
  final DriftUnifiedRepo repo;
  final _uuid = const Uuid();

  FolderService(this.repo);

  String _newId() => _uuid.v4();

  String _replaceText(String value, FolderCloneOptions options) {
    return _replaceTextWith(
      value,
      replaceFrom: options.replaceFrom,
      replaceTo: options.replaceTo,
    );
  }

  String _replaceTextWith(
    String value, {
    required String replaceFrom,
    required String replaceTo,
  }) {
    replaceFrom = replaceFrom.trim();
    if (replaceFrom.isEmpty) return value;

    var replaced = value.replaceAll(replaceFrom, replaceTo);
    final parts = replaceFrom
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length <= 1) return replaced;

    final flexibleWhitespacePattern = parts.map(RegExp.escape).join(r'\s*');
    return replaced.replaceAll(
      RegExp(flexibleWhitespacePattern),
      replaceTo,
    );
  }

  String? _replaceNullableText(String? value, FolderCloneOptions options) {
    if (value == null || value.trim().isEmpty) return value;
    return _replaceText(value, options);
  }

  Map<String, dynamic>? _replaceAttrs(
    Map<String, dynamic>? attrs,
    FolderCloneOptions options,
  ) {
    if (attrs == null || attrs.isEmpty) return attrs;

    dynamic replaceValue(dynamic value) {
      if (value is String) return _replaceText(value, options);
      if (value is List) return value.map(replaceValue).toList();
      if (value is Map) {
        return value.map<String, dynamic>(
          (key, entry) => MapEntry(key.toString(), replaceValue(entry)),
        );
      }
      return value;
    }

    return attrs.map<String, dynamic>(
      (key, value) => MapEntry(key, replaceValue(value)),
    );
  }

  Future<String> _uniqueFolderName({
    required String? parentId,
    required String desiredName,
  }) async {
    final siblings = await repo.listFolderChildren(parentId);
    final names = siblings.map((e) => e.name).toSet();
    if (!names.contains(desiredName)) return desiredName;

    var index = 2;
    while (names.contains('$desiredName $index')) {
      index++;
    }
    return '$desiredName $index';
  }

  Future<FolderCloneResult> cloneFolderConfiguration({
    required String sourceFolderId,
    required FolderCloneOptions options,
  }) async {
    final source = await repo.folderById(sourceFolderId);
    if (source == null) {
      throw StateError('복제할 폴더를 찾을 수 없습니다.');
    }

    final folderIdMap = <String, String>{};
    final rootName = await _uniqueFolderName(
      parentId: source.parentId,
      desiredName: _replaceText(source.name, options),
    );

    await _cloneFolderRecursive(
      source: source,
      newParentId: source.parentId,
      folderIdMap: folderIdMap,
      options: options,
      overrideName: rootName,
    );

    final itemIdMap = await _cloneAllItems(folderIdMap, options);
    final bomCount = options.copyBom ? await _cloneBomRows(itemIdMap) : 0;

    return FolderCloneResult(
      sourceFolderName: source.name,
      newFolderName: rootName,
      folderCount: folderIdMap.length,
      itemCount: itemIdMap.length,
      bomRowCount: bomCount,
    );
  }

  Future<List<String>> sampleSkusInFolder(
    String sourceFolderId, {
    int limit = 8,
  }) async {
    final items = await _getAllItemsInTree({sourceFolderId});
    final skus = <String>[];
    final seen = <String>{};
    for (final item in items) {
      final sku = item.sku.trim();
      if (sku.isEmpty || !seen.add(sku)) continue;
      skus.add(sku);
      if (skus.length >= limit) break;
    }
    return skus;
  }

  Future<void> _cloneFolderRecursive({
    required FolderNode source,
    required String? newParentId,
    required Map<String, String> folderIdMap,
    required FolderCloneOptions options,
    String? overrideName,
  }) async {
    final newFolderId = _newId();
    folderIdMap[source.id] = newFolderId;

    final newFolder = FolderNode(
      id: newFolderId,
      name: overrideName ?? _replaceText(source.name, options),
      parentId: newParentId,
      depth: source.depth,
      order: source.order,
    );

    await repo.upsertFolderNode(newFolder);

    final children = await repo.getChildren(source.id);
    for (final child in children) {
      await _cloneFolderRecursive(
        source: child,
        newParentId: newFolderId,
        folderIdMap: folderIdMap,
        options: options,
      );
    }
  }

  Future<Map<String, String>> _cloneAllItems(
    Map<String, String> folderIdMap,
    FolderCloneOptions options,
  ) async {
    final result = <String, String>{};
    final allItems = await _getAllItemsInTree(folderIdMap.keys.toSet());
    final usedSkus = (await repo.listItems()).map((item) => item.sku).toSet();

    for (final item in allItems) {
      final newId = await _cloneItemWithMapping(
        item,
        folderIdMap,
        options,
        usedSkus,
      );
      result[item.id] = newId;
    }

    return result;
  }

  String _uniqueSku(String desiredSku, Set<String> usedSkus) {
    final baseSku = desiredSku.trim();
    if (baseSku.isEmpty) return '';
    if (usedSkus.add(baseSku)) return baseSku;

    var index = 2;
    while (!usedSkus.add('$baseSku-$index')) {
      index++;
    }
    return '$baseSku-$index';
  }

  String _cloneSku(
    Item item,
    FolderCloneOptions options,
    Set<String> usedSkus,
  ) {
    final desiredSku = options.replaceSku
        ? _replaceTextWith(
            item.sku,
            replaceFrom: options.skuReplaceFrom,
            replaceTo: options.skuReplaceTo,
          )
        : item.sku;
    return _uniqueSku(desiredSku, usedSkus);
  }

  Future<String> _cloneItemWithMapping(
    Item item,
    Map<String, String> folderIdMap,
    FolderCloneOptions options,
    Set<String> usedSkus,
  ) async {
    final newId = _newId();
    final path = await _getItemPath(item.id);

    final oldL1 = path.$1;
    final oldL2 = path.$2;
    final oldL3 = path.$3;

    final newL1 = oldL1 != null && folderIdMap.containsKey(oldL1)
        ? folderIdMap[oldL1]
        : oldL1;
    final newL2 = oldL2 != null && folderIdMap.containsKey(oldL2)
        ? folderIdMap[oldL2]
        : oldL2;
    final newL3 = oldL3 != null && folderIdMap.containsKey(oldL3)
        ? folderIdMap[oldL3]
        : oldL3;

    final newItem = Item(
      id: newId,
      name: _replaceText(item.name, options),
      displayName: _replaceNullableText(item.displayName, options),
      sku: _cloneSku(item, options, usedSkus),
      unit: item.unit,
      folder: item.folder,
      subfolder: item.subfolder,
      subsubfolder: item.subsubfolder,
      qty: options.resetQty ? 0 : item.qty,
      minQty: item.minQty,
      kind: item.kind,
      attrs: _replaceAttrs(item.attrs, options),
      unitIn: item.unitIn,
      unitOut: item.unitOut,
      conversionRate: item.conversionRate,
      conversionMode: item.conversionMode,
      stockHints: item.stockHints,
      supplierName: item.supplierName,
      defaultSupplierId: item.defaultSupplierId,
      defaultPrice: item.defaultPrice,
      defaultPurchasePrice: item.defaultPurchasePrice,
      defaultSalePrice: item.defaultSalePrice,
      reorderIntervalDays: item.reorderIntervalDays,
      reorderReminderEnabled: item.reorderReminderEnabled,
      reorderReminderDaysBefore: item.reorderReminderDaysBefore,
    );

    await repo.upsertItemWithPath(newItem, newL1, newL2, newL3);
    return newId;
  }

  Future<int> _cloneBomRows(Map<String, String> itemIdMap) async {
    if (itemIdMap.isEmpty) return 0;

    var copied = 0;
    final sourceIds = itemIdMap.keys.toSet();
    final rows = await repo.db.select(repo.db.bomRows).get();

    for (final row in rows) {
      if (!sourceIds.contains(row.parentItemId)) continue;

      final newParentId = itemIdMap[row.parentItemId];
      if (newParentId == null) continue;

      final newComponentId =
          itemIdMap[row.componentItemId] ?? row.componentItemId;

      await repo.db.customStatement(
        '''
        INSERT OR REPLACE INTO bom_rows
          (root, parent_item_id, component_item_id, kind, qty_per, waste_pct)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          row.root,
          newParentId,
          newComponentId,
          row.kind,
          row.qtyPer,
          row.wastePct,
        ],
      );
      copied++;
    }

    await repo.refreshBomSnapshot();
    return copied;
  }

  /// 🔥 엔트리
  Future<void> copyFolderTree(String sourceFolderId) async {
    final source = await repo.folderById(sourceFolderId);
    if (source == null) return;

    final Map<String, String> folderIdMap = {};

    await _copyFolderRecursive(
      source: source,
      newParentId: source.parentId,
      folderIdMap: folderIdMap,
    );
    await _copyAllItems(folderIdMap);
  }

  /// 🔁 폴더 복사
  Future<void> _copyFolderRecursive({
    required FolderNode source,
    required String? newParentId,
    required Map<String, String> folderIdMap,
  }) async {
    final newFolderId = _newId();

    folderIdMap[source.id] = newFolderId;

    final newFolder = FolderNode(
      id: newFolderId,
      name: '${source.name} copy',
      parentId: newParentId,
      depth: source.depth,
      order: source.order,
    );

    await repo.upsertFolderNode(newFolder);

    final children = await repo.getChildren(source.id);

    for (final child in children) {
      await _copyFolderRecursive(
        source: child,
        newParentId: newFolderId,
        folderIdMap: folderIdMap,
      );
    }
  }

  Future<List<Item>> _getAllItemsInTree(Set<String> folderIds) async {
    final result = <Item>[];
    final seen = <String>{};

    final rows = await repo.db.select(repo.db.itemPaths).get();

    for (final p in rows) {
      final matched = folderIds.contains(p.l1Id) ||
          folderIds.contains(p.l2Id) ||
          folderIds.contains(p.l3Id);

      if (!matched) continue;
      if (!seen.add(p.itemId)) continue;

      final item = await repo.getItem(p.itemId);
      if (item != null) {
        result.add(item);
      }
    }

    return result;
  }

  /// 📦 아이템 복사
  Future<void> _copyAllItems(Map<String, String> folderIdMap) async {
    final allItems = await _getAllItemsInTree(folderIdMap.keys.toSet());

    for (final item in allItems) {
      await _copyItemWithMapping(item, folderIdMap);
    }
  }

  /// 🎯 아이템 복사
  Future<void> _copyItemWithMapping(
    Item item,
    Map<String, String> folderIdMap,
  ) async {
    final newId = _newId();

    final path = await _getItemPath(item.id);

    final oldL1 = path.$1;
    final oldL2 = path.$2;
    final oldL3 = path.$3;

    // 🔥 핵심: 각각 매핑
    final newL1 = oldL1;

    final newL2 = oldL2 != null && folderIdMap.containsKey(oldL2)
        ? folderIdMap[oldL2]
        : oldL2;

    final newL3 = oldL3 != null && folderIdMap.containsKey(oldL3)
        ? folderIdMap[oldL3]
        : oldL3;

    // 👉 여기 중요 (id 안전하게 생성)
    final usedSkus = (await repo.listItems()).map((item) => item.sku).toSet();
    final newItem = Item(
      id: newId,
      name: '${item.name} copy',
      displayName: item.displayName,
      sku: _uniqueSku(item.sku, usedSkus),
      unit: item.unit,
      folder: item.folder,
      subfolder: item.subfolder,
      subsubfolder: item.subsubfolder,
      qty: item.qty,
      minQty: item.minQty,
      kind: item.kind,
      isFavorite: item.isFavorite,
      defaultPurchasePrice: item.defaultPurchasePrice,
      defaultSalePrice: item.defaultSalePrice,
    );

    await repo.upsertItemWithPath(
      newItem,
      newL1,
      newL2,
      newL3,
    );
  }

  /// 🔍 itemPaths 조회
  Future<(String?, String?, String?)> _getItemPath(String itemId) async {
    final row = await (repo.db.select(repo.db.itemPaths)
          ..where((t) => t.itemId.equals(itemId)))
        .getSingleOrNull();

    if (row == null) return (null, null, null);

    return (row.l1Id, row.l2Id, row.l3Id);
  }

  Future<void> copySingleItem(String itemId) async {
    final item = await repo.getItem(itemId);
    if (item == null) return;

    // 현재 폴더 매핑 없음 → 그대로 복사
    await _copyItemWithMapping(item, {});
  }

  Future<String?> copySingleItemWithOptions(
    String itemId,
    FolderCloneOptions options,
  ) async {
    final ids = await copyItemsWithOptions([itemId], options);
    return ids.isEmpty ? null : ids.first;
  }

  Future<List<String>> copyItemsWithOptions(
    List<String> itemIds,
    FolderCloneOptions options,
  ) async {
    final usedSkus = (await repo.listItems()).map((item) => item.sku).toSet();
    final itemIdMap = <String, String>{};

    for (final itemId in itemIds) {
      final item = await repo.getItem(itemId);
      if (item == null) continue;
      final newId = await _cloneItemWithMapping(item, {}, options, usedSkus);
      itemIdMap[item.id] = newId;
    }

    if (options.copyBom) {
      await _cloneBomRows(itemIdMap);
    }

    return itemIdMap.values.toList();
  }
}
