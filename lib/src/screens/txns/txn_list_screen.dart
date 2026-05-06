import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/models/calendar_event.dart';
import 'package:stockapp_mvp/src/models/txn.dart';
import 'package:stockapp_mvp/src/models/types.dart';
import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'widgets/txn_row.dart';
import '../../ui/common/common_calendar_view.dart';
import '../../ui/common/ui.dart';
import 'package:stockapp_mvp/src/repos/drift_unified_repo.dart';

class TxnListScreen extends StatefulWidget {
  const TxnListScreen({super.key});

  @override
  State<TxnListScreen> createState() => _TxnListScreenState();
}

class _TxnListScreenState extends State<TxnListScreen> {
  bool _isCalendarView = false;
  DateTime? _focusedDay;
  final Set<TxnType> _typeFilter = {
    TxnType.in_,
    TxnType.out_,
  };

  @override
  void initState() {
    super.initState();
    // 프레임 이후에 최초 스냅샷 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriftUnifiedRepo>().listTxns();
    });
  }

  Future<void> _refresh() async {
    await context.read<DriftUnifiedRepo>().listTxns();
  }

  Color _typeFilterColor(TxnType type) {
    switch (type) {
      case TxnType.in_:
        return Colors.green;
      case TxnType.out_:
        return Colors.red;
    }
  }

  String _typeFilterLabel(TxnType type) {
    switch (type) {
      case TxnType.in_:
        return '입고';
      case TxnType.out_:
        return '출고';
    }
  }

  Widget _buildTypeFilterChip(TxnType type) {
    final selected = _typeFilter.contains(type);
    final color = _typeFilterColor(type);

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
            Text(_typeFilterLabel(type)),
          ],
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: color.withValues(alpha: 0.2),
        backgroundColor: Colors.grey.shade200,
        onSelected: (_) {
          setState(() {
            if (selected) {
              _typeFilter.remove(type);
            } else {
              _typeFilter.add(type);
            }
          });
        },
      ),
    );
  }

  Widget _buildTypeFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _buildTypeFilterChip(TxnType.in_),
          _buildTypeFilterChip(TxnType.out_),
        ],
      ),
    );
  }

  Future<Map<String, String>> _loadItemNames(
    ItemRepo itemRepo,
    List<Txn> txns,
  ) async {
    final names = <String, String>{};
    final itemIds = txns.map((t) => t.itemId).toSet();

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

  CalendarEvent _calendarEventOf(Txn txn, Map<String, String> itemNames) {
    final itemName = itemNames[txn.itemId] ?? '아이템 ${shortId(txn.itemId)}';
    final isInbound = txn.type == TxnType.in_;
    final direction = isInbound ? '입고' : '출고';

    return CalendarEvent(
      date: txn.ts,
      type: isInbound ? CalendarEventType.inbound : CalendarEventType.outbound,
      title: '$itemName ×${txn.qty.abs()}',
      subtitle: '$direction · ${txn.refType.name}',
      refId: txn.id,
      searchText:
          '${txn.id} ${txn.itemId} $itemName ${txn.refType.name} ${txn.refId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    // notifyListeners()를 구독하려면 read가 아니라 watch
    final txRepo = context.watch<DriftUnifiedRepo>();
    final itemRepo = context.read<ItemRepo>();
    final rawList = txRepo.snapshotTxnsDesc();
    final list = rawList.where((t) => _typeFilter.contains(t.type)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.dashboard_txns),
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(
          context: context,
          itemRepo: itemRepo,
          rawList: rawList,
          list: list,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ItemRepo itemRepo,
    required List<Txn> rawList,
    required List<Txn> list,
  }) {
    if (rawList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildTypeFilterBar(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(child: Text(context.t.txns_empty)),
          ),
        ],
      );
    }

    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildTypeFilterBar(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const Center(child: Text('선택한 유형의 입출고 기록이 없습니다.')),
          ),
        ],
      );
    }

    if (_isCalendarView) {
      final txnById = {for (final txn in list) txn.id: txn};

      return FutureBuilder<Map<String, String>>(
        future: _loadItemNames(itemRepo, list),
        builder: (context, itemNameSnap) {
          final itemNames = itemNameSnap.data ?? const <String, String>{};
          final events = list
              .map((txn) => _calendarEventOf(txn, itemNames))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildTypeFilterBar(),
                CommonCalendarView(
                  events: events,
                  focusedDay: _focusedDay,
                  scrollEvents: false,
                  expandedBuilder: (event) {
                    final txn = txnById[event.refId];
                    if (txn == null) return const SizedBox.shrink();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: TxnRow(t: txn),
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
        _buildTypeFilterBar(),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => TxnRow(t: list[i]),
          ),
        ),
      ],
    );
  }
}
