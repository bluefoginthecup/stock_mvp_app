import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/calendar_event.dart';

class CommonCalendarView extends StatefulWidget {
  final List<CalendarEvent> events;
  final void Function(CalendarEvent event)? onEventTap;

  const CommonCalendarView({
    super.key,
    required this.events,
    this.onEventTap, // 👈 추가
  });

  @override
  State<CommonCalendarView> createState() => _CommonCalendarViewState();
}

class _CommonCalendarViewState extends State<CommonCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents =
    _getEventsForDay(_selectedDay ?? _focusedDay);

    return Column(
      children: [
        /// 📅 캘린더
        TableCalendar<CalendarEvent>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
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

              return ListTile(
                leading: Icon(_iconForType(e.type)),
                title: Text(e.title),
                subtitle: Text(_typeLabel(e.type)),
                onTap: () {
                  if (widget.onEventTap != null) {
                    widget.onEventTap!(e);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 아이콘
  IconData _iconForType(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.purchase:
        return Icons.shopping_cart;
      case CalendarEventType.inbound:
        return Icons.inventory;
      case CalendarEventType.memo:
        return Icons.note;
    }
  }

  /// 라벨
  String _typeLabel(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.purchase:
        return '발주';
      case CalendarEventType.inbound:
        return '입출고';
      case CalendarEventType.memo:
        return '메모';
    }
  }
}