import 'dart:async';

import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/work.dart';
import '../../models/types.dart';
import '../../models/calendar_event.dart';
import 'work_detail_screen.dart';
import '../../services/inventory_service.dart'; // ✅ 추가
import '../../ui/common/common_calendar_view.dart';
import '../../utils/korean_search.dart';
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
  Timer? _debounce;
  String _query = '';
  final _controller = TextEditingController();
  final Set<WorkStatus> _statusFilter = {
    WorkStatus.planned,
    WorkStatus.inProgress,
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _query = _controller.text.trim().toLowerCase());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: '아이템명(초성) / 주문자명 검색',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _controller.clear(),
                )
              : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
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

  Future<
      ({
        Map<String, String> customerNames,
        Map<String, String> itemNames,
      })> _loadSearchData(
    ItemRepo itemRepo,
    OrderRepo orderRepo,
    List<Work> works,
  ) async {
    final itemNames = await _loadItemNames(itemRepo, works);
    final customerNames = <String, String>{};
    final orderIds = works
        .map((w) => w.orderId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet();

    for (final orderId in orderIds) {
      try {
        final name = await orderRepo.customerNameOf(orderId);
        final trimmed = name?.trim();
        if (trimmed != null && trimmed.isNotEmpty) {
          customerNames[orderId] = trimmed;
        }
      } catch (_) {}
    }

    return (customerNames: customerNames, itemNames: itemNames);
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

  bool _containsInitials(String text, String query) {
    if (!looksLikeChosungQuery(query)) return false;
    final initials = toChosungString(text);
    final q = query.replaceAll(RegExp(r'\s+'), '');
    if (q.isEmpty) return false;

    var start = 0;
    for (final rune in q.runes) {
      final char = String.fromCharCode(rune);
      final next = initials.indexOf(char, start);
      if (next < 0) return false;
      start = next + 1;
    }

    return true;
  }

  bool _matchesText(
    String text,
    String query, {
    bool allowInitials = false,
  }) {
    if (query.isEmpty) return true;
    final normalizedText = normalizeForSearch(text);
    final normalizedQuery = normalizeForSearch(query);
    if (normalizedQuery.isNotEmpty &&
        normalizedText.contains(normalizedQuery)) {
      return true;
    }

    return allowInitials && _containsInitials(text, query);
  }

  bool _matchesQuery(
    Work w,
    Map<String, String> itemNames,
    Map<String, String> customerNames,
  ) {
    if (_query.isEmpty) return true;
    final itemName = itemNames[w.itemId] ?? '';
    final orderId = w.orderId ?? '';
    final customerName = customerNames[orderId] ?? '';

    return _matchesText(itemName, _query, allowInitials: true) ||
        _matchesText(customerName, _query) ||
        _matchesText(orderId, _query);
  }

  void _showSearchTip() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검색 TIP'),
        content: const Text(
          '아이템명은 초성으로도 검색할 수 있어요.\n'
          '예: “ㄱㄹ”처럼 입력해도 아이템을 찾을 수 있어요.\n\n'
          '주문자명으로도 작업을 검색할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _openWorkDetail(Work w) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkDetailScreen(work: w)),
    );
  }

  Future<void> _deleteWork(Work w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('작업 삭제'),
        content: const Text('이 작업을 작업 목록에서 삭제할까요? 삭제된 작업은 휴지통에서 확인할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<InventoryService>().deleteWorkSafe(w.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작업을 삭제했어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('작업 삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workRepo = context.read<WorkRepo>();
    final itemRepo = context.read<ItemRepo>();
    final orderRepo = context.read<OrderRepo>();
    //  final inmem = context.read<InMemoryRepo>();
    // print('[WorkListScreen] using InMemoryRepo instance = ${identityHashCode(inmem)}'); // ✅ 추가
    final inv = context.read<InventoryService>(); // ✅ 재고/전이 오케스트레이션

    return Scaffold(
      appBar: AppBar(
        title: const Text('작업 목록'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '검색 TIP',
            icon: const Icon(Icons.help_outline),
            onPressed: _showSearchTip,
          ),
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
          if (rawList.isEmpty) {
            return Column(
              children: [
                _buildSearchField(),
                _buildStatusFilterBar(),
                Expanded(child: Center(child: Text(context.t.work_list_empty))),
              ],
            );
          }

          return FutureBuilder<
              ({
                Map<String, String> customerNames,
                Map<String, String> itemNames,
              })>(
            future: _loadSearchData(itemRepo, orderRepo, rawList),
            builder: (context, searchSnap) {
              final itemNames =
                  searchSnap.data?.itemNames ?? const <String, String>{};
              final customerNames =
                  searchSnap.data?.customerNames ?? const <String, String>{};
              final statusList = rawList
                  .where((w) => _statusFilter.contains(w.status))
                  .toList();
              final list = statusList
                  .where((w) => _matchesQuery(w, itemNames, customerNames))
                  .toList();

              if (list.isEmpty) {
                final message =
                    _query.isEmpty ? '선택한 상태의 작업이 없습니다.' : '"$_query" 검색 결과 없음';
                return Column(
                  children: [
                    _buildSearchField(),
                    _buildStatusFilterBar(),
                    Expanded(child: Center(child: Text(message))),
                  ],
                );
              }

              if (_isCalendarView) {
                final workById = {for (final w in list) w.id: w};
                final events = list
                    .map((w) => _calendarEventOf(w, itemNames))
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSearchField(),
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
                              onDelete: () => _deleteWork(w),
                              onTap: () => _openWorkDetail(w),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  _buildSearchField(),
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
                          onDelete: () => _deleteWork(w),
                          onTap: () => _openWorkDetail(w),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
