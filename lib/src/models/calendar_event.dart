enum CalendarEventType {
  purchase,
  inbound,
  memo,
}

class CalendarEvent {
  final DateTime date;
  final CalendarEventType type;
  final String title;
  final String refId;

  const CalendarEvent({
    required this.date,
    required this.type,
    required this.title,
    required this.refId,
  });

  /// 날짜 비교용 (시간 제거)
  DateTime get normalizedDate =>
      DateTime(date.year, date.month, date.day);
}