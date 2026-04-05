import 'package:uuid/uuid.dart';

import '../repos/drift_unified_repo.dart';
import '../models/folder_node.dart';
import '../models/item.dart';

class FolderService {
  final DriftUnifiedRepo repo;
  final _uuid = const Uuid();

  FolderService(this.repo);

  String _newId() => _uuid.v4();

  /// 🔥 엔트리
  Future<void> copyFolderTree(String sourceFolderId) async {
    final source = await repo.folderById(sourceFolderId);
    if (source == null) return;

    final Map<String, String> folderIdMap = {};
    print('🚀 copyFolderTree 시작');

    await _copyFolderRecursive(
      source: source,
      newParentId: source.parentId,
      folderIdMap: folderIdMap,
    );
    print('🚀 폴더 복사 끝');
    await _copyAllItems(folderIdMap);
    print('🚀 아이템 복사 끝');
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
      final matched =
          folderIds.contains(p.l1Id) ||
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

    print('📦 folderIdMap: $folderIdMap');

    final allItems = await _getAllItemsInTree(folderIdMap.keys.toSet());

    print('📦 복사 대상 item 개수: ${allItems.length}');
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
    final newItem = Item(
      id: newId,
      name: '${item.name} copy',
      displayName: item.displayName,
      sku: item.sku,
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
    print('🔥 복사 시도: ${item.name}');
    print('👉 newL1=$newL1, newL2=$newL2, newL3=$newL3');
  }

  /// 🔍 itemPaths 조회
  Future<(String?, String?, String?)> _getItemPath(String itemId) async {
    final row = await (repo.db.select(repo.db.itemPaths)
      ..where((t) => t.itemId.equals(itemId)))
        .getSingleOrNull();

    if (row == null) return (null, null, null);

    return (row.l1Id, row.l2Id, row.l3Id);
  }
}