import '../models/calendar_event.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';

String buildSubtitle(List<PurchaseLine> lines) {
  if (lines.isEmpty) return '';

  if (lines.length == 1) {
    return lines.first.name;
  }

  return '${lines.first.name} 외 ${lines.length - 1}건';
}

List<CalendarEvent> mapPurchaseToEvents(
    List<PurchaseOrder> list,
    Map<String, List<PurchaseLine>> linesMap,
    ) {
    final events = <CalendarEvent>[];
    for (final p in list) {
      print('DEBUG 결제상태 → id: ${p.id}, paidAt: ${p.paidAt}');

      final lines = linesMap[p.id] ?? [];
      // 📦 발주일
      final searchText = lines.map((l) => l.name).join(' ').toLowerCase();

      events.add(CalendarEvent(
        date: p.createdAt,
        type: CalendarEventType.purchaseOrderDate,
        title: '발주 - ${p.supplierName}',
        subtitle: buildSubtitle(lines),
        refId: p.id,
        searchText: searchText, // 🔥 추가
      ));

      // 🚚 입고 예정일
      events.add(CalendarEvent(
        date: p.eta,
        type: CalendarEventType.purchaseEta,
        title: '입고예정 - ${p.supplierName}',
        subtitle: buildSubtitle(lines),
        refId: p.id,
        searchText: searchText,
      ));

      final isPaid = p.paidAt != null;
      // 💰 결제 이벤트 (항상 생성)
      events.add(CalendarEvent(
        date: p.eta, // 👉 입고예정일 기준
        type: CalendarEventType.paymentDate,
        title: isPaid
            ? '결제완료 - ${p.supplierName}'
            : '미결제 - ${p.supplierName}',
        subtitle: buildSubtitle(lines),
        refId: p.id,
        isPaid: p.paidAt != null, // 🔥 핵심
        searchText: searchText,
      ));

      // 🧾 세금계산서
      if (p.vatInvoiceIssuedAt != null) {
        events.add(CalendarEvent(
          date: p.vatInvoiceIssuedAt!,
          type: CalendarEventType.vatInvoiceDate,
          title: '계산서 - ${p.supplierName}',
          subtitle: buildSubtitle(lines),
          refId: p.id,
          searchText: searchText,
        ));
      }
    }

    return events;
  }