import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/app_schedule.dart';
import '../../repos/repo_interfaces.dart';
import '../../utils/tag_utils.dart';
import 'schedule_detail_screen.dart';
import 'schedule_edit_screen.dart';

class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isCalendarView = true;
  AppScheduleStatus _listStatus = AppScheduleStatus.pending;
  String _query = '';
  String? _selectedTag;
  final _searchController = TextEditingController();
  final Set<AppScheduleStatus> _calendarStatusFilter = {
    AppScheduleStatus.pending,
    AppScheduleStatus.done,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _openDetail(AppSchedule schedule) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleDetailScreen(schedule: schedule),
      ),
    );
  }

  List<AppSchedule> _schedulesForDay(
    List<AppSchedule> schedules,
    DateTime day,
  ) {
    return schedules.where((s) => _sameDay(s.date, day)).toList();
  }

  List<AppSchedule> _filterByQuery(List<AppSchedule> schedules) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return schedules;
    return schedules.where((s) {
      return s.title.toLowerCase().contains(query) ||
          s.body.toLowerCase().contains(query);
    }).toList();
  }

  List<AppSchedule> _filterBySelectedTag(List<AppSchedule> schedules) {
    final tag = _selectedTag;
    if (tag == null) return schedules;
    return schedules.where((schedule) => schedule.tags.contains(tag)).toList();
  }

  void _sortPinnedFirst(List<AppSchedule> schedules) {
    schedules.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '제목 / 내용 검색',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() => _query = value.trim().toLowerCase());
        },
      ),
    );
  }

  Widget _buildTagFilterBar(List<AppSchedule> schedules) {
    final tags = collectTagsFromSchedules(schedules).toList();
    final selectedTag = _selectedTag;
    if (selectedTag != null && !tags.contains(selectedTag)) {
      tags.add(selectedTag);
    }
    if (tags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('전체'),
              selected: _selectedTag == null,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedTag = null),
            ),
          ),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text('#$tag'),
                selected: _selectedTag == tag,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedTag = tag),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarStatusChip(AppScheduleStatus status) {
    final selected = _calendarStatusFilter.contains(status);
    final color =
        status == AppScheduleStatus.pending ? Colors.deepPurple : Colors.green;
    final label = status == AppScheduleStatus.pending ? '할일' : '한일';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: color.withValues(alpha: 0.18),
        backgroundColor: Colors.grey.shade200,
        onSelected: (_) {
          setState(() {
            if (selected) {
              _calendarStatusFilter.remove(status);
            } else {
              _calendarStatusFilter.add(status);
            }
          });
        },
      ),
    );
  }

  Widget _buildCalendarStatusFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          _buildCalendarStatusChip(AppScheduleStatus.pending),
          _buildCalendarStatusChip(AppScheduleStatus.done),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(AppSchedule schedule) {
    final repo = context.read<ScheduleRepo>();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Checkbox(
        value: schedule.status == AppScheduleStatus.done,
        onChanged: (_) => repo.toggleScheduleStatus(schedule.id),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              schedule.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: schedule.status == AppScheduleStatus.done
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    )
                  : null,
            ),
          ),
          if (schedule.isPinned)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.push_pin, size: 16, color: Colors.deepPurple),
            ),
        ],
      ),
      subtitle: _ScheduleTileSubtitle(schedule: schedule),
      trailing: schedule.isPinned
          ? IconButton(
              tooltip: '고정 해제',
              icon: const Icon(Icons.push_pin, size: 18),
              color: Colors.deepPurple,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              onPressed: () {
                repo.updateSchedule(
                  schedule.copyWith(
                    isPinned: false,
                    updatedAt: DateTime.now(),
                  ),
                );
              },
            )
          : null,
      onTap: () => _openDetail(schedule),
    );
  }

  Widget _buildCalendarBody(
    List<AppSchedule> schedules, {
    required List<AppSchedule> tagSourceSchedules,
  }) {
    final filteredSchedules = schedules
        .where((s) => _calendarStatusFilter.contains(s.status))
        .toList();
    final selectedSchedules = _schedulesForDay(filteredSchedules, _selectedDay);
    _sortPinnedFirst(selectedSchedules);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildSearchField()),
        SliverToBoxAdapter(child: _buildTagFilterBar(tagSourceSchedules)),
        SliverToBoxAdapter(child: _buildCalendarStatusFilterBar()),
        SliverToBoxAdapter(
          child: TableCalendar<AppSchedule>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            availableGestures: AvailableGestures.horizontalSwipe,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            eventLoader: (day) => _schedulesForDay(filteredSchedules, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                final hasPending =
                    events.any((e) => e.status == AppScheduleStatus.pending);
                final hasDone =
                    events.any((e) => e.status == AppScheduleStatus.done);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasPending)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasDone)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: Colors.green,
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
            itemBuilder: (context, index) =>
                _buildScheduleTile(selectedSchedules[index]),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }

  Widget _buildListBody(
    List<AppSchedule> schedules, {
    required List<AppSchedule> tagSourceSchedules,
  }) {
    final list = schedules.where((s) => s.status == _listStatus).toList();
    _sortPinnedFirst(list);

    return Column(
      children: [
        _buildSearchField(),
        _buildTagFilterBar(tagSourceSchedules),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SegmentedButton<AppScheduleStatus>(
            segments: const [
              ButtonSegment(
                value: AppScheduleStatus.pending,
                label: Text('할일'),
                icon: Icon(Icons.radio_button_unchecked),
              ),
              ButtonSegment(
                value: AppScheduleStatus.done,
                label: Text('한일'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {_listStatus},
            onSelectionChanged: (values) {
              setState(() => _listStatus = values.first);
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? (_listStatus == AppScheduleStatus.pending
                            ? '할일이 없습니다.'
                            : '한일이 없습니다.')
                        : '검색 결과가 없습니다.',
                  ),
                )
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final schedule = list[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(72, 6, 16, 0),
                          child: Text(
                            DateFormat('yyyy-MM-dd')
                                .format(_dayOnly(schedule.date)),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                        ),
                        _buildScheduleTile(schedule),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ScheduleRepo>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정/할일'),
        actions: [
          IconButton(
            tooltip: _isCalendarView ? '리스트 보기' : '캘린더 보기',
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_today),
            onPressed: () {
              setState(() => _isCalendarView = !_isCalendarView);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppSchedule>>(
        stream: repo.watchSchedules(),
        builder: (context, snapshot) {
          final queryFiltered =
              _filterByQuery(snapshot.data ?? const <AppSchedule>[]);
          final schedules = _filterBySelectedTag(queryFiltered);

          return _isCalendarView
              ? _buildCalendarBody(
                  schedules,
                  tagSourceSchedules: queryFiltered,
                )
              : _buildListBody(
                  schedules,
                  tagSourceSchedules: queryFiltered,
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

class _ScheduleTileSubtitle extends StatelessWidget {
  final AppSchedule schedule;

  const _ScheduleTileSubtitle({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final body = schedule.body.trim();
    final tags = schedule.tags;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            schedule.statusLabel,
            style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  Chip(
                    label: Text('#$tag'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: textTheme.labelSmall,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
