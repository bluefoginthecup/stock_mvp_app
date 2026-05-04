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

  CalendarEvent _calendarEventOf(Work w) {
    return CalendarEvent(
      date: _calendarDateOf(w),
      type: _calendarTypeOf(w),
      title: '작업 ×${w.qty}',
      subtitle: Labels.workStatus(context, w.status),
      refId: w.id,
      searchText: '${w.id} ${w.itemId} ${w.orderId ?? ''}',
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
          final list = (snap.data ?? const <Work>[])
              .where((w) => w.status != WorkStatus.canceled)
              .toList();
          if (list.isEmpty) {
            return Center(child: Text(context.t.work_list_empty));
          }
          if (_isCalendarView) {
            final workById = {for (final w in list) w.id: w};
            final events = list.map(_calendarEventOf).toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            return CommonCalendarView(
              events: events,
              focusedDay: _focusedDay,
              expandedBuilder: (e) {
                final w = workById[e.refId];
                if (w == null) return const SizedBox.shrink();
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            );
          }
          return ListView.separated(
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
          );
        },
      ),
    );
  }
}
