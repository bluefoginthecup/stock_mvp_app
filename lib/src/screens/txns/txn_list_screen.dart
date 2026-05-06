import 'dart:async';

import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/models/calendar_event.dart';
import 'package:stockapp_mvp/src/models/txn.dart';
import 'package:stockapp_mvp/src/models/types.dart';
import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'widgets/txn_row.dart';
import '../../ui/common/common_calendar_view.dart';
import '../../ui/common/ui.dart';
import '../../utils/korean_search.dart';
import 'package:stockapp_mvp/src/repos/drift_unified_repo.dart';

class TxnListScreen extends StatefulWidget {
  const TxnListScreen({super.key});

  @override
  State<TxnListScreen> createState() => _TxnListScreenState();
}

class _TxnListScreenState extends State<TxnListScreen> {
  bool _isCalendarView = false;
  DateTime? _focusedDay;
  Timer? _debounce;
  String _query = '';
  final _controller = TextEditingController();
  final Set<TxnType> _typeFilter = {
    TxnType.in_,
    TxnType.out_,
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

    // 프레임 이후에 최초 스냅샷 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriftUnifiedRepo>().listTxns();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: '아이템명(초성) / 거래처 / 참조 검색',
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

  Future<
      ({
        Map<String, String> itemNames,
        Map<String, String> partnerNames,
      })> _loadSearchData({
    required ItemRepo itemRepo,
    required OrderRepo orderRepo,
    required PurchaseOrderRepo purchaseRepo,
    required SupplierRepo supplierRepo,
    required WorkRepo workRepo,
    required List<Txn> txns,
  }) async {
    final itemNames = await _loadItemNames(itemRepo, txns);
    final partnerNames = <String, String>{};

    for (final txn in txns) {
      if (partnerNames.containsKey(txn.id)) continue;

      try {
        final name = await _partnerNameOf(
          txn,
          orderRepo: orderRepo,
          purchaseRepo: purchaseRepo,
          supplierRepo: supplierRepo,
          workRepo: workRepo,
        );
        final trimmed = name?.trim();
        if (trimmed != null && trimmed.isNotEmpty) {
          partnerNames[txn.id] = trimmed;
        }
      } catch (_) {}
    }

    return (itemNames: itemNames, partnerNames: partnerNames);
  }

  Future<String?> _partnerNameOf(
    Txn txn, {
    required OrderRepo orderRepo,
    required PurchaseOrderRepo purchaseRepo,
    required SupplierRepo supplierRepo,
    required WorkRepo workRepo,
  }) async {
    switch (txn.refType) {
      case RefType.order:
        return orderRepo.customerNameOf(txn.refId);
      case RefType.work:
        final work = await workRepo.getWorkById(txn.refId);
        final orderId = work?.orderId;
        if (orderId == null || orderId.trim().isEmpty) return null;
        return orderRepo.customerNameOf(orderId);
      case RefType.purchase:
        final purchase = await purchaseRepo.getPurchaseOrderById(txn.refId);
        final supplierId = purchase?.supplierId;
        if (supplierId != null && supplierId.trim().isNotEmpty) {
          final supplier = await supplierRepo.get(supplierId);
          final supplierName = supplier?.name.trim();
          if (supplierName != null && supplierName.isNotEmpty) {
            return supplierName;
          }
        }
        return purchase?.supplierName;
      case RefType.manual:
        return null;
    }
  }

  String _refTypeLabel(RefType type) {
    switch (type) {
      case RefType.order:
        return '주문';
      case RefType.work:
        return '작업';
      case RefType.purchase:
        return '발주';
      case RefType.manual:
        return '수동';
    }
  }

  CalendarEvent _calendarEventOf(Txn txn, Map<String, String> itemNames) {
    final itemName = itemNames[txn.itemId] ?? '아이템 ${shortId(txn.itemId)}';
    final isInbound = txn.type == TxnType.in_;
    final direction = isInbound ? '입고' : '출고';
    final refTypeLabel = _refTypeLabel(txn.refType);

    return CalendarEvent(
      date: txn.ts,
      type: isInbound ? CalendarEventType.inbound : CalendarEventType.outbound,
      title: '$itemName ×${txn.qty.abs()}',
      subtitle: '$direction · $refTypeLabel',
      refId: txn.id,
      searchText:
          '${txn.id} ${txn.itemId} $itemName $refTypeLabel ${txn.refType.name} ${txn.refId}',
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
    Txn txn,
    Map<String, String> itemNames,
    Map<String, String> partnerNames,
  ) {
    if (_query.isEmpty) return true;
    final itemName = itemNames[txn.itemId] ?? '';
    final partnerName = partnerNames[txn.id] ?? '';
    final refTypeLabel = _refTypeLabel(txn.refType);

    return _matchesText(itemName, _query, allowInitials: true) ||
        _matchesText(partnerName, _query) ||
        _matchesText(txn.refId, _query) ||
        _matchesText(refTypeLabel, _query) ||
        _matchesText(txn.refType.name, _query);
  }

  void _showSearchTip() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검색 TIP'),
        content: const Text(
          '아이템명은 초성으로도 검색할 수 있어요.\n'
          '예: “ㅇㄷ”처럼 입력해도 아이템을 찾을 수 있어요.\n\n'
          '거래처명, 참조 ID로 검색할 수 있어요.\n'
          '참조유형은 작업, 발주, 주문, 수동으로 검색할 수 있어요.',
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

  @override
  Widget build(BuildContext context) {
    // notifyListeners()를 구독하려면 read가 아니라 watch
    final txRepo = context.watch<DriftUnifiedRepo>();
    final itemRepo = context.read<ItemRepo>();
    final orderRepo = context.read<OrderRepo>();
    final purchaseRepo = context.read<PurchaseOrderRepo>();
    final supplierRepo = context.read<SupplierRepo>();
    final workRepo = context.read<WorkRepo>();
    final rawList = txRepo.snapshotTxnsDesc();
    final list = rawList.where((t) => _typeFilter.contains(t.type)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('입출고기록'),
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(
          context: context,
          itemRepo: itemRepo,
          orderRepo: orderRepo,
          purchaseRepo: purchaseRepo,
          supplierRepo: supplierRepo,
          workRepo: workRepo,
          rawList: rawList,
          list: list,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ItemRepo itemRepo,
    required OrderRepo orderRepo,
    required PurchaseOrderRepo purchaseRepo,
    required SupplierRepo supplierRepo,
    required WorkRepo workRepo,
    required List<Txn> rawList,
    required List<Txn> list,
  }) {
    if (rawList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSearchField(),
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
          _buildSearchField(),
          _buildTypeFilterBar(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const Center(child: Text('선택한 유형의 입출고 기록이 없습니다.')),
          ),
        ],
      );
    }

    return FutureBuilder<
        ({
          Map<String, String> itemNames,
          Map<String, String> partnerNames,
        })>(
      future: _loadSearchData(
        itemRepo: itemRepo,
        orderRepo: orderRepo,
        purchaseRepo: purchaseRepo,
        supplierRepo: supplierRepo,
        workRepo: workRepo,
        txns: list,
      ),
      builder: (context, searchSnap) {
        final itemNames =
            searchSnap.data?.itemNames ?? const <String, String>{};
        final partnerNames =
            searchSnap.data?.partnerNames ?? const <String, String>{};
        final filteredList = list
            .where((txn) => _matchesQuery(txn, itemNames, partnerNames))
            .toList();

        if (filteredList.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildSearchField(),
              _buildTypeFilterBar(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(child: Text('"$_query" 검색 결과 없음')),
              ),
            ],
          );
        }

        if (_isCalendarView) {
          return _buildCalendarBody(filteredList, itemNames);
        }

        return Column(
          children: [
            _buildSearchField(),
            _buildTypeFilterBar(),
            Expanded(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => TxnRow(t: filteredList[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarBody(List<Txn> list, Map<String, String> itemNames) {
    if (_isCalendarView) {
      final txnById = {for (final txn in list) txn.id: txn};
      final events = list
          .map((txn) => _calendarEventOf(txn, itemNames))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildSearchField(),
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
    }

    return const SizedBox.shrink();
  }
}
