// lib/src/screens/dashboard_screen.dart
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../app/main_tab_controller.dart';
import '../db/app_database.dart';
import '../db/quick_actions_order_dao.dart';
import '../repos/repo_interfaces.dart';
import '../ui/common/ui.dart';
import 'dashboard/dashboard_quick_actions.dart';
import 'stock/stock_browser_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late List<QuickActionType> _order;

  @override
  void initState() {
    super.initState();
    _order = [...defaultQuickActionOrder];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderFromDb();
    });
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

    return Scaffold(
      appBar: AppBar(title: Text(context.t.dashboard_title)),
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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t.dashboard_summary,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      title: context.t.dashboard_total_items,
                      value: items.length.toString(),
                      onTap: () =>
                          context.read<MainTabController>().setIndex(2),
                    ),
                    _StatCard(
                      title: '전체 수량',
                      value: totalQty.toString(),
                      onTap: () =>
                          context.read<MainTabController>().setIndex(2),
                    ),
                    _StatCard(
                      title: context.t.dashboard_below_threshold,
                      value: low.length.toString(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StockBrowserScreen(
                                showLowStockOnly: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '빠른 실행 (${_order.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _DashboardActionGrid(
                    actions: actions.toList(),
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        final item = _order.removeAt(oldIndex);
                        _order.insert(newIndex, item);
                      });
                      await _persistOrderToDb();
                    },
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

class _DashboardActionGrid extends StatelessWidget {
  final List<DashboardQuickAction> actions;
  final ReorderCallback onReorder;

  const _DashboardActionGrid({
    required this.actions,
    required this.onReorder,
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

        return Center(
          child: SizedBox(
            width: gridContentWidth,
            height: availableHeight,
            child: ReorderableGridView.count(
              physics: actions.length > (crossAxisCount * rowsForLayout)
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainSpacing,
              crossAxisSpacing: crossSpacing,
              childAspectRatio: 1.0,
              dragWidgetBuilder: (index, child) => child,
              onReorder: onReorder,
              children: [
                for (final action in actions)
                  DashboardQuickActionGridTile(
                    key: action.key,
                    action: action,
                  ),
              ],
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
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
