// lib/src/models/trash_entry.dart
class TrashEntry {
  final String id;
  final String entityType; // 'item' | 'order' | 'txn' | 'work' | 'po'
  final String title;
  final DateTime deletedAt;

  const TrashEntry({
    required this.id,
    required this.entityType,
    required this.title,
    required this.deletedAt,
  });
}
