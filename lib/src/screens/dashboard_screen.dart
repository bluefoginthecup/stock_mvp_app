// lib/src/screens/dashboard_screen.dart
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../app/main_tab_controller.dart';
import '../db/app_database.dart';
import '../db/quick_actions_order_dao.dart';
import '../models/purchase_order.dart';
import '../repos/modules/memo_repo.dart';
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
  late Future<String> _memoFuture;

  @override
  void initState() {
    super.initState();
    _order = [...defaultQuickActionOrder];
    _memoFuture = MemoRepo().load();
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
    final purchaseRepo = context.read<PurchaseOrderRepo>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFF),
      appBar: AppBar(
        title: Text(context.t.dashboard_title),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFAFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
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

          return StreamBuilder<List<PurchaseOrder>>(
            stream: purchaseRepo.watchAllPurchaseOrders(),
            builder: (context, purchaseSnap) {
              final purchaseDueCount =
                  _countTodayPurchaseOrders(purchaseSnap.data ?? const []);

              return FutureBuilder<String>(
                future: _memoFuture,
                builder: (context, memoSnap) {
                  final memoCount =
                      (memoSnap.data ?? '').trim().isEmpty ? 0 : 1;

                  return _DashboardContent(
                    itemCount: items.length,
                    totalQty: totalQty,
                    lowCount: low.length,
                    purchaseDueCount: purchaseDueCount,
                    memoCount: memoCount,
                    actions: actions.toList(),
                    onStockTap: () =>
                        context.read<MainTabController>().setIndex(2),
                    onLowStockTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const StockBrowserScreen(showLowStockOnly: true),
                        ),
                      );
                    },
                    onPurchaseTap: () =>
                        context.read<MainTabController>().setIndex(5),
                    onMemoTap: () => context
                        .read<MainTabController>()
                        .openShellRoute('/memo'),
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        final item = _order.removeAt(oldIndex);
                        _order.insert(newIndex, item);
                      });
                      await _persistOrderToDb();
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

  int _countTodayPurchaseOrders(List<PurchaseOrder> orders) {
    final now = DateTime.now();
    return orders.where((order) {
      if (order.isDeleted) return false;
      if (order.status == PurchaseOrderStatus.received ||
          order.status == PurchaseOrderStatus.canceled) {
        return false;
      }

      final eta = order.eta;
      return eta.year == now.year &&
          eta.month == now.month &&
          eta.day == now.day;
    }).length;
  }
}

class _DashboardContent extends StatelessWidget {
  final int itemCount;
  final int totalQty;
  final int lowCount;
  final int purchaseDueCount;
  final int memoCount;
  final List<DashboardQuickAction> actions;
  final VoidCallback onStockTap;
  final VoidCallback onLowStockTap;
  final VoidCallback onPurchaseTap;
  final VoidCallback onMemoTap;
  final ReorderCallback onReorder;

