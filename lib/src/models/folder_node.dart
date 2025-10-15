// lib/src/models/folder_node.dart
// Minimal folder node model for Explorer-style browsing

class FolderNode {
  final String id;
  final String name;
  final String? parentId; // null => root (depth=1)
  final int depth; // 1, 2, or 3
  final int order; // optional ordering within siblings

  const FolderNode({
    required this.id,
    required this.name,
    required this.depth,
    this.parentId,
    this.order = 0,
  });

  FolderNode copyWith({
    String? name,
    String? parentId,
    int? depth,
    int? order,
  }) => FolderNode(
        id: id,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        depth: depth ?? this.depth,
        order: order ?? this.order,
      );
}
