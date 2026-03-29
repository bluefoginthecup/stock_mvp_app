import '../models/calendar_event.dart';
import '../models/purchase_order.dart';

List<CalendarEvent> mapPurchaseToEvents(List<PurchaseOrder> list) {
  return list.map((p) {
    return CalendarEvent(
      date: p.eta, // 🔥 핵심: ETA 기준
      type: CalendarEventType.purchase,
      title: p.supplierName,
      refId: p.id,
    );
  }).toList();
}