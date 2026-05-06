import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import '../../models/calendar_event.dart';
import 'work_detail_screen.dart';
import '../../services/inventory_service.dart'; // ✅ 추가
import '../../ui/common/common_calendar_view.dart';
import 'widgets/work_row.dart';

//다국어 앱 셋팅
import '../../ui/common/ui.dart';

class WorkListScreen extends StatefulWidget {
  const WorkListScreen({super.key});

  @override
  State<WorkListScreen> createState() => _WorkListScreenState();
}

class _WorkListScreenState extends State<WorkListScreen> {
  bool _isCalendarView = false;
  DateTime? _focusedDay;
  final Set<WorkStatus> _statusFilter = {
    WorkStatus.planned,
    WorkStatus.inProgress,
  };

  Color _statusFilterColor(WorkStatus status) {
    switch (status) {
      case WorkStatus.planned:
        return Colors.grey;
      case WorkStatus.inProgress:
        return Colors.blue;
      case WorkStatus.done:
        return Colors.green;
      case WorkStatus.canceled:
        return Colors.redAccent;
    }
  }

  String _statusFilterLabel(WorkStatus status) {
    switch (status) {
      case WorkStatus.planned:
        return '예정';
      case WorkStatus.inProgress:
        return '진행중';
      case WorkStatus.done:
        return '완료';
      case WorkStatus.canceled:
        return '취소';
    }
  }

  Widget _buildStatusFilterChip(WorkStatus status) {
    final selected = _statusFilter.contains(status);
    final color = _statusFilterColor(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(_statusFilterLabel(status)),
          ],
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: color.withValues(alpha: 0.2),
        backgroundColor: Colors.grey.shade200,
        onSelected: (_) {
          setState(() {
            if (selected) {
              _statusFilter.remove(status);
            } else {
              _statusFilter.add(status);
            }
          });
        },
      ),
    );
  }

  Widget _buildStatusFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _buildStatusFilterChip(WorkStatus.planned),
          _buildStatusFilterChip(WorkStatus.inProgress),
          _buildStatusFilterChip(WorkStatus.done),
          _buildStatusFilterChip(WorkStatus.canceled),
        ],
      ),
    );
  }

  DateTime _calendarDateOf(Work w) {
    switch (w.status) {
      case WorkStatus.done:
        return w.finishedAt ?? w.updatedAt ?? w.createdAt;
      case WorkStatus.inProgress:
        return w.startedAt ?? w.updatedAt ?? w.createdAt;
      case WorkStatus.planned:
        return w.createdAt;
      case WorkStatus.canceled:
        return w.updatedAt ?? w.createdAt;
    }
  }

  CalendarEventType _calendarTypeOf(Work w) {
    switch (w.status) {
      case WorkStatus.planned:
        return CalendarEventType.workPlanned;
      case WorkStatus.inProgress:
        return CalendarEventType.workInProgress;
      case WorkStatus.done:
        return CalendarEventType.workDone;
      case WorkStatus.canceled:
        return CalendarEventType.workPlanned;
    }
  }

  Future<Map<String, String>> _loadItemNames(
    ItemRepo itemRepo,
    List<Work> works,
  ) async {
    final names = <String, String>{};
    final itemIds = works.map((w) => w.itemId).toSet();

    for (final itemId in itemIds) {
      try {
        final name = await itemRepo.nameOf(itemId);
        final trimmed = name?.trim();
        if (trimmed != null && trimmed.isNotEmpty) {
          names[itemId] = trimmed;
        }
      } catch (_) {}
    }

    return names;
  }

  CalendarEvent _calendarEventOf(Work w, Map<String, String> itemNames) {
    final itemName = itemNames[w.itemId] ??
        context.t.work_row_item_fallback(shortId(w.itemId));

    return CalendarEvent(
      date: _calendarDateOf(w),
      type: _calendarTypeOf(w),
      title: '$itemName ×${w.qty}',
      subtitle: Labels.workStatus(context, w.status),
      refId: w.id,
      searchText: '${w.id} ${w.itemId} $itemName ${w.orderId ?? ''}',
    );
  }

  void _openWorkDetail(Work w) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkDetailScreen(work: w)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
    final itemRepo = context.read<ItemRepo>();
    //  final inmem = context.read<InMemoryRepo>();
    // print('[WorkListScreen] using InMemoryRepo instance = ${identityHashCode(inmem)}'); // ✅ 추가
    final inv = context.read<InventoryService>(); // ✅ 재고/전이 오케스트레이션

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.work_list_title),
        actions: [
          IconButton(
            tooltip: _isCalendarView ? '목록 보기' : '캘린더 보기',
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_today),
            onPressed: () {
              setState(() {
                _isCalendarView = !_isCalendarView;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Work>>(
        stream: workRepo.watchAllWorks(),
        builder: (context, snap) {
          final rawList = snap.data ?? const <Work>[];
          final list =
              rawList.where((w) => _statusFilter.contains(w.status)).toList();
          if (rawList.isEmpty) {
            return Column(
              children: [
                _buildStatusFilterBar(),
                Expanded(child: Center(child: Text(context.t.work_list_empty))),
              ],
            );
          }
          if (list.isEmpty) {
            return Column(
              children: [
                _buildStatusFilterBar(),
                const Expanded(
                  child: Center(child: Text('선택한 상태의 작업이 없습니다.')),
                ),
              ],
            );
          }
          if (_isCalendarView) {
            final workById = {for (final w in list) w.id: w};

            return FutureBuilder<Map<String, String>>(
              future: _loadItemNames(itemRepo, list),
              builder: (context, itemNameSnap) {
                final itemNames = itemNameSnap.data ?? const <String, String>{};
                final events = list
                    .map((w) => _calendarEventOf(w, itemNames))
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildStatusFilterBar(),
                      CommonCalendarView(
                        events: events,
                        focusedDay: _focusedDay,
                        scrollEvents: false,
                        expandedBuilder: (e) {
                          final w = workById[e.refId];
                          if (w == null) return const SizedBox.shrink();
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: WorkRow(
                              w: w,
                              onStart: (w.status == WorkStatus.planned)
                                  ? () => inv.startWork(w.id)
                                  : null,
                              onDone: (w.status == WorkStatus.inProgress)
                                  ? () => inv.completeWork(w.id)
                                  : null,
                              onTap: () => _openWorkDetail(w),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
          return Column(
            children: [
              _buildStatusFilterBar(),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final w = list[i];

                    return WorkRow(
                      w: w,
                      // ✅ planned → inProgress : planned Txn 생성 + 상태 전환
                      onStart: (w.status == WorkStatus.planned)
                          ? () => inv.startWork(w.id)
                          : null,
                      // ✅ inProgress → done : actual Txn 생성 + 완료 처리
                      onDone: (w.status == WorkStatus.inProgress)
                          ? () => inv.completeWork(w.id)
                          : null,
                      onTap: () => _openWorkDetail(w),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
