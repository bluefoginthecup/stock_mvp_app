
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/purchase_order.dart';
import '../models/work.dart'; // 네 경로에 맞춰 수정
// ↑ 경로 혼재되어 있으면 맞춰 변경해줘!

/// UI 전용 DTO
@immutable
class TimelineBar {
  final String lane; // 'ORDER' | 'PROCUREMENT' | 'PRODUCTION'
  final String id;
  final String label;
  final DateTime start;     // day-level (Asia/Seoul)
  final DateTime? end;      // null => 진행중(오늘까지 표시)
  final List<TimelineMarker> markers;
  final Map<String, dynamic> meta;

  const TimelineBar({
    required this.lane,
    required this.id,
    required this.label,
    required this.start,
    this.end,
    this.markers = const [],
    this.meta = const {},
  });
}

@immutable
class TimelineMarker {
  final DateTime date; // day-level
  final String kind;   // 'ship' | 'workStart' | 'done' | 'poDone' ...
  const TimelineMarker({required this.date, required this.kind});
}

@immutable
class TimelineData {
  final List<TimelineBar> bars;
  final DateTime rangeStart; // 화면 초기 뷰포트 추천
  final DateTime rangeEnd;
  const TimelineData({required this.bars, required this.rangeStart, required this.rangeEnd});
}

DateTime _asLocalDate(DateTime dt) {
  final l = dt.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime _today() {
  final now = DateTime.now().toLocal();
  return DateTime(now.year, now.month, now.day);
}

class TimelineRepo {
  final Future<Order> Function(String orderId) getOrderById;
  final Future<List<PurchaseOrder>> Function(String orderId) listPOsByOrderId;
  final Future<List<Work>> Function(String orderId) listWorksByOrderId;

  const TimelineRepo({
    required this.getOrderById,
    required this.listPOsByOrderId,
    required this.listWorksByOrderId,
  });

  Future<TimelineData> fetchOrderTimeline(String orderId) async {
    final order = await getOrderById(orderId);
    final pos   = await listPOsByOrderId(orderId);
    final works = await listWorksByOrderId(orderId);

    final bars = <TimelineBar>[];
    final today = _today();

    // ORDER lane
    final orderStart = _asLocalDate(order.date);
    final orderEnd   = order.shippedAt != null ? _asLocalDate(order.shippedAt!) : null;
    bars.add(TimelineBar(
      lane: 'ORDER',
      id: order.id,
      label: '주문 전체',
      start: orderStart,
      end: orderEnd,
      markers: [
        if (order.shippedAt != null) TimelineMarker(date: _asLocalDate(order.shippedAt!), kind: 'ship'),
      ],
      meta: {'type': 'order', 'customer': order.customer},
    ));

    // PROCUREMENT lane (orderId 연동 발주만)
    for (final po in pos.where((p) => p.orderId == order.id && p.isDeleted == false)) {
      final start = _asLocalDate(po.createdAt);
      final end   = po.receivedAt != null ? _asLocalDate(po.receivedAt!) : null;
      bars.add(TimelineBar(
        lane: 'PROCUREMENT',
        id: po.id,
        label: po.supplierName.isNotEmpty ? po.supplierName : '발주',
        start: start,
        end: end,
        markers: const [],
        meta: {'type':'po'},
      ));
    }

    // PRODUCTION lane
    for (final w in works.where((w) => w.isDeleted == false)) {
      final start = _asLocalDate(w.createdAt);
      final end   = w.finishedAt != null ? _asLocalDate(w.finishedAt!) : null;
      final markers = <TimelineMarker>[
        if (w.startedAt  != null) TimelineMarker(date: _asLocalDate(w.startedAt!),  kind: 'workStart'),
        if (w.finishedAt != null) TimelineMarker(date: _asLocalDate(w.finishedAt!), kind: 'done'),
      ];
      bars.add(TimelineBar(
        lane: 'PRODUCTION',
        id: w.id,
        label: '작업 ${w.qty}개', // itemName 조인해서 'Rouen Gray ×10'로 바꿔도 OK
        start: start,
        end: end,
        markers: markers,
        meta: {'type':'work', 'qty': w.qty, 'itemId': w.itemId},
      ));
    }

    // range 계산 (±3일 여백)
    DateTime minStart = orderStart;
    DateTime maxEnd   = orderEnd ?? today;
    for (final b in bars) {
      if (b.start.isBefore(minStart)) minStart = b.start;
      final e = b.end ?? today;
      if (e.isAfter(maxEnd)) maxEnd = e;
    }
    final rangeStart = minStart.subtract(const Duration(days: 3));
    final rangeEnd   = maxEnd.add(const Duration(days: 3));

    return TimelineData(bars: bars, rangeStart: rangeStart, rangeEnd: rangeEnd);
  }
}
