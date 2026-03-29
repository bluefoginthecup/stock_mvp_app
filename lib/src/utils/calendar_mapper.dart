import '../models/calendar_event.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';

List<CalendarEvent> mapPurchaseToEvents(
    List<PurchaseOrder> list,
    Map<String, List<PurchaseLine>> linesMap,
    ) {
    final events = <CalendarEvent>[];
    for (final p in list) {
      print('DEBUG 결제상태 → id: ${p.id}, paidAt: ${p.paidAt}');

      final lines = linesMap[p.id] ?? [];
      // 📦 발주일
      events.add(CalendarEvent(
        date: p.createdAt,
        type: CalendarEventType.purchaseOrderDate,
        title: '발주 - ${p.supplierName}',
        subtitle: lines.map((i) => i.name).join(', '),
        refId: p.id,
      ));

      // 🚚 입고 예정일
      events.add(CalendarEvent(
        date: p.eta,
        type: CalendarEventType.purchaseEta,
        title: '입고예정 - ${p.supplierName}',
        refId: p.id,
      ));

      final isPaid = p.paidAt != null;
      // 💰 결제 이벤트 (항상 생성)
      events.add(CalendarEvent(
        date: p.eta, // 👉 입고예정일 기준
        type: CalendarEventType.paymentDate,
        title: isPaid
            ? '결제완료 - ${p.supplierName}'
            : '미결제 - ${p.supplierName}',
        refId: p.id,
        isPaid: p.paidAt != null, // 🔥 핵심
      ));

      // 🧾 세금계산서
      if (p.vatInvoiceIssuedAt != null) {
        events.add(CalendarEvent(
          date: p.vatInvoiceIssuedAt!,
          type: CalendarEventType.vatInvoiceDate,
          title: '계산서 - ${p.supplierName}',
          refId: p.id,
        ));
      }
    }

    return events;
  }