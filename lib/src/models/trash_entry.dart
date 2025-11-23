class TrashEntry {
  final String id;
  final String entityType;
  final String title;
  final DateTime deletedAt;

  const TrashEntry({
      required this.id,
      required this.entityType,
      required this.title,
      required this.deletedAt,
    });
}


