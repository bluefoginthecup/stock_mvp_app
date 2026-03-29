import '../models/calendar_event.dart';
import '../models/purchase_order.dart';


  List<CalendarEvent> mapPurchaseToEvents(List<PurchaseOrder> list) {
    final events = <CalendarEvent>[];

    for (final p in list) {

      // 📦 발주일
      events.add(CalendarEvent(
        date: p.createdAt,
        type: CalendarEventType.purchaseOrderDate,
        title: '발주 - ${p.supplierName}',
        refId: p.id,
      ));

      // 🚚 입고 예정일
      events.add(CalendarEvent(
        date: p.eta,
        type: CalendarEventType.purchaseEta,
        title: '입고예정 - ${p.supplierName}',
        refId: p.id,
      ));

      // 💰 결제일 (있을 때만)
      if (p.paidAt != null) {
        events.add(CalendarEvent(
          date: p.paidAt!,
          type: CalendarEventType.paymentDate,
          title: '결제 - ${p.supplierName}',
          refId: p.id,
        ));
      }

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