  const _DashboardContent({
    required this.itemCount,
    required this.totalQty,
    required this.lowCount,
    required this.purchaseDueCount,
    required this.memoCount,
    required this.actions,
    required this.onStockTap,
    required this.onLowStockTap,
    required this.onPurchaseTap,
    required this.onMemoTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final horizontalPadding = wide ? 24.0 : 16.0;
        final contentWidth = constraints.maxWidth - horizontalPadding * 2;
        final gridHeight = _actionGridHeight(contentWidth, actions.length);

        return SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t.dashboard_summary,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF202027),
                    ),
              ),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _SummaryPanel(
                        itemCount: itemCount,
                        totalQty: totalQty,
                        lowCount: lowCount,
                        onStockTap: onStockTap,
                        onLowStockTap: onLowStockTap,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _ChalstockAssistantCard(
                        lowCount: lowCount,
                        purchaseDueCount: purchaseDueCount,
                        memoCount: memoCount,
                        onLowStockTap: onLowStockTap,
                        onPurchaseTap: onPurchaseTap,
                        onMemoTap: onMemoTap,
                      ),
                    ),
                  ],
                )
              else ...[
                _SummaryPanel(
                  itemCount: itemCount,
                  totalQty: totalQty,
                  lowCount: lowCount,
                  onStockTap: onStockTap,
                  onLowStockTap: onLowStockTap,
                ),
                const SizedBox(height: 12),
                _ChalstockAssistantCard(
                  lowCount: lowCount,
                  purchaseDueCount: purchaseDueCount,
                  memoCount: memoCount,
                  onLowStockTap: onLowStockTap,
                  onPurchaseTap: onPurchaseTap,
                  onMemoTap: onMemoTap,
                ),
              ],
              const SizedBox(height: 28),
              Text(
                '빠른 실행 (${actions.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF202027),
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: gridHeight,
                child: _DashboardActionGrid(
                  actions: actions,
                  onReorder: onReorder,
                ),
              ),
            ],
          ),
        );
      },
    );
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
  final int purchaseDueCount;
  final int memoCount;
  final VoidCallback onLowStockTap;
  final VoidCallback onPurchaseTap;
  final VoidCallback onMemoTap;

  const _ChalstockAssistantCard({
    required this.lowCount,
    required this.purchaseDueCount,
    required this.memoCount,
    required this.onLowStockTap,
    required this.onPurchaseTap,
    required this.onMemoTap,
  });

  @override
  State<_ChalstockAssistantCard> createState() =>
      _ChalstockAssistantCardState();
}

class _ChalstockAssistantCardState extends State<_ChalstockAssistantCard> {
  static const _happyPuppyAsset = 'assets/images/chal_happy.png';
  static const _discPuppyAsset = 'assets/images/chal_pup2.png';

  bool _expanded = false;

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
                  child: _SpeechBubble(
                    text: widget.lowCount > 0
                        ? '재고 ${widget.lowCount}개가\n부족해요!'
                        : '오늘도 재고가\n든든해요!',
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 128,
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
        _AssistantTaskPanel(
          lowCount: widget.lowCount,
          purchaseDueCount: widget.purchaseDueCount,
          memoCount: widget.memoCount,
          onLowStockTap: widget.onLowStockTap,
          onPurchaseTap: widget.onPurchaseTap,
          onMemoTap: widget.onMemoTap,
        ),
        const SizedBox(height: 12),
        const _TipPanel(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onLowStockTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C5BEA),
                  side: const BorderSide(color: Color(0xFF8B6BEF)),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('자세히 보기'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: widget.onLowStockTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5BEA),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('바로가기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;

  const _SpeechBubble({required this.text});

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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B2930),
          ),
        ),
      ),
    );
  }
}

class _AssistantTaskPanel extends StatelessWidget {
  final int lowCount;
  final int purchaseDueCount;
  final int memoCount;
  final VoidCallback onLowStockTap;
  final VoidCallback onPurchaseTap;
  final VoidCallback onMemoTap;

  const _AssistantTaskPanel({
    required this.lowCount,
    required this.purchaseDueCount,
    required this.memoCount,
    required this.onLowStockTap,
    required this.onPurchaseTap,
    required this.onMemoTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E2F5)),
      ),
      child: Column(
        children: [
          _AssistantTaskRow(
            icon: Icons.warning_rounded,
            iconColor: const Color(0xFFFF7474),
            label: '재고 부족 아이템',
            value: '$lowCount개',
            onTap: onLowStockTap,
          ),
          _AssistantTaskRow(
            icon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF6A7AF5),
            label: '오늘 발주 예정',
            value: '$purchaseDueCount건',
            onTap: onPurchaseTap,
          ),
          _AssistantTaskRow(
            icon: Icons.note_alt_rounded,
            iconColor: const Color(0xFF8B6BEF),
            label: '미확인 메모',
            value: '$memoCount개',
            onTap: onMemoTap,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _AssistantTaskRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  const _AssistantTaskRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
              ],
            ),
          ),
          if (showDivider) const Divider(height: 1, indent: 52, endIndent: 16),
        ],
      ),
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
                '임계치 설정을 하면 재고 부족을 더 빨리 발견할 수 있어요!',
                style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
