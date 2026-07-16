import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/main_tab_controller.dart';
import '../../services/playauto_sales_service.dart';

class SalesCalendarScreen extends StatefulWidget {
  const SalesCalendarScreen({super.key});

  @override
  State<SalesCalendarScreen> createState() => _SalesCalendarScreenState();
}

class _SalesCalendarScreenState extends State<SalesCalendarScreen> {
  Stream<PlayAutoSalesSnapshot>? _stream;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= _watchSales(const PlayAutoSalesService());
  }

  Stream<PlayAutoSalesSnapshot> _watchSales(PlayAutoSalesService service) {
    late final StreamController<PlayAutoSalesSnapshot> controller;
    Timer? refreshTimer;
    var queued = false;

    Future<void> emit() async {
      if (queued || controller.isClosed) return;
      queued = true;
      scheduleMicrotask(() async {
        queued = false;
        if (controller.isClosed) return;
        try {
          controller.add(await service.loadSnapshot());
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        }
      });
    }

    controller = StreamController<PlayAutoSalesSnapshot>(
      onListen: () {
        emit();
        refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          emit();
        });
      },
      onCancel: () async {
        refreshTimer?.cancel();
      },
    );
    return controller.stream;
  }

  String _money(double value) {
    final rounded = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final remaining = rounded.length - i;
      buffer.write(rounded[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    final sign = value < 0 ? '-' : '';
    return '$sign$buffer원';
  }

  String _compactMoney(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}억';
    }
    if (abs >= 10000) {
      return '${(value / 10000).toStringAsFixed(abs >= 100000 ? 0 : 1)}만';
    }
    return value.round().toString();
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    PlayAutoSalesSnapshot snapshot, {
    required bool selected,
    required bool today,
  }) {
    final summary = snapshot.dayOf(day);
    final amount = summary?.amount ?? 0;
    final background = selected
        ? const Color(0xFF6A7AF5)
        : today
            ? const Color(0xFFFFF0D8)
            : Colors.transparent;
    final foreground = selected ? Colors.white : const Color(0xFF17151C);
    final amountColor = selected ? Colors.white : const Color(0xFF2F9F70);

    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: amount > 0 && !selected
            ? Border.all(color: const Color(0xFFDDEEDB))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          if (amount > 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _compactMoney(amount),
                maxLines: 1,
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            )
          else
            const SizedBox(height: 13),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    return Scaffold(
      appBar: AppBar(
        title: const Text('매출 달력'),
        centerTitle: true,
      ),
      body: stream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<PlayAutoSalesSnapshot>(
              stream: stream,
              initialData: PlayAutoSalesSnapshot.empty,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('매출을 불러오지 못했습니다: ${snapshot.error}'));
                }
                final data = snapshot.data ?? PlayAutoSalesSnapshot.empty;
                final selectedSummary = data.dayOf(_selectedDay);
                final monthTotal = data.monthAmount(_focusedDay);

                return SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: _SalesTotalHeader(
                          month: _focusedDay,
                          amount: _money(monthTotal),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TableCalendar<void>(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2100),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(day, _selectedDay),
                          availableGestures: AvailableGestures.horizontalSwipe,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                          ),
                          onDaySelected: (selected, focused) {
                            setState(() {
                              _selectedDay = selected;
                              _focusedDay = focused;
                            });
                          },
                          onPageChanged: (focused) {
                            setState(() => _focusedDay = focused);
                          },
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) =>
                                _buildDayCell(context, day, data,
                                    selected: false, today: false),
                            todayBuilder: (context, day, focusedDay) =>
                                _buildDayCell(context, day, data,
                                    selected: false, today: true),
                            selectedBuilder: (context, day, focusedDay) =>
                                _buildDayCell(context, day, data,
                                    selected: true,
                                    today: isSameDay(day, DateTime.now())),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _SalesDayDetail(
                          date: _selectedDay,
                          summary: selectedSummary,
                          money: _money,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SalesTotalHeader extends StatelessWidget {
  final DateTime month;
  final String amount;

  const _SalesTotalHeader({
    required this.month,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF9F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9EFDE)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.payments_rounded, color: Color(0xFF2F9F70)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${month.year}년 ${month.month}월 매출',
                style: const TextStyle(
                  color: Color(0xFF1F5F41),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                color: Color(0xFF1D7A4B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesDayDetail extends StatelessWidget {
  final DateTime date;
  final PlayAutoSalesDay? summary;
  final String Function(double value) money;

  const _SalesDayDetail({
    required this.date,
    required this.summary,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null || summary.orders.isEmpty) {
      return Center(
        child: Text(
          '${date.month}월 ${date.day}일 주문 매출이 없습니다.',
          style: const TextStyle(
            color: Color(0xFF7A7480),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: summary.orders.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SelectedDayTotal(
            date: date,
            orderCount: summary.orderCount,
            amount: money(summary.amount),
          );
        }
        final order = summary.orders[index - 1];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE9E2F5)),
          ),
          leading: const Icon(Icons.receipt_long_rounded),
          title: Text(
            order.customer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            [
              order.shopName,
              '품목 ${order.lineCount}개',
              '수량 ${order.quantity}개',
            ].join(' · '),
          ),
          trailing: Text(
            money(order.amount),
            style: const TextStyle(
              color: Color(0xFF2F9F70),
              fontWeight: FontWeight.w900,
            ),
          ),
          onTap: () => context.read<MainTabController>().openShellRoute(
                '/playauto-test',
              ),
        );
      },
    );
  }
}

class _SelectedDayTotal extends StatelessWidget {
  final DateTime date;
  final int orderCount;
  final String amount;

  const _SelectedDayTotal({
    required this.date,
    required this.orderCount,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${date.month}월 ${date.day}일 주문 $orderCount건',
              style: const TextStyle(
                color: Color(0xFF2B2930),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF1D7A4B),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
