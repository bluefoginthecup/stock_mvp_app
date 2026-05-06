import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/app_schedule.dart';
import '../../repos/repo_interfaces.dart';
import 'schedule_edit_screen.dart';

class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openEditor({AppSchedule? schedule}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleEditScreen(schedule: schedule),
      ),
    );
  }

  List<AppSchedule> _schedulesForDay(
    List<AppSchedule> schedules,
    DateTime day,
  ) {
    return schedules.where((s) => _sameDay(s.date, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ScheduleRepo>();

    return Scaffold(
      appBar: AppBar(title: const Text('일정/할일')),
      body: StreamBuilder<List<AppSchedule>>(
        stream: repo.watchSchedules(),
        builder: (context, snapshot) {
          final schedules = snapshot.data ?? const <AppSchedule>[];
          final selectedSchedules = _schedulesForDay(schedules, _selectedDay);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: TableCalendar<AppSchedule>(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2100),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  availableGestures: AvailableGestures.horizontalSwipe,
                  headerStyle: const HeaderStyle(formatButtonVisible: false),
                  eventLoader: (day) => _schedulesForDay(schedules, day),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      final hasPending = events
                          .any((e) => e.status == AppScheduleStatus.pending);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  hasPending ? Colors.deepPurple : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(_dayOnly(_selectedDay)),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      _StatusLegend(
                        label: '할일',
                        color: Colors.deepPurple,
                        count: selectedSchedules
                            .where((s) => s.status == AppScheduleStatus.pending)
                            .length,
                      ),
                      const SizedBox(width: 10),
                      _StatusLegend(
                        label: '한일',
                        color: Colors.green,
                        count: selectedSchedules
                            .where((s) => s.status == AppScheduleStatus.done)
                            .length,
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedSchedules.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('선택한 날짜의 일정이 없습니다.')),
                )
              else
                SliverList.separated(
                  itemCount: selectedSchedules.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final schedule = selectedSchedules[index];
                    return ListTile(
                      leading: Checkbox(
                        value: schedule.status == AppScheduleStatus.done,
                        onChanged: (_) =>
                            repo.toggleScheduleStatus(schedule.id),
                      ),
                      title: Text(
                        schedule.title,
                        style: schedule.status == AppScheduleStatus.done
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      subtitle: schedule.body.trim().isEmpty
                          ? Text(schedule.statusLabel)
                          : Text('${schedule.statusLabel} · ${schedule.body}'),
                      trailing: IconButton(
                        tooltip: '수정',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(schedule: schedule),
                      ),
                      onTap: () => _openEditor(schedule: schedule),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('새 일정'),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final String label;
  final Color color;
  final int count;

  const _StatusLegend({
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label $count'),
      ],
    );
  }
}
