// lib/src/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../repos/repo_interfaces.dart';
import '../ui/common/ui.dart';
import '../screens/stock/stock_browser_screen.dart';
import '../app/main_tab_controller.dart';
import 'package:stockapp_mvp/src/screens/settings/language_settings_screen.dart';
import 'package:stockapp_mvp/src/db/app_database.dart';
import 'package:stockapp_mvp/src/db/quick_actions_order_dao.dart';


enum QuickActionType {
  orders, stock, txns, works, purchases, language, suppliers, receipts,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  late List<QuickActionType> _order;

  bool _orderLoaded = false;

  // enum ↔ string
  String _idOf(QuickActionType t) => t.name;
  QuickActionType _typeOf(String id) =>
      QuickActionType.values.firstWhere(
            (e) => e.name == id,
        orElse: () => QuickActionType.orders,
      );

  @override
  void initState() {
    super.initState();

    // 1) 기본 순서 초기화
    _order = [
      QuickActionType.orders,
      QuickActionType.stock,
      QuickActionType.txns,
      QuickActionType.works,
      QuickActionType.purchases,
      QuickActionType.language,
      QuickActionType.suppliers,
      QuickActionType.receipts,
    ];

    // 2) DB에서 저장된 순서 로드 (화면 뜬 뒤)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderFromDb();
    });
  }

    Future<void> _loadOrderFromDb() async {
        try {
          final db = context.read<AppDatabase>(); // AppDatabase를 Provider로 주입했다고 가정
          final dao = QuickActionsOrderDao(db);
          final ids = await dao.loadOrder();
          if (ids.isNotEmpty) {
            setState(() {
              _order = ids.map(_typeOf).toList();
              _orderLoaded = true;
            });
          } else {
            setState(() => _orderLoaded = true);
          }
        } catch (_) {
          // 로드 실패 시 기본 순서로 진행
          setState(() => _orderLoaded = true);
        }
      }

    Future<void> _persistOrderToDb() async {
        try {
          final db = context.read<AppDatabase>();
          final dao = QuickActionsOrderDao(db);
          await dao.saveOrder(_order.map(_idOf).toList());
        } catch (_) {
          // 저장 실패는 조용히 무시(로그 필요시 추가)
        }
      }
  @override
  Widget build(BuildContext context) {
    final itemRepo = context.read<ItemRepo>();

    // type → 버튼 정의(아이콘/라벨/동작) 매핑
    _QuickAction _map(QuickActionType t) {
      switch (t) {
        case QuickActionType.orders:
          return _QuickAction(
            key: const ValueKey('orders'),
            icon: Icons.assignment,
            label: context.t.dashboard_orders,
            onTap: () => context.read<MainTabController>().setIndex(1),
          );
        case QuickActionType.stock:
          return _QuickAction(
            key: const ValueKey('stock'),
            icon: Icons.inventory_2,
            label: context.t.dashboard_stock,
            onTap: () => context.read<MainTabController>().setIndex(2),
          );
        case QuickActionType.txns:
          return _QuickAction(
            key: const ValueKey('txns'),
            icon: Icons.swap_vert,
            label: context.t.dashboard_txns,
            onTap: () => context.read<MainTabController>().setIndex(3),
          );
        case QuickActionType.works:
          return _QuickAction(
            key: const ValueKey('works'),
            icon: Icons.precision_manufacturing,
            label: context.t.dashboard_works,
            onTap: () => context.read<MainTabController>().setIndex(4),
          );
        case QuickActionType.purchases:
          return _QuickAction(
            key: const ValueKey('purchases'),
            icon: Icons.local_shipping,
            label: context.t.dashboard_purchases,
            onTap: () => context.read<MainTabController>().setIndex(5),
          );
        case QuickActionType.language:
          return _QuickAction(
            key: const ValueKey('language'),
            icon: Icons.settings,
            label: context.t.settings_language_title,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
              );
            },
          );
        case QuickActionType.suppliers:
          return _QuickAction(
            key: const ValueKey('suppliers'),
            icon: Icons.business,
            label: '거래처 목록',
            onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/suppliers'),
          );
        case QuickActionType.receipts:
          return _QuickAction(
            key: const ValueKey('receipts'),
            icon: Icons.receipt_long,
            label: '영수증 관리',
            onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/receipts'),
          );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t.dashboard_title)),
      body: FutureBuilder(
        future: itemRepo.listItems(),
        builder: (context, snap) {
          final items = (snap.data ?? []);
          final low = items.where((e) => e.qty <= e.minQty).toList();

          // 화면에 그릴 액션들 (현재 순서에 맞춰 구성)
          final actions = _order.map(_map).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 요약 카드 섹션 ─────────────────────────────────────
                Text(context.t.dashboard_summary,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      title: context.t.dashboard_total_items,
                      value: items.length.toString(),
                      onTap: () => context.read<MainTabController>().setIndex(2),
                    ),
                    _StatCard(
                      title: context.t.dashboard_below_threshold,
                      value: low.length.toString(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StockBrowserScreen(showLowStockOnly: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Text('빠른 실행', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                // ── 중앙 정사각형 2×4 + 드래그 재정렬 ────────────────────
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 레이아웃 상수
                      const rows = 4;
                      const crossAxisCount = 2;
                      const crossSpacing = 12.0;
                      const mainSpacing = 12.0;
                      const horizontalPagePadding = 16.0;

                      final screenWidth = MediaQuery.of(context).size.width;
                      final availableHeight = constraints.maxHeight;

                      // 4행을 정확히 채우는 타일 높이
                      final maxRowHeight =
                          (availableHeight - mainSpacing * (rows - 1)) / rows;

                      // 그리드 최대 폭 제한(버튼이 가로로 너무 넓어지지 않도록)
                      final maxGridWidthByScreen = screenWidth - horizontalPagePadding * 2;
                      const maxPreferredGridWidth = 480.0;
                      final tentativeGridWidth = maxGridWidthByScreen < maxPreferredGridWidth
                          ? maxGridWidthByScreen
                          : maxPreferredGridWidth;

                      // 2열 + 간격에서의 타일 폭
                      final maxColWidth =
                          (tentativeGridWidth - crossSpacing) / crossAxisCount;

                      // 정사각형 타일 한 변 길이
                      final tileSize =
                      maxRowHeight < maxColWidth ? maxRowHeight : maxColWidth;

                      // 실제 그리드 컨테이너 폭
                      final gridContentWidth = tileSize * 2 + crossSpacing;

                      return Center(
                        child: SizedBox(
                          width: gridContentWidth,
                          child: ReorderableGridView.count(
                            // 스크롤 없이 영역 내에서만 드래그
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: mainSpacing,
                            crossAxisSpacing: crossSpacing,
                            childAspectRatio: 1.0, // 정사각형
                            // 드래그 시작 제스처(기본: long-press)
                            dragWidgetBuilder: (index, child) => child,

                            onReorder: (oldIndex, newIndex) async {
                              setState(() {
                                final moved = _order.removeAt(oldIndex);
                                _order.insert(newIndex, moved);
                              });
                              // 변경 즉시 DB 반영
                              await _persistOrderToDb();
                            },
                            children: [
                              for (final a in actions)
                                _QuickTile(
                                  key: a.key, // 반드시 고유 Key!
                                  action: a,
                                ),
                            ],
                          ),
                        ),
                      );
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  const _StatCard({required this.title, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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

class _QuickAction {
  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _QuickTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: action.key, // ← Reorderable용 고유 Key
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 힌트: 길게 눌러서 순서 변경
                  Text('↕ 길게 눌러 이동', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
