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
import '../models/today_activity_summary.dart';
import '../repos/repo_interfaces.dart';
import '../services/dashboard_activity_service.dart';
import '../services/dashboard_purchase_stats_service.dart';
import '../ui/common/ui.dart';
import 'dashboard/dashboard_quick_actions.dart';
import 'stock/stock_browser_screen.dart';

const _dashboardSectionOrderPrefsKey = 'dashboard.sectionOrder.v1';
const _dashboardHiddenSectionsPrefsKey = 'dashboard.hiddenSections.v1';
const _dashboardCollapsedSectionsPrefsKey = 'dashboard.collapsedSections.v1';

enum _DashboardSectionType {
  summary('summary', '현재 요약', Icons.dashboard_customize_rounded),
  assistant('assistant', '오늘의 찰스톡', Icons.pets_rounded),
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
  bool _editingDashboard = false;

  @override
  void initState() {
    super.initState();
    _order = [...defaultQuickActionOrder];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderFromDb();
      _loadDashboardLayout();
    });
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: '알림',
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () {},
                ),
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
          if (_editingDashboard)
            IconButton(
              tooltip: '카드 추가',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: _showAddSectionSheet,
            ),
          TextButton(
            onPressed: () {
              setState(() => _editingDashboard = !_editingDashboard);
            },
            child: Text(_editingDashboard ? '완료' : '편집'),
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
                if (i > 0) const SizedBox(height: 18),
                _buildSection(context, sections[i], gridHeight),
              ],
            ],
          ),
        );
      },
    );
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
  final Widget child;

  const _DashboardSectionShell({
    required this.section,
    required this.collapsed,
    required this.onToggleCollapsed,
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
          Row(
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
              TextButton.icon(
                onPressed: onToggleCollapsed,
                icon: Icon(
                  collapsed
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 20,
                ),
                label: Text(collapsed ? '펼치기' : '접기'),
              ),
            ],
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
    return Row(
      children: [
        const Icon(Icons.pets_rounded, color: Color(0xFF8B6BEF), size: 22),
        const SizedBox(width: 8),
        Text(
          '오늘의 찰스톡',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF7756E7),
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        Icon(
          _expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.chevron_right_rounded,
          color: const Color(0xFF8B6BEF),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: _SpeechBubble(
                    text: _compactMessages[_compactMessageIndex],
                    compact: true,
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
      child: lines.isEmpty
          ? const Padding(
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
          : Column(
              children: [
                for (var i = 0; i < lines.length; i++)
                  _TodayActivityRow(
                    line: lines[i],
                    showDivider: i != lines.length - 1,
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

  String _time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9E2F5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenSchedules,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ScheduleCountPill(
                    label: '할일',
                    value: pending.length,
                    color: const Color(0xFF8B6BEF),
                  ),
                  const SizedBox(width: 8),
                  _ScheduleCountPill(
                    label: '완료',
                    value: done.length,
                    color: const Color(0xFF37A66B),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8B6BEF),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (visibleSchedules.isEmpty)
                const Text(
                  '오늘 등록된 일정이 없습니다.',
                  style: TextStyle(
                    color: Color(0xFF7A7480),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < visibleSchedules.length; i++)
                      _SchedulePreviewRow(
                        schedule: visibleSchedules[i],
                        time: _time(visibleSchedules[i].date),
                        showDivider: i != visibleSchedules.length - 1,
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

class _ScheduleCountPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ScheduleCountPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: const TextStyle(
                color: Color(0xFF202027),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePreviewRow extends StatelessWidget {
  final AppSchedule schedule;
  final String time;
  final bool showDivider;

  const _SchedulePreviewRow({
    required this.schedule,
    required this.time,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final done = schedule.status == AppScheduleStatus.done;
    final color = done ? const Color(0xFF37A66B) : const Color(0xFF8B6BEF);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(
                done ? Icons.task_alt_rounded : Icons.radio_button_unchecked,
                color: color,
                size: 21,
              ),
              const SizedBox(width: 10),
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF7A7480),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  schedule.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF202027),
                    fontWeight: FontWeight.w800,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 31),
      ],
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
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    color: Color(0xFF7756E7),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '발주 통계',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF2B2930),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8B6BEF),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
