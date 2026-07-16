// lib/src/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/main_tab_controller.dart';
import '../db/app_database.dart';
import '../db/quick_actions_order_dao.dart';
import '../models/app_schedule.dart';
import '../models/dashboard_purchase_stats.dart';
import '../models/item.dart';
import '../models/today_activity_summary.dart';
import '../repos/repo_interfaces.dart';
import '../services/dashboard_activity_service.dart';
import '../services/dashboard_purchase_stats_service.dart';
import '../ui/common/ui.dart';
import '../utils/reorder_schedule_utils.dart';
import 'dashboard/dashboard_quick_actions.dart';
import 'schedules/schedule_edit_screen.dart';
import 'stock/stock_browser_screen.dart';
import 'stock/stock_item_detail_screen.dart';

const _dashboardSectionOrderPrefsKey = 'dashboard.sectionOrder.v1';
const _dashboardHiddenSectionsPrefsKey = 'dashboard.hiddenSections.v1';
const _dashboardCollapsedSectionsPrefsKey = 'dashboard.collapsedSections.v1';
const _reorderAlertReadPrefsKey = 'dashboard.reorderAlertRead.v1';

enum _DashboardSectionType {
  summary('summary', '현재 요약', Icons.dashboard_customize_rounded),
  assistant('assistant', '오늘의 찰스톡', Icons.pets_rounded),
  tarot('tarot', '오늘의 타로', Icons.auto_awesome_rounded),
  schedules('schedules', '일정', Icons.event_note_rounded),
  purchaseStats('purchaseStats', '발주 통계', Icons.local_shipping_rounded),
  quickActions('quickActions', '빠른 실행', Icons.bolt_rounded);

  final String id;
  final String label;
  final IconData icon;

  const _DashboardSectionType(this.id, this.label, this.icon);
}

const _defaultDashboardSectionOrder = [
  _DashboardSectionType.summary,
  _DashboardSectionType.assistant,
  _DashboardSectionType.tarot,
  _DashboardSectionType.schedules,
  _DashboardSectionType.purchaseStats,
  _DashboardSectionType.quickActions,
];

