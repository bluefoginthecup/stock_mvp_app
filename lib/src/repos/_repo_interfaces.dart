  // lib/src/repos/repo_interfaces.dart

import '../models/folder_node.dart';
import '../models/item.dart';

/// Folders (Explorer-style)
abstract class FolderRepo {
  /// parentId == null => list root (depth=1)
  Future<List<FolderNode>> listChildren(String? parentId);

  /// Returns the created node
  Future<FolderNode> createFolder({
    required String? parentId,
    required String name,
  });

  Future<void> renameFolder({
    required String id,
    required String newName,
  });

  /// Should fail (throw) if the folder has children or items under it
  Future<void> deleteFolder(String id);
}

/// Items with path-based listing/creation
abstract class ItemRepo {
  /// When l3 is provided, list items in that leaf; when only l1/l2 provided,
  /// you may choose to list items at that level (if you allow items at non-leaf levels),
  /// or simply return empty. Our Stage 6 UI lists items only at depth=3.
  Future<List<Item>> listByFolderPath({
    String? l1,
    String? l2,
    String? l3,
    String? keyword,
  });

  /// Create item under the given path (length 1..3). Returns when persisted.
  Future<void> createItemInPath({
    required List<String> pathIds, // [l1Id, l2Id?, l3Id?]
    required Item item,
  });

  // Keep your existing CRUD & list methods here (not repeated).
}
