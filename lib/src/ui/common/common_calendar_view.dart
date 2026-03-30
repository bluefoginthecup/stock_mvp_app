import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/calendar_event.dart';

class CommonCalendarView extends StatefulWidget {
  final List<CalendarEvent> events;
  final DateTime? focusedDay;
  final void Function(CalendarEvent event)? onEventTap;
  final Widget Function(CalendarEvent e)? expandedBuilder;

  const CommonCalendarView({
    super.key,
    required this.events,
    this.onEventTap, // 👈 추가
    this.expandedBuilder,
    this.focusedDay,
  });



  @override
  State<CommonCalendarView> createState() => _CommonCalendarViewState();
}


class _CommonCalendarViewState extends State<CommonCalendarView> {
  int _expandedIndex = -1;
  DateTime? _focusedDay;


  @override
  void didUpdateWidget(covariant CommonCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);

      if (widget.focusedDay != null &&
          !_isSameDate(widget.focusedDay, _focusedDay)) {
      setState(() {
        _focusedDay = widget.focusedDay!;
        _selectedDay = widget.focusedDay!;
        _expandedIndex = -1;
      });
    }
  }

  DateTime? _selectedDay;

    bool _isSameDate(DateTime? a, DateTime? b) {
        if (a == null || b == null) return false;
        return a.year == b.year &&
            a.month == b.month &&
            a.day == b.day;
      }

  DateTime _normalize(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// 날짜별 이벤트 필터
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final target = _normalize(day);

    return widget.events.where((e) {
      return _normalize(e.date) == target;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay ?? DateTime.now();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents =
    _getEventsForDay(_selectedDay ?? _focusedDay ?? DateTime.now());


    Color colorForEvent(CalendarEvent e) {

      // 🔥 미결제
      if (e.type == CalendarEventType.paymentDate && e.isPaid == false) {
        return Colors.red;
      }
      switch (e.type) {
        case CalendarEventType.purchaseOrderDate:
          return Colors.blue;      // 발주
        case CalendarEventType.purchaseEta:
          return Colors.green;     // 입고예정
        case CalendarEventType.paymentDate:
          return Colors.orange;    // 결제
        case CalendarEventType.vatInvoiceDate:
          return Colors.purple;    // 세금계산서
        default:
          return Colors.grey;
      }
    }
    return Column(
      children: [
        /// 📅 캘린더
        TableCalendar<CalendarEvent>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay ?? DateTime.now(),
          // 👇 이거 추가
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
          ),


          selectedDayPredicate: (day) =>
              isSameDay(_selectedDay, day),

          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },

          eventLoader: _getEventsForDay,



    calendarBuilders: CalendarBuilders(
    markerBuilder: (context, date, events) {
    if (events.isEmpty) return const SizedBox();

    return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: events.take(3).map((e) {
    final event = e as CalendarEvent;

    return Container(
    margin: const EdgeInsets.symmetric(horizontal: 1),
    width: 6,
    height: 6,
    decoration: BoxDecoration(
    color: colorForEvent(event),
    shape: BoxShape.circle,
    ),
    );
    }).toList(),
    );
    },
    ),
 calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),

        const SizedBox(height: 8),

        /// 📋 선택 날짜 이벤트 리스트
        Expanded(
          child: selectedEvents.isEmpty
              ? const Center(child: Text('이 날의 기록 없음'))
              : ListView.builder(
            itemCount: selectedEvents.length,
            itemBuilder: (_, i) {
              final e = selectedEvents[i];



              print('UI 확인 → type: ${e.type}, isPaid: ${e.isPaid}'); // 👈 여기

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorForEvent(e).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: Icon(
                        _iconForType(e),
                        color: colorForEvent(e),
                      ),
                      title: Text(e.title),
                      subtitle: Text(
                        e.subtitle ?? _typeLabel(e.type),
                      ),
                      onTap: () {
                        setState(() {
                          _expandedIndex = _expandedIndex == i ? -1 : i;
                        });
                      },
                    ),
                  ),

                  if (_expandedIndex == i && widget.expandedBuilder != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: widget.expandedBuilder!(e),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 아이콘
  IconData _iconForType(CalendarEvent e) {
    switch (e.type) {
      case CalendarEventType.purchaseOrderDate:
        return Icons.shopping_cart;
      case CalendarEventType.purchaseEta:
        return Icons.local_shipping;
      case CalendarEventType.paymentDate:
        return Icons.payments;
      case CalendarEventType.vatInvoiceDate:
        return Icons.receipt;
      default:
        return Icons.event;
    }
  }

  String _typeLabel(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.purchaseOrderDate:
        return '발주';
      case CalendarEventType.purchaseEta:
        return '입고예정';
      case CalendarEventType.paymentDate:
        return '결제';
      case CalendarEventType.vatInvoiceDate:
        return '세금계산서';
      default:
        return '';
    }
  }
}