List<_DashboardSectionType> _mergeDashboardSectionOrder(List<String>? ids) {
  final byId = {
    for (final section in _defaultDashboardSectionOrder) section.id: section,
  };
  final seen = <_DashboardSectionType>{};
  final merged = <_DashboardSectionType>[];

  for (final id in ids ?? const <String>[]) {
    final section = byId[id];
    if (section != null && seen.add(section)) merged.add(section);
  }
  for (final section in _defaultDashboardSectionOrder) {
    if (seen.add(section)) merged.add(section);
  }
  return merged;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late List<QuickActionType> _order;
  List<_DashboardSectionType> _sectionOrder = [
    ..._defaultDashboardSectionOrder,
  ];
  Set<_DashboardSectionType> _visibleSections = {
    ..._defaultDashboardSectionOrder,
  };
  Set<_DashboardSectionType> _collapsedSections = {};
  Set<String> _readReorderAlertKeys = {};
  bool _editingDashboard = false;

  @override
  void initState() {
    super.initState();
    _order = [...defaultQuickActionOrder];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderFromDb();
      _loadDashboardLayout();
      _loadReadReorderAlerts();
    });
  }

  Future<void> _loadReadReorderAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _readReorderAlertKeys =
            (prefs.getStringList(_reorderAlertReadPrefsKey) ?? const [])
                .toSet();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _readReorderAlertKeys = {});
    }
  }

  Future<void> _persistReadReorderAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _reorderAlertReadPrefsKey,
        _readReorderAlertKeys.toList()..sort(),
      );
    } catch (_) {
      // 읽음 상태 저장 실패는 알림 표시를 막지 않는다.
    }
  }

  Future<void> _loadDashboardLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_dashboardSectionOrderPrefsKey);
      final hiddenIds =
          prefs.getStringList(_dashboardHiddenSectionsPrefsKey) ?? const [];
      final collapsedIds =
          prefs.getStringList(_dashboardCollapsedSectionsPrefsKey) ?? const [];
      if (!mounted) return;

      setState(() {
        _sectionOrder = _mergeDashboardSectionOrder(ids);
        _visibleSections = _defaultDashboardSectionOrder
            .where((section) => !hiddenIds.contains(section.id))
            .toSet();
        _collapsedSections = _defaultDashboardSectionOrder
            .where((section) => collapsedIds.contains(section.id))
            .toSet();
      });
      await _persistDashboardLayout();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sectionOrder = [..._defaultDashboardSectionOrder];
        _visibleSections = {..._defaultDashboardSectionOrder};
        _collapsedSections = {};
      });
    }
  }

  Future<void> _persistDashboardLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _dashboardSectionOrderPrefsKey,
        _sectionOrder.map((section) => section.id).toList(),
      );
      await prefs.setStringList(
        _dashboardHiddenSectionsPrefsKey,
        _defaultDashboardSectionOrder
            .where((section) => !_visibleSections.contains(section))
            .map((section) => section.id)
            .toList(),
      );
      await prefs.setStringList(
        _dashboardCollapsedSectionsPrefsKey,
        _collapsedSections.map((section) => section.id).toList(),
      );
    } catch (_) {
      // 저장 실패는 대시보드 표시를 막지 않는다.
    }
  }

  Future<void> _hideDashboardSection(_DashboardSectionType section) async {
    setState(() => _visibleSections.remove(section));
    await _persistDashboardLayout();
  }

  Future<void> _restoreDashboardSection(_DashboardSectionType section) async {
    setState(() => _visibleSections.add(section));
    await _persistDashboardLayout();
  }

  Future<void> _toggleDashboardSectionCollapsed(
    _DashboardSectionType section,
  ) async {
    setState(() {
      if (!_collapsedSections.add(section)) {
        _collapsedSections.remove(section);
      }
    });
    await _persistDashboardLayout();
  }

  Future<void> _reorderDashboardSection(int oldIndex, int newIndex) async {
    final visibleSections =
        _sectionOrder.where(_visibleSections.contains).toList();
    if (oldIndex < 0 || oldIndex >= visibleSections.length) return;

    if (newIndex > oldIndex) newIndex -= 1;
    final moving = visibleSections.removeAt(oldIndex);
    visibleSections.insert(newIndex, moving);

    final hiddenSections =
        _sectionOrder.where((section) => !_visibleSections.contains(section));
    setState(() => _sectionOrder = [...visibleSections, ...hiddenSections]);
    await _persistDashboardLayout();
  }

  Future<void> _showAddSectionSheet() async {
    final hiddenSections = _defaultDashboardSectionOrder
        .where((section) => !_visibleSections.contains(section))
        .toList();
    if (hiddenSections.isEmpty) return;

    final selected = await showModalBottomSheet<_DashboardSectionType>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  '카드 추가',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              for (final section in hiddenSections)
                ListTile(
                  leading: Icon(section.icon),
                  title: Text(section.label),
                  onTap: () => Navigator.of(context).pop(section),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    await _restoreDashboardSection(selected);
  }

  Future<void> _loadOrderFromDb() async {
    try {
      final db = context.read<AppDatabase>();
      final dao = QuickActionsOrderDao(db);
      final ids = await dao.loadOrder();
      if (!mounted) return;

      setState(() {
        _order = mergeQuickActionOrder(ids);
      });
      await _persistOrderToDb();
    } catch (_) {
      if (!mounted) return;
      setState(() => _order = [...defaultQuickActionOrder]);
    }
  }

  Future<void> _persistOrderToDb() async {
    try {
      if (!mounted) return;
      final db = context.read<AppDatabase>();
      final dao = QuickActionsOrderDao(db);
      await dao.saveOrder(_order.map(quickActionIdOf).toList());
    } catch (_) {
      // 저장 실패는 대시보드 표시를 막지 않는다.
    }
  }

  Future<List<Item>> _loadReorderAlertItems(ItemRepo repo) async {
    final items = await repo.listItems();
    return _reorderAlertItems(items);
  }

  String _reorderAlertKey(Item item) {
    final nextDate = ReorderScheduleUtils.effectiveNextReorderDate(item);
    final dateKey = nextDate == null
        ? 'none'
        : ReorderScheduleUtils.dateOnly(nextDate).toIso8601String();
    return '${item.id}:$dateKey';
  }

  Future<void> _markReorderAlertsRead(Iterable<Item> items) async {
    final keys = items.map(_reorderAlertKey).toSet();
    if (keys.isEmpty || _readReorderAlertKeys.containsAll(keys)) return;

    setState(() {
      _readReorderAlertKeys = {..._readReorderAlertKeys, ...keys};
    });
    await _persistReadReorderAlerts();
  }

  List<Item> _reorderAlertItems(Iterable<Item> items) {
    final now = DateTime.now();
    final alerts = items.where((item) {
      if (!item.reorderReminderEnabled) return false;
      return ReorderScheduleUtils.statusFor(item, now: now).shouldShow;
    }).toList();

    alerts.sort((a, b) {
      final aStatus = ReorderScheduleUtils.statusFor(a, now: now);
      final bStatus = ReorderScheduleUtils.statusFor(b, now: now);
      if (aStatus.overdue != bStatus.overdue) {
        return aStatus.overdue ? -1 : 1;
      }
      final aDate = ReorderScheduleUtils.effectiveNextReorderDate(a, now: now);
      final bDate = ReorderScheduleUtils.effectiveNextReorderDate(b, now: now);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return alerts;
  }

  Future<void> _showReorderAlerts(ItemRepo repo) async {
    final items = await _loadReorderAlertItems(repo);
    if (!mounted) return;
    await _markReorderAlertsRead(items);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _ReorderAlertSheet(
        items: items,
        readKeys: _readReorderAlertKeys,
        alertKeyOf: _reorderAlertKey,
        onOpenItem: (item) {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StockItemDetailScreen(itemId: item.id),
            ),
          );
        },
        onMarkOrdered: (item) async {
          await repo.markItemOrderedNow(item.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.displayName ?? item.name} 발주 완료 처리됨'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemRepo = context.read<ItemRepo>();
    final scheduleRepo = context.read<ScheduleRepo>();
    final activityService = context.read<DashboardActivityService>();
    final purchaseStatsService = context.read<DashboardPurchaseStatsService>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFF),
      appBar: AppBar(
        title: Text(context.t.dashboard_title),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFAFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_editingDashboard)
            _DashboardNotificationButton(
              stream: itemRepo.watchItems().map(_reorderAlertItems),
              readKeys: _readReorderAlertKeys,
              alertKeyOf: _reorderAlertKey,
              onPressed: () => _showReorderAlerts(itemRepo),
            ),
          if (_editingDashboard)
            IconButton(
              tooltip: '카드 추가',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: _showAddSectionSheet,
            ),
          if (_editingDashboard)
            TextButton(
              onPressed: () {
                setState(() => _editingDashboard = false);
              },
              child: const Text('완료'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder(
        stream: itemRepo.watchItems(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = (snap.data ?? []) as List;
          final low =
              items.where((e) => e.minQty > 0 && e.qty <= e.minQty).toList();
          final totalQty =
              items.fold<int>(0, (sum, it) => sum + (it.qty as int));
          final actions = _order.map(
            (type) => buildDashboardQuickAction(
              context,
              type,
              onChanged: () {
                if (mounted) setState(() {});
              },
            ),
          );

          return StreamBuilder<DashboardPurchaseStats>(
            stream: purchaseStatsService.watchStats(),
            initialData: DashboardPurchaseStats.empty,
            builder: (context, purchaseStatsSnap) {
              return StreamBuilder<List<AppSchedule>>(
                stream: scheduleRepo.watchSchedules(date: DateTime.now()),
                initialData: const <AppSchedule>[],
                builder: (context, scheduleSnap) {
                  return StreamBuilder<TodayActivitySummary>(
                    stream: activityService.watchTodaySummary(),
                    initialData: TodayActivitySummary.empty,
                    builder: (context, activitySnap) {
                      return _DashboardContent(
                        itemCount: items.length,
                        totalQty: totalQty,
                        lowCount: low.length,
                        todaySchedules:
                            scheduleSnap.data ?? const <AppSchedule>[],
                        todaySummary:
                            activitySnap.data ?? TodayActivitySummary.empty,
                        purchaseStats: purchaseStatsSnap.data ??
                            DashboardPurchaseStats.empty,
                        actions: actions.toList(),
                        sectionOrder: _sectionOrder,
                        visibleSections: _visibleSections,
                        collapsedSections: _collapsedSections,
                        editing: _editingDashboard,
                        onStockTap: () =>
                            context.read<MainTabController>().setIndex(2),
                        onLowStockTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StockBrowserScreen(
                                showLowStockOnly: true,
                              ),
                            ),
                          );
                        },
                        onOpenSchedules: () => context
                            .read<MainTabController>()
                            .openShellRoute('/schedules'),
                        onReorder: (oldIndex, newIndex) async {
                          if (_editingDashboard) return;
                          setState(() {
                            final item = _order.removeAt(oldIndex);
                            _order.insert(newIndex, item);
                          });
                          await _persistOrderToDb();
                        },
                        onSectionReorder: _reorderDashboardSection,
                        onHideSection: _hideDashboardSection,
                        onToggleSectionCollapsed:
                            _toggleDashboardSectionCollapsed,
                        onEnterEditMode: () {
                          if (!_editingDashboard) {
                            setState(() => _editingDashboard = true);
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardNotificationButton extends StatelessWidget {
  final Stream<List<Item>> stream;
  final Set<String> readKeys;
  final String Function(Item item) alertKeyOf;
  final VoidCallback onPressed;

  const _DashboardNotificationButton({
    required this.stream,
    required this.readKeys,
    required this.alertKeyOf,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Item>>(
      stream: stream,
      initialData: const <Item>[],
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Item>[];
        final count =
            items.where((item) => !readKeys.contains(alertKeyOf(item))).length;
        return Semantics(
          label: count > 0 ? '미확인 발주 알림 $count개' : '알림',
          button: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: '알림',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: onPressed,
              ),
              if (count > 0)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B6BEF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReorderAlertSheet extends StatefulWidget {
  final List<Item> items;
  final Set<String> readKeys;
  final String Function(Item item) alertKeyOf;
  final ValueChanged<Item> onOpenItem;
  final Future<void> Function(Item item) onMarkOrdered;

  const _ReorderAlertSheet({
    required this.items,
    required this.readKeys,
    required this.alertKeyOf,
    required this.onOpenItem,
    required this.onMarkOrdered,
  });

  @override
  State<_ReorderAlertSheet> createState() => _ReorderAlertSheetState();
}

class _ReorderAlertSheetState extends State<_ReorderAlertSheet> {
  late List<Item> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.items];
  }

  String _dateText(DateTime? value) {
    if (value == null) return '예정일 없음';
    final d = ReorderScheduleUtils.dateOnly(value);
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _markOrdered(Item item) async {
    await widget.onMarkOrdered(item);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((candidate) => candidate.id == item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final height = math.min(MediaQuery.of(context).size.height * 0.72, 560.0);

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF7756E7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '발주 알림',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_items.length}개',
                    style: text.bodyMedium?.copyWith(
                      color: const Color(0xFF6F6878),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_items.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    '지금 확인할 발주 알림이 없습니다.',
                    style: TextStyle(
                      color: Color(0xFF6F6878),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final status = ReorderScheduleUtils.statusFor(item);
                    final nextDate =
                        ReorderScheduleUtils.effectiveNextReorderDate(item);
                    final read =
                        widget.readKeys.contains(widget.alertKeyOf(item));
                    final color = status.overdue
                        ? Colors.deepOrange.shade700
                        : const Color(0xFF7756E7);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        foregroundColor: color,
                        child: Icon(
                          status.overdue
                              ? Icons.priority_high_rounded
                              : Icons.event_repeat_rounded,
                        ),
                      ),
                      title: Text(
                        item.displayName ?? item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${status.label} · ${_dateText(nextDate)}${read ? ' · 읽음' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: '발주 완료',
                            onPressed: () => _markOrdered(item),
                            icon: const Icon(Icons.check_circle_outline),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () => widget.onOpenItem(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final int itemCount;
  final int totalQty;
  final int lowCount;
  final List<AppSchedule> todaySchedules;
  final TodayActivitySummary todaySummary;
  final DashboardPurchaseStats purchaseStats;
  final List<DashboardQuickAction> actions;
  final List<_DashboardSectionType> sectionOrder;
  final Set<_DashboardSectionType> visibleSections;
  final Set<_DashboardSectionType> collapsedSections;
  final bool editing;
  final VoidCallback onStockTap;
  final VoidCallback onLowStockTap;
  final VoidCallback onOpenSchedules;
  final ReorderCallback onReorder;
  final ReorderCallback onSectionReorder;
  final ValueChanged<_DashboardSectionType> onHideSection;
  final ValueChanged<_DashboardSectionType> onToggleSectionCollapsed;
  final VoidCallback onEnterEditMode;

  const _DashboardContent({
    required this.itemCount,
    required this.totalQty,
    required this.lowCount,
    required this.todaySchedules,
    required this.todaySummary,
    required this.purchaseStats,
    required this.actions,
    required this.sectionOrder,
    required this.visibleSections,
    required this.collapsedSections,
    required this.editing,
    required this.onStockTap,
    required this.onLowStockTap,
    required this.onOpenSchedules,
    required this.onReorder,
    required this.onSectionReorder,
    required this.onHideSection,
    required this.onToggleSectionCollapsed,
    required this.onEnterEditMode,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final horizontalPadding = wide ? 24.0 : 16.0;
        final contentWidth = constraints.maxWidth - horizontalPadding * 2;
        final gridHeight = _actionGridHeight(contentWidth, actions.length);
        final sections = sectionOrder
            .where((section) => visibleSections.contains(section))
            .toList();

        if (editing) {
          if (sections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '표시할 카드가 없습니다. 상단의 + 버튼으로 카드를 추가하세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF6F6878),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            );
          }

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 8, horizontalPadding, 24),
            itemCount: sections.length,
            onReorder: onSectionReorder,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Padding(
                key: ValueKey('dashboard-section-${section.id}'),
                padding: EdgeInsets.only(
                    bottom: index == sections.length - 1 ? 0 : 18),
                child: _EditableDashboardSection(
                  index: index,
                  section: section,
                  onHide: () => onHideSection(section),
                  child: _buildSection(context, section, gridHeight),
                ),
              );
            },
          );
        }

        return SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0)
                  SizedBox(
                    height: _sectionGapBefore(sections[i - 1], sections[i]),
                  ),
                _buildSection(context, sections[i], gridHeight),
              ],
            ],
          ),
        );
      },
    );
  }

  double _sectionGapBefore(
    _DashboardSectionType previous,
    _DashboardSectionType current,
  ) {
    final previousCollapsed = collapsedSections.contains(previous);
    final currentCollapsed = collapsedSections.contains(current);
    if (previousCollapsed && currentCollapsed) return 6;
    if (previousCollapsed || currentCollapsed) return 10;
    return 18;
  }

  Widget _buildSection(
    BuildContext context,
    _DashboardSectionType section,
    double gridHeight,
  ) {
    final child = _buildSectionBody(context, section, gridHeight);
    if (editing) return child;

    return _DashboardSectionShell(
      section: section,
      collapsed: collapsedSections.contains(section),
      onToggleCollapsed: () => onToggleSectionCollapsed(section),
      onLongPressHeader: onEnterEditMode,
      child: child,
    );
  }

  Widget _buildSectionBody(
    BuildContext context,
    _DashboardSectionType section,
    double gridHeight,
  ) {
    switch (section) {
      case _DashboardSectionType.summary:
        return _SummaryPanel(
          itemCount: itemCount,
          totalQty: totalQty,
          lowCount: lowCount,
          onStockTap: onStockTap,
          onLowStockTap: onLowStockTap,
        );
      case _DashboardSectionType.assistant:
        return _ChalstockAssistantCard(
          lowCount: lowCount,
          todaySummary: todaySummary,
          onOpenOrders: () => context.read<MainTabController>().setIndex(1),
          onOpenTxns: () => context.read<MainTabController>().setIndex(3),
          onOpenWorks: () => context.read<MainTabController>().setIndex(4),
          onOpenPurchases: () => context.read<MainTabController>().setIndex(5),
          onOpenSchedules: onOpenSchedules,
        );
      case _DashboardSectionType.tarot:
        return const _TodayTarotCard();
      case _DashboardSectionType.schedules:
        return _ScheduleDashboardCard(
          schedules: todaySchedules,
          onOpenSchedules: onOpenSchedules,
        );
      case _DashboardSectionType.purchaseStats:
        return _PurchaseStatsSection(stats: purchaseStats);
      case _DashboardSectionType.quickActions:
        return SizedBox(
          height: gridHeight,
          child: _DashboardActionGrid(
            actions: actions,
            onReorder: onReorder,
            enabled: !editing,
          ),
        );
    }
  }

  double _actionGridHeight(double contentWidth, int actionCount) {
    const crossAxisCount = 4;
    const crossSpacing = 12.0;
    const mainSpacing = 12.0;
    const maxPreferredGridWidth = 480.0;

    final rows = (actionCount / crossAxisCount).ceil().clamp(1, 8);
    final gridWidth = contentWidth < maxPreferredGridWidth
        ? contentWidth
        : maxPreferredGridWidth;
    final tileSize =
        (gridWidth - crossSpacing * (crossAxisCount - 1)) / crossAxisCount;

    return tileSize * rows + mainSpacing * (rows - 1);
  }
}

class _DashboardSectionShell extends StatelessWidget {
  final _DashboardSectionType section;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onLongPressHeader;
  final Widget child;

  const _DashboardSectionShell({
    required this.section,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onLongPressHeader,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPressHeader,
            child: Row(
              children: [
                Icon(section.icon, color: const Color(0xFF8B6BEF), size: 21),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF202027),
                        ),
                  ),
                ),
                IconButton(
                  tooltip: collapsed ? '펼치기' : '접기',
                  onPressed: onToggleCollapsed,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}

class _EditableDashboardSection extends StatelessWidget {
  final int index;
  final _DashboardSectionType section;
  final VoidCallback onHide;
  final Widget child;

  const _EditableDashboardSection({
    required this.index,
    required this.section,
    required this.onHide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBDA7F5), width: 1.5),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 44, 8, 8),
            child: child,
          ),
          Positioned(
            left: 56,
            right: 56,
            top: 14,
            child: Text(
              section.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF7756E7),
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          Positioned(
            left: 8,
            top: 6,
            child: IconButton.filledTonal(
              tooltip: '${section.label} 숨기기',
              icon: const Icon(Icons.visibility_off_rounded),
              onPressed: onHide,
            ),
          ),
          Positioned(
            right: 8,
            top: 6,
            child: ReorderableDragStartListener(
              index: index,
              child: IconButton.filledTonal(
                tooltip: '${section.label} 이동',
                icon: const Icon(Icons.drag_handle_rounded),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayTarotCard extends StatelessWidget {
  const _TodayTarotCard();

  @override
  Widget build(BuildContext context) {
    final reading = _TodayTarotReading.forDate(DateTime.now());
    final card = reading.card;
    final direction = reading.reversed ? '역방향' : '정방향';
    final keyword = reading.reversed ? card.reversedKeyword : card.keyword;
    final message = reading.reversed
        ? '오늘은 $keyword 기운이 비칩니다. 서두르기보다 마음의 균형을 먼저 살피면 흐름이 부드러워져요.'
        : '오늘은 $keyword 기운이 함께합니다. 자연스럽게 다가오는 감각을 믿고, 하루의 작은 신호를 놓치지 마세요.';

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _TarotHomeScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5D9F8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F7A6B99),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TarotMiniCard(reading: reading),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_formatTarotDate(reading.date)}의 카드',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF8A8297),
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E8FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            direction,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF7355D9),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.koreanName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF202027),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${card.name} · ${card.group}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A8297),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            color: const Color(0xFF3A3543),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarotHomeScreen extends StatelessWidget {
  const _TarotHomeScreen();

  @override
  Widget build(BuildContext context) {
    final reading = _TodayTarotReading.forDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 타로')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TarotReadingPanel(reading: reading),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.style_rounded),
                title: const Text('78장 카드보기'),
                subtitle: const Text('메이저와 마이너 아르카나의 정방향, 역방향 의미'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _TarotDeckScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarotReadingPanel extends StatelessWidget {
  final _TodayTarotReading reading;

  const _TarotReadingPanel({required this.reading});

  @override
  Widget build(BuildContext context) {
    final card = reading.card;
    final direction = reading.reversed ? '역방향' : '정방향';
    final keyword = reading.reversed ? card.reversedKeyword : card.keyword;
    final message = reading.reversed
        ? '오늘은 $keyword 기운이 비칩니다. 서두르기보다 마음의 균형을 먼저 살피면 흐름이 부드러워져요.'
        : '오늘은 $keyword 기운이 함께합니다. 자연스럽게 다가오는 감각을 믿고, 하루의 작은 신호를 놓치지 마세요.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5D9F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TarotMiniCard(reading: reading),
            const SizedBox(height: 14),
            Text(
              '${_formatTarotDate(reading.date)}의 카드',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8A8297),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              card.koreanName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF202027),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              '${card.name} · ${card.group} · $direction',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8A8297),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.42,
                    color: const Color(0xFF3A3543),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarotDeckScreen extends StatefulWidget {
  const _TarotDeckScreen();

  @override
  State<_TarotDeckScreen> createState() => _TarotDeckScreenState();
}

class _TarotDeckScreenState extends State<_TarotDeckScreen> {
  String _filter = '전체';

  List<String> get _filters => const [
        '전체',
        '메이저',
        '완드',
        '컵',
        '소드',
        '펜타클',
      ];

  List<_TarotCardData> get _cards {
    final all = _TarotCardData.deck;
    if (_filter == '전체') return all;
    if (_filter == '메이저') {
      return all.where((card) => card.group == '메이저').toList();
    }
    return all.where((card) => card.group.contains(_filter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;

    return Scaffold(
      appBar: AppBar(title: const Text('78장 카드보기')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  return ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _filters.length,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemBuilder: (context, index) {
                  return _TarotDeckCardTile(card: cards[index]);
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: cards.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarotDeckCardTile extends StatelessWidget {
  final _TarotCardData card;

  const _TarotDeckCardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _TarotCardDetailScreen(card: card),
            ),
          );
        },
        leading: Container(
          width: 42,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2D2547),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: Color(0xFFFFD66B),
          ),
        ),
        title: Text(
          card.koreanName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${card.name} · ${card.group}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _TarotCardDetailScreen extends StatelessWidget {
  final _TarotCardData card;

  const _TarotCardDetailScreen({required this.card});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(card.koreanName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TarotCardHero(card: card),
            const SizedBox(height: 16),
            _TarotDetailSection(
              title: '카드의 핵심',
              icon: Icons.auto_awesome_rounded,
              text: _tarotCoreMessage(card),
            ),
            const SizedBox(height: 12),
            _TarotDetailSection(
              title: '정방향 의미',
              icon: Icons.north_rounded,
              text: _tarotUprightMessage(card),
            ),
            const SizedBox(height: 12),
            _TarotDetailSection(
              title: '역방향 의미',
              icon: Icons.south_rounded,
              text: _tarotReversedMessage(card),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarotCardHero extends StatelessWidget {
  final _TarotCardData card;

  const _TarotCardHero({required this.card});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5D9F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: 116,
              height: 172,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2547),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFBBA7F3), width: 1.2),
              ),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Color(0xFFFFD66B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    card.shortLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFD8CDF8),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              card.koreanName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF202027),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${card.name} · ${card.group}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF8A8297),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarotDetailSection extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _TarotDetailSection({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE5F4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF7355D9)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF202027),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: const Color(0xFF3A3543),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _tarotCoreMessage(_TarotCardData card) {
  return '${card.koreanName} 카드는 ${card.keyword}을 중심으로 삶의 흐름을 바라보게 합니다. '
      '지금 눈앞에 드러난 사건보다 그 안에서 반복되는 마음의 패턴과 선택의 방향을 살펴보라는 카드입니다.';
}

String _tarotUprightMessage(_TarotCardData card) {
  return '정방향의 ${card.koreanName}은 ${card.keyword}을 긍정적으로 받아들이라는 메시지를 전합니다. '
      '상황을 억지로 밀어붙이기보다, 카드가 가리키는 흐름을 의식하면서 한 걸음씩 움직이면 좋습니다.';
}

String _tarotReversedMessage(_TarotCardData card) {
  return '역방향의 ${card.koreanName}은 ${card.reversedKeyword}을 돌아보라는 신호입니다. '
      '겉으로 드러난 결과보다 마음속 저항, 불균형, 미뤄둔 감정이 어디에서 시작됐는지 조용히 살펴보세요.';
}

class _TarotMiniCard extends StatelessWidget {
  final _TodayTarotReading reading;

  const _TarotMiniCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final card = reading.card;
    return Container(
      width: 88,
      height: 132,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2547),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBA7F3), width: 1.2),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Transform.rotate(
              angle: reading.reversed ? math.pi : 0,
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFFFFD66B),
              ),
            ),
          ),
          const Spacer(),
          Text(
            card.shortLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            card.group,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFD8CDF8),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _TodayTarotReading {
  final _TarotCardData card;
  final bool reversed;
  final DateTime date;

  const _TodayTarotReading({
    required this.card,
    required this.reversed,
    required this.date,
  });

  factory _TodayTarotReading.forDate(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final random = math.Random(seed);
    final deck = _TarotCardData.deck;
    return _TodayTarotReading(
      card: deck[random.nextInt(deck.length)],
      reversed: random.nextBool(),
      date: date,
    );
  }
}

class _TarotCardData {
  final String name;
  final String koreanName;
  final String group;
  final String keyword;
  final String reversedKeyword;

  const _TarotCardData({
    required this.name,
    required this.koreanName,
    required this.group,
    required this.keyword,
    required this.reversedKeyword,
  });

  String get shortLabel {
    final parts = koreanName.split(' ');
    if (parts.length <= 1) return koreanName;
    return parts.last;
  }

  static final List<_TarotCardData> deck = [
    ..._majorArcana,
    ..._minorArcana,
  ];

  static const List<_TarotCardData> _majorArcana = [
    _TarotCardData(
      name: 'The Fool',
      koreanName: '광대',
      group: '메이저',
      keyword: '새 출발과 가벼운 시도',
      reversedKeyword: '성급한 시작과 준비 부족',
    ),
    _TarotCardData(
      name: 'The Magician',
      koreanName: '마법사',
      group: '메이저',
      keyword: '도구 활용과 실행력',
      reversedKeyword: '산만함과 과장된 판단',
    ),
    _TarotCardData(
      name: 'The High Priestess',
      koreanName: '여사제',
      group: '메이저',
      keyword: '직감과 숨은 정보',
      reversedKeyword: '확인되지 않은 추측',
    ),
    _TarotCardData(
      name: 'The Empress',
      koreanName: '여황제',
      group: '메이저',
      keyword: '풍요와 생산성',
      reversedKeyword: '과잉과 관리 누락',
    ),
    _TarotCardData(
      name: 'The Emperor',
      koreanName: '황제',
      group: '메이저',
      keyword: '질서와 기준 세우기',
      reversedKeyword: '고집과 경직된 운영',
    ),
    _TarotCardData(
      name: 'The Hierophant',
      koreanName: '교황',
      group: '메이저',
      keyword: '규칙과 검증된 방식',
      reversedKeyword: '낡은 방식에 대한 집착',
    ),
    _TarotCardData(
      name: 'The Lovers',
      koreanName: '연인',
      group: '메이저',
      keyword: '선택과 협력',
      reversedKeyword: '흔들리는 우선순위',
    ),
    _TarotCardData(
      name: 'The Chariot',
      koreanName: '전차',
      group: '메이저',
      keyword: '추진과 집중',
      reversedKeyword: '방향 상실과 무리한 속도',
    ),
    _TarotCardData(
      name: 'Strength',
      koreanName: '힘',
      group: '메이저',
      keyword: '인내와 부드러운 통제',
      reversedKeyword: '조급함과 소진',
    ),
    _TarotCardData(
      name: 'The Hermit',
      koreanName: '은둔자',
      group: '메이저',
      keyword: '점검과 깊은 집중',
      reversedKeyword: '고립과 지연',
    ),
    _TarotCardData(
      name: 'Wheel of Fortune',
      koreanName: '운명의 수레바퀴',
      group: '메이저',
      keyword: '흐름 변화와 기회',
      reversedKeyword: '반복되는 변수',
    ),
    _TarotCardData(
      name: 'Justice',
      koreanName: '정의',
      group: '메이저',
      keyword: '균형과 정확한 기록',
      reversedKeyword: '불균형과 누락된 근거',
    ),
    _TarotCardData(
      name: 'The Hanged Man',
      koreanName: '매달린 사람',
      group: '메이저',
      keyword: '관점 전환과 기다림',
      reversedKeyword: '불필요한 정체',
    ),
    _TarotCardData(
      name: 'Death',
      koreanName: '죽음',
      group: '메이저',
      keyword: '정리와 새 단계',
      reversedKeyword: '끝내야 할 것의 지연',
    ),
    _TarotCardData(
      name: 'Temperance',
      koreanName: '절제',
      group: '메이저',
      keyword: '조율과 적정선',
      reversedKeyword: '과부하와 섞이지 않는 계획',
    ),
    _TarotCardData(
      name: 'The Devil',
      koreanName: '악마',
      group: '메이저',
      keyword: '집착을 알아차리는 힘',
      reversedKeyword: '습관적 반복과 유혹',
    ),
    _TarotCardData(
      name: 'The Tower',
      koreanName: '탑',
      group: '메이저',
      keyword: '갑작스러운 재정비',
      reversedKeyword: '미뤄둔 문제의 확대',
    ),
    _TarotCardData(
      name: 'The Star',
      koreanName: '별',
      group: '메이저',
      keyword: '회복과 희망적인 계획',
      reversedKeyword: '기대치 조정 필요',
    ),
    _TarotCardData(
      name: 'The Moon',
      koreanName: '달',
      group: '메이저',
      keyword: '불확실성 속 관찰',
      reversedKeyword: '오해와 흐릿한 정보',
    ),
    _TarotCardData(
      name: 'The Sun',
      koreanName: '태양',
      group: '메이저',
      keyword: '명확함과 좋은 성과',
      reversedKeyword: '과신과 세부 확인 부족',
    ),
    _TarotCardData(
      name: 'Judgement',
      koreanName: '심판',
      group: '메이저',
      keyword: '결산과 재평가',
      reversedKeyword: '판단 보류와 미해결',
    ),
    _TarotCardData(
      name: 'The World',
      koreanName: '세계',
      group: '메이저',
      keyword: '완성과 다음 단계',
      reversedKeyword: '마무리 직전의 누락',
    ),
  ];

  static final List<_TarotCardData> _minorArcana = [
    for (final suit in _TarotSuitData.values)
      for (final rank in _TarotRankData.values)
        _TarotCardData(
          name: '${rank.name} of ${suit.name}',
          koreanName: '${suit.koreanName} ${rank.koreanName}',
          group: suit.group,
          keyword: '${suit.keyword} 속 ${rank.keyword}',
          reversedKeyword: '${suit.keyword}에서 ${rank.reversedKeyword}',
        ),
  ];
}

class _TarotSuitData {
  final String name;
  final String koreanName;
  final String group;
  final String keyword;

  const _TarotSuitData({
    required this.name,
    required this.koreanName,
    required this.group,
    required this.keyword,
  });

  static const values = [
    _TarotSuitData(
      name: 'Wands',
      koreanName: '완드',
      group: '마이너 · 완드',
      keyword: '추진력',
    ),
    _TarotSuitData(
      name: 'Cups',
      koreanName: '컵',
      group: '마이너 · 컵',
      keyword: '감정과 관계',
    ),
    _TarotSuitData(
      name: 'Swords',
      koreanName: '소드',
      group: '마이너 · 소드',
      keyword: '판단과 소통',
    ),
    _TarotSuitData(
      name: 'Pentacles',
      koreanName: '펜타클',
      group: '마이너 · 펜타클',
      keyword: '현실과 자원',
    ),
  ];
}

class _TarotRankData {
  final String name;
  final String koreanName;
  final String keyword;
  final String reversedKeyword;

  const _TarotRankData({
    required this.name,
    required this.koreanName,
    required this.keyword,
    required this.reversedKeyword,
  });

  static const values = [
    _TarotRankData(
      name: 'Ace',
      koreanName: '에이스',
      keyword: '새로운 씨앗',
      reversedKeyword: '시작 전 망설임',
    ),
    _TarotRankData(
      name: 'Two',
      koreanName: '2',
      keyword: '선택과 균형',
      reversedKeyword: '우선순위 혼선',
    ),
    _TarotRankData(
      name: 'Three',
      koreanName: '3',
      keyword: '확장과 협업',
      reversedKeyword: '손발이 맞지 않음',
    ),
    _TarotRankData(
      name: 'Four',
      koreanName: '4',
      keyword: '안정과 기반',
      reversedKeyword: '닫힌 태도',
    ),
    _TarotRankData(
      name: 'Five',
      koreanName: '5',
      keyword: '변화와 마찰',
      reversedKeyword: '불필요한 충돌',
    ),
    _TarotRankData(
      name: 'Six',
      koreanName: '6',
      keyword: '회복과 나눔',
      reversedKeyword: '과거 방식의 반복',
    ),
    _TarotRankData(
      name: 'Seven',
      koreanName: '7',
      keyword: '점검과 전략',
      reversedKeyword: '집중력 분산',
    ),
    _TarotRankData(
      name: 'Eight',
      koreanName: '8',
      keyword: '숙련과 빠른 진행',
      reversedKeyword: '무리한 속도',
    ),
    _TarotRankData(
      name: 'Nine',
      koreanName: '9',
      keyword: '성과와 인내',
      reversedKeyword: '피로 누적',
    ),
    _TarotRankData(
      name: 'Ten',
      koreanName: '10',
      keyword: '완성과 부담',
      reversedKeyword: '과부하',
    ),
    _TarotRankData(
      name: 'Page',
      koreanName: '페이지',
      keyword: '학습과 작은 소식',
      reversedKeyword: '서툰 전달',
    ),
    _TarotRankData(
      name: 'Knight',
      koreanName: '기사',
      keyword: '움직임과 실행',
      reversedKeyword: '성급한 움직임',
    ),
    _TarotRankData(
      name: 'Queen',
      koreanName: '여왕',
      keyword: '관리와 돌봄',
      reversedKeyword: '감정적 과잉',
    ),
    _TarotRankData(
      name: 'King',
      koreanName: '왕',
      keyword: '책임과 통솔',
      reversedKeyword: '통제 과잉',
    ),
  ];
}

String _formatTarotDate(DateTime date) {
  return '${date.month}월 ${date.day}일';
}

String _formatWon(double value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final remaining = rounded.length - i;
    buffer.write(rounded[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  final sign = value < 0 ? '-' : '';
  return '$sign$buffer원';
}

class _SummaryPanel extends StatelessWidget {
  final int itemCount;
  final int totalQty;
  final int lowCount;
  final VoidCallback onStockTap;
  final VoidCallback onLowStockTap;

  const _SummaryPanel({
    required this.itemCount,
    required this.totalQty,
    required this.lowCount,
    required this.onStockTap,
    required this.onLowStockTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE5F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F7A6B99),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: context.t.dashboard_total_items,
              value: itemCount.toString(),
              icon: Icons.inventory_2_rounded,
              onTap: onStockTap,
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _StatCard(
              title: '전체 수량',
              value: totalQty.toString(),
              icon: Icons.view_in_ar_rounded,
              onTap: onStockTap,
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _StatCard(
              title: context.t.dashboard_below_threshold,
              value: lowCount.toString(),
              icon: Icons.warning_rounded,
              danger: true,
              onTap: onLowStockTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 112,
      color: const Color(0xFFECE5F4),
    );
  }
}

class _ChalstockAssistantCard extends StatefulWidget {
  final int lowCount;
  final TodayActivitySummary todaySummary;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenTxns;
  final VoidCallback onOpenWorks;
  final VoidCallback onOpenPurchases;
  final VoidCallback onOpenSchedules;

  const _ChalstockAssistantCard({
    required this.lowCount,
    required this.todaySummary,
    required this.onOpenOrders,
    required this.onOpenTxns,
    required this.onOpenWorks,
    required this.onOpenPurchases,
    required this.onOpenSchedules,
  });

  @override
  State<_ChalstockAssistantCard> createState() =>
      _ChalstockAssistantCardState();
}

class _ChalstockAssistantCardState extends State<_ChalstockAssistantCard> {
  static const _happyPuppyAsset = 'assets/images/chal_happy.png';
  static const _discPuppyAsset = 'assets/images/chal_pup2.png';
  static const _compactMessages = [
    '사장님… 저 간식비는 재고로 안 잡히나요?',
    '오늘도 뭔가 많이 열려 있네요. 아주 좋아요.',
    '발주서는 늘 왜 급할 때만 생각날까요?',
    '방금 뭔가 정리한 척했죠? 제가 봤어요.',
    '오늘도 찰스톡에 출근 완료입니다 🐶',
    '커피 마시고 오면 일이 줄어들 수도 있어요. 아마도.',
    '체크 하나 하면 왠지 똑똑해진 기분이에요.',
    '저는 누워있었는데 사장님은 계속 일하네요.',
    '재고는 조용히 줄어드는데 저는 조용히 배고파져요.',
    '오늘 창고 공기… 약간 프로의 냄새예요.',
    '급하게 뛰면 저도 같이 미끄러져요.',
    '오늘은 뭘 먼저 잊어버릴 예정인가요?',
    '이상하게 바쁜 날은 탭도 많아져요.',
    '이 정도면 거의 작업실 레이드 아닌가요?',
    '장부는 차가운데 손은 뜨겁네요.',
    '사장님 손이 바쁜 걸 보니 오늘도 살아있네요.',
    '가끔은 정리보다 앉아있는 것도 중요해요.',
    '제가 보기엔 지금 꽤 잘 굴러가고 있어요.',
    '일단 하나만 끝내도 분위기가 달라져요.',
    '너무 완벽하게 하려다 배고파지지 말기!',
    '오늘도 작은 완료 하나 응원할게요.',
    '천천히 해도 괜찮아요. 저는 원래 느려요.',
    '바쁜 와중에 여기 들어온 건 잘한 거예요.',
    '오늘 할 일들이 줄 서 있는 중이에요.',
    '방금 저장 버튼 누른 거 아주 훌륭했어요.',
    '어질러져도 기록하면 뭔가 있어 보여요.',
    '저는 전문가가 아니고 그냥 강아지입니다.',
    '근데 사장님은 약간 전문가 같아요.',
    '오늘도 작업실이 살아 움직이고 있어요.',
    '메모는 미래의 사장님에게 보내는 편지래요.',
    '저는 돕고 싶지만 발이 짧아요.',
    '지금 시작한 것만으로도 꽤 괜찮아요.',
    '사장님, 물 한 잔 마셨어요?',
    '일이 많아 보일 땐 확대하지 말고 축소해서 보기!',
    '가끔은 모르는 척 지나가는 것도 기술이에요.',
    '오늘 재고들도 열심히 살아가고 있어요.',
    '사장님 오늘 표정이 약간 장인 같아요.',
    '저는 오늘도 귀엽고 사장님은 오늘도 바빠요.',
    '체크박스는 왠지 누르면 기분이 좋아요.',
    '오늘도 한 칸씩 정리해봐요.',
    '뭔가 복잡할 땐 일단 앉는 게 중요해요.',
    '저는 누워있지만 마음만은 근무중입니다.',
    '오늘은 덜 피곤한 하루였으면 좋겠어요.',
    '할 일이 많다는 건 살아있다는 뜻이래요.',
    '이 앱도 사장님처럼 열심히 돌아가는 중이에요.',
    '지금 정도면 꽤 잘하고 있는 흐름이에요.',
    '저는 강아지고 사장님은 사장님이에요. 둘 다 힘내요.',
    '멍!',
    '꼬리 흔드는 중…',
    '오늘도 무사히 지나가보자구요 🐶',
  ];

  final _random = math.Random();
  Timer? _messageTimer;
  int _compactMessageIndex = 0;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _compactMessageIndex = _random.nextInt(_compactMessages.length);
    _messageTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(_selectNextCompactMessage);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _selectNextCompactMessage() {
    if (_compactMessages.length < 2) return;

    var next = _random.nextInt(_compactMessages.length);
    while (next == _compactMessageIndex) {
      next = _random.nextInt(_compactMessages.length);
    }
    _compactMessageIndex = next;
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFCDBAF7), width: 1.4),
    );

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _expanded ? _buildExpanded(context) : _buildCompact(context),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Icon(
        _expanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.chevron_right_rounded,
        color: const Color(0xFF8B6BEF),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return SizedBox(
      height: 152,
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _TodayBusinessMetrics(
                        summary: widget.todaySummary,
                        compact: true,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _SpeechBubble(
                          text: _compactMessages[_compactMessageIndex],
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: Image.asset(
                    _discPuppyAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: _SpeechBubble(text: '작업을 더 스마트하게\n도와드릴게요!'),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 150,
              child: Image.asset(
                _happyPuppyAsset,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TodayActivityPanel(
          summary: widget.todaySummary,
          onOpenOrders: widget.onOpenOrders,
          onOpenTxns: widget.onOpenTxns,
          onOpenWorks: widget.onOpenWorks,
          onOpenPurchases: widget.onOpenPurchases,
          onOpenSchedules: widget.onOpenSchedules,
        ),
        const SizedBox(height: 12),
        const _TipPanel(),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  final bool compact;

  const _SpeechBubble({
    required this.text,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D7A6B99),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 14 : 14,
        ),
        child: Text(
          text,
          maxLines: compact ? 4 : null,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(
            fontSize: compact ? 14.5 : 14,
            height: compact ? 1.3 : 1.35,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2B2930),
          ),
        ),
      ),
    );
  }
}

class _TodayBusinessMetrics extends StatelessWidget {
  final TodayActivitySummary summary;
  final bool compact;

  const _TodayBusinessMetrics({
    required this.summary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _TodayBusinessMetricData(
        label: '신규주문',
        value: '${summary.newOrders}개',
        color: const Color(0xFF6A7AF5),
      ),
      _TodayBusinessMetricData(
        label: '오늘 매출',
        value: _formatWon(summary.todaySales),
        color: const Color(0xFF2F9F70),
      ),
      _TodayBusinessMetricData(
        label: '이달 매출',
        value: _formatWon(summary.monthSales),
        color: const Color(0xFF7756E7),
      ),
      _TodayBusinessMetricData(
        label: '오늘 발주',
        value: '${summary.purchases}개',
        color: const Color(0xFFED8A3D),
      ),
      _TodayBusinessMetricData(
        label: '오늘 지출',
        value: _formatWon(summary.todayExpenses),
        color: const Color(0xFFD95858),
      ),
    ];

    if (compact) {
      return SizedBox(
        height: 54,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: metrics.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return SizedBox(
              width: 104,
              child: _TodayBusinessMetric(
                label: metric.label,
                value: metric.value,
                color: metric.color,
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 520
            ? (constraints.maxWidth - 16) / 3
            : (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: _TodayBusinessMetric(
                  label: metric.label,
                  value: metric.value,
                  color: metric.color,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TodayBusinessMetricData {
  final String label;
  final String value;
  final Color color;

  const _TodayBusinessMetricData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _TodayBusinessMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TodayBusinessMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF17151C),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayActivityPanel extends StatelessWidget {
  final TodayActivitySummary summary;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenTxns;
  final VoidCallback onOpenWorks;
  final VoidCallback onOpenPurchases;
  final VoidCallback onOpenSchedules;

  const _TodayActivityPanel({
    required this.summary,
    required this.onOpenOrders,
    required this.onOpenTxns,
    required this.onOpenWorks,
    required this.onOpenPurchases,
    required this.onOpenSchedules,
  });

  List<_TodayActivityLine> _lines() {
    final lines = <_TodayActivityLine>[];
    if (summary.newOrders > 0) {
      lines.add(_TodayActivityLine(
        icon: Icons.assignment_rounded,
        color: const Color(0xFF6A7AF5),
        text: '오늘 새 주문이 ${summary.newOrders}개 들어왔어요 🐶',
        onTap: onOpenOrders,
      ));
    }
    if (summary.purchases > 0) {
      lines.add(_TodayActivityLine(
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF4E9F7B),
        text: '발주 ${summary.purchases}건을 챙겼어요',
        onTap: onOpenPurchases,
      ));
    }
    if (summary.inbound > 0 || summary.outbound > 0) {
      lines.add(_TodayActivityLine(
        icon: Icons.swap_vert_rounded,
        color: const Color(0xFF5C8DF6),
        text: '입고 ${summary.inbound}건, 출고 ${summary.outbound}건이 움직였어요',
        onTap: onOpenTxns,
      ));
    }
    if (summary.pendingTodos > 0) {
      lines.add(_TodayActivityLine(
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFF8B6BEF),
        text: '오늘 할일 ${summary.pendingTodos}개가 기다리고 있어요',
        onTap: onOpenSchedules,
      ));
    }
    if (summary.doneTodos > 0) {
      lines.add(_TodayActivityLine(
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF37A66B),
        text: '한일 ${summary.doneTodos}개 완료! 잘했어요',
        onTap: onOpenSchedules,
      ));
    }
    if (summary.inProgressWorks > 0) {
      lines.add(_TodayActivityLine(
        icon: Icons.precision_manufacturing_rounded,
        color: const Color(0xFFED8A3D),
        text: '진행중 작업 ${summary.inProgressWorks}개가 있어요',
        onTap: onOpenWorks,
      ));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E2F5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _TodayBusinessMetrics(summary: summary),
          ),
          const Divider(height: 1),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Text(
                '오늘은 아직 기록된 활동이 없어요. 첫 기록을 남겨볼까요?',
                style: TextStyle(
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B2930),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < lines.length; i++)
                  _TodayActivityRow(
                    line: lines[i],
                    showDivider: i != lines.length - 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TodayActivityLine {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  const _TodayActivityLine({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });
}

class _TodayActivityRow extends StatelessWidget {
  final _TodayActivityLine line;
  final bool showDivider;

  const _TodayActivityRow({
    required this.line,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: line.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(line.icon, color: line.color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    line.text,
                    style: const TextStyle(
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: line.color.withValues(alpha: 0.72),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 52, endIndent: 16),
      ],
    );
  }
}

class _TipPanel extends StatelessWidget {
  const _TipPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E2F5)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.tips_and_updates_rounded, color: Color(0xFF8B6BEF)),
            SizedBox(width: 10),
            Text(
              'TIP',
              style: TextStyle(
                color: Color(0xFF7756E7),
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '기록을 남길수록 찰스톡이 오늘 흐름을 더 똑똑하게 모아드려요!',
                style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleDashboardCard extends StatelessWidget {
  final List<AppSchedule> schedules;
  final VoidCallback onOpenSchedules;

  const _ScheduleDashboardCard({
    required this.schedules,
    required this.onOpenSchedules,
  });

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}';
  }

  String _updateLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '업데이트 $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        schedules.where((s) => s.status == AppScheduleStatus.pending).toList();
    final done =
        schedules.where((s) => s.status == AppScheduleStatus.done).toList();
    final visibleSchedules = [
      ...pending,
      ...done,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F7A6B99),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _todayLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF050507),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _updateLabel(),
                  style: const TextStyle(
                    color: Color(0xFF8E8A94),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ScheduleWidgetAction(
                    icon: Icons.checklist_rtl_rounded,
                    label: '일정 추가',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduleEditScreen(
                            draft: ScheduleDraft(
                              title: '',
                              body: '',
                              date: DateTime.now(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _ScheduleWidgetAction(
                    icon: Icons.notes_rounded,
                    label: '메모',
                    onTap: () => context
                        .read<MainTabController>()
                        .openShellRoute('/memo'),
                  ),
                  const SizedBox(width: 10),
                  _ScheduleWidgetAction(
                    icon: Icons.inventory_2_outlined,
                    label: '재고',
                    onTap: () => context.read<MainTabController>().setIndex(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _ScheduleStatusBadge(
                  label: '할일',
                  value: pending.length,
                  color: const Color(0xFFC04FDD),
                  background: const Color(0xFFF6E6FB),
                ),
                _ScheduleStatusBadge(
                  label: '완료',
                  value: done.length,
                  color: const Color(0xFF31B765),
                  background: const Color(0xFFE7F9ED),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (visibleSchedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '오늘 등록된 일정이 없습니다.',
                  style: TextStyle(
                    color: Color(0xFF7A7480),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < visibleSchedules.length; i++)
                    _ScheduleWidgetRow(schedule: visibleSchedules[i]),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenSchedules,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('전체 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleWidgetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ScheduleWidgetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0EFF2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: const Color(0xFF101013)),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF101013),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleStatusBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color background;

  const _ScheduleStatusBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          '$label $value',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ScheduleWidgetRow extends StatelessWidget {
  final AppSchedule schedule;

  const _ScheduleWidgetRow({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final done = schedule.status == AppScheduleStatus.done;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.read<MainTabController>().openShellRoute(
              '/schedules',
            ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: done ? const Color(0xFF35C56F) : const Color(0xFFC04FDD),
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  schedule.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF08080A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseStatsSection extends StatelessWidget {
  final DashboardPurchaseStats stats;

  const _PurchaseStatsSection({required this.stats});

  String _money(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final remaining = rounded.length - i;
      buffer.write(rounded[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '₩$buffer';
  }

  String _date(DateTime? value) {
    if (value == null) return '-';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9E2F5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.read<MainTabController>().setIndex(5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 520;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: twoColumns
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth,
                        child: _PurchaseMetricBlock(
                          title: '이번 달 발주',
                          count: '${stats.monthlyCount}건',
                          amount: _money(stats.monthlyAmount),
                          color: const Color(0xFF7756E7),
                        ),
                      ),
                      SizedBox(
                        width: twoColumns
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth,
                        child: _PurchaseMetricBlock(
                          title: '미완료 발주',
                          count: '${stats.incompleteCount}건',
                          amount: _money(stats.incompleteAmount),
                          color: const Color(0xFFED8A3D),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _RecentPurchaseLine(
                date: _date(stats.recentCreatedAt),
                supplierName: stats.recentSupplierName ?? '-',
              ),
              const SizedBox(height: 14),
              _PurchaseTopList(
                title: '자주 발주한 거래처',
                emptyText: '아직 발주 거래처가 없어요',
                children: [
                  for (final supplier in stats.topSuppliers)
                    _PurchaseTopRow(
                      title: supplier.name,
                      meta: '${supplier.count}건 · ${_money(supplier.amount)}',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _PurchaseTopList(
                title: '자주 발주한 아이템',
                emptyText: '아직 발주 아이템이 없어요',
                children: [
                  for (final item in stats.topItems)
                    _PurchaseTopRow(
                      title: item.name,
                      meta: '${item.count}건',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseMetricBlock extends StatelessWidget {
  final String title;
  final String count;
  final String amount;
  final Color color;

  const _PurchaseMetricBlock({
    required this.title,
    required this.count,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  count,
                  style: const TextStyle(
                    color: Color(0xFF202027),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF5F5A68),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPurchaseLine extends StatelessWidget {
  final String date;
  final String supplierName;

  const _RecentPurchaseLine({
    required this.date,
    required this.supplierName,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Text(
              '최근 발주',
              style: TextStyle(
                color: Color(0xFF7756E7),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              date,
              style: const TextStyle(
                color: Color(0xFF202027),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                supplierName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5F5A68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseTopList extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Widget> children;

  const _PurchaseTopList({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2B2930),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(
            emptyText,
            style: const TextStyle(
              color: Color(0xFF8A8491),
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Column(children: children),
      ],
    );
  }
}

class _PurchaseTopRow extends StatelessWidget {
  final String title;
  final String meta;

  const _PurchaseTopRow({
    required this.title,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF202027),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            meta,
            style: const TextStyle(
              color: Color(0xFF7A7480),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardActionGrid extends StatelessWidget {
  final List<DashboardQuickAction> actions;
  final ReorderCallback onReorder;
  final bool enabled;

  const _DashboardActionGrid({
    required this.actions,
    required this.onReorder,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 4;
        const crossSpacing = 12.0;
        const mainSpacing = 12.0;
        const horizontalPagePadding = 16.0;

        final rowsForLayout =
            (actions.length / crossAxisCount).ceil().clamp(1, 4);
        final screenWidth = MediaQuery.of(context).size.width;
        final availableHeight = constraints.maxHeight;
        final maxRowHeight =
            (availableHeight - mainSpacing * (rowsForLayout - 1)) /
                rowsForLayout;

        final maxGridWidthByScreen = screenWidth - horizontalPagePadding * 2;
        const maxPreferredGridWidth = 480.0;
        final tentativeGridWidth = maxGridWidthByScreen < maxPreferredGridWidth
            ? maxGridWidthByScreen
            : maxPreferredGridWidth;

        final maxColWidth =
            (tentativeGridWidth - crossSpacing * (crossAxisCount - 1)) /
                crossAxisCount;
        final tileSize =
            maxRowHeight < maxColWidth ? maxRowHeight : maxColWidth;
        final gridContentWidth =
            tileSize * crossAxisCount + crossSpacing * (crossAxisCount - 1);

        final children = [
          for (final action in actions)
            DashboardQuickActionGridTile(
              key: action.key,
              action: action,
            ),
        ];

        return Center(
          child: SizedBox(
            width: gridContentWidth,
            height: availableHeight,
            child: enabled
                ? ReorderableGridView.count(
                    physics: actions.length > (crossAxisCount * rowsForLayout)
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: mainSpacing,
                    crossAxisSpacing: crossSpacing,
                    childAspectRatio: 1.0,
                    dragWidgetBuilder: (index, child) => child,
                    onReorder: onReorder,
                    children: children,
                  )
                : GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: mainSpacing,
                    crossAxisSpacing: crossSpacing,
                    childAspectRatio: 1.0,
                    children: children,
                  ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool danger;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? const Color(0xFFFF7474) : const Color(0xFFA98EF0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF28252E),
                ),
              ),
              const SizedBox(height: 18),
              Icon(icon, color: accent, size: 30),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17151B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
