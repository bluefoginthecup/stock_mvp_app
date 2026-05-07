class ScheduleAttachment {
  final String id;
  final String scheduleId;
  final String fileName;
  final String filePath;
  final String mimeType;
  final DateTime createdAt;

  const ScheduleAttachment({
    required this.id,
    required this.scheduleId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.createdAt,
  });
}
