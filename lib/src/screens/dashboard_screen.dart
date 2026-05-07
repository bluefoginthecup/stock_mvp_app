// lib/src/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../app/main_tab_controller.dart';
import '../db/app_database.dart';
import '../db/quick_actions_order_dao.dart';
import '../models/today_activity_summary.dart';
import '../repos/repo_interfaces.dart';
import '../services/dashboard_activity_service.dart';
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
    final activityService = context.read<DashboardActivityService>();

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

          return StreamBuilder<TodayActivitySummary>(
            stream: activityService.watchTodaySummary(),
            initialData: TodayActivitySummary.empty,
            builder: (context, activitySnap) {
              return _DashboardContent(
                itemCount: items.length,
                totalQty: totalQty,
                lowCount: low.length,
                todaySummary: activitySnap.data ?? TodayActivitySummary.empty,
                actions: actions.toList(),
                onStockTap: () => context.read<MainTabController>().setIndex(2),
                onLowStockTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const StockBrowserScreen(showLowStockOnly: true),
                    ),
                  );
                },
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
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final int itemCount;
  final int totalQty;
  final int lowCount;
  final TodayActivitySummary todaySummary;
  final List<DashboardQuickAction> actions;
  final VoidCallback onStockTap;
  final VoidCallback onLowStockTap;
  final ReorderCallback onReorder;

  const _DashboardContent({
    required this.itemCount,
    required this.totalQty,
    required this.lowCount,
    required this.todaySummary,
    required this.actions,
    required this.onStockTap,
    required this.onLowStockTap,
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
                        todaySummary: todaySummary,
                        onOpenOrders: () =>
                            context.read<MainTabController>().setIndex(1),
                        onOpenTxns: () =>
                            context.read<MainTabController>().setIndex(3),
                        onOpenWorks: () =>
                            context.read<MainTabController>().setIndex(4),
                        onOpenPurchases: () =>
                            context.read<MainTabController>().setIndex(5),
                        onOpenSchedules: () => context
                            .read<MainTabController>()
                            .openShellRoute('/schedules'),
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
                  todaySummary: todaySummary,
                  onOpenOrders: () =>
                      context.read<MainTabController>().setIndex(1),
                  onOpenTxns: () =>
                      context.read<MainTabController>().setIndex(3),
                  onOpenWorks: () =>
                      context.read<MainTabController>().setIndex(4),
                  onOpenPurchases: () =>
                      context.read<MainTabController>().setIndex(5),
                  onOpenSchedules: () => context
                      .read<MainTabController>()
                      .openShellRoute('/schedules'),
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
