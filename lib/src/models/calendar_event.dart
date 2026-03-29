enum CalendarEventType {
  purchaseOrderDate,   // 발주일
  purchaseEta,         // 입고 예정일
  paymentDate,         // 결제일
  vatInvoiceDate,         // 세금계산서
  inbound,
  memo,
}

class CalendarEvent {
  final DateTime date;
  final CalendarEventType type;
  final String title;
  final String refId;
  final bool? isPaid;
  final String? subtitle;

  const CalendarEvent({
    required this.date,
    required this.type,
    required this.title,
    this.subtitle,
    required this.refId,
    this.isPaid,

  });

  /// 날짜 비교용 (시간 제거)
  DateTime get normalizedDate =>
      DateTime(date.year, date.month, date.day);
}