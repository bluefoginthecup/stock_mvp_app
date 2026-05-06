import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/main_tab_controller.dart';
import '../../db/app_database.dart';
import '../../db/quick_actions_order_dao.dart';
import 'dashboard_quick_actions.dart';

class DashboardQuickPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const DashboardQuickPanel({
    super.key,
    this.onClose,
  });

  @override
  State<DashboardQuickPanel> createState() => _DashboardQuickPanelState();
}

class _DashboardQuickPanelState extends State<DashboardQuickPanel> {
  List<QuickActionType> _order = [...defaultQuickActionOrder];

  @override
  void initState() {
    super.initState();
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
      setState(() => _order = mergeQuickActionOrder(ids));
    } catch (_) {
      if (!mounted) return;
      setState(() => _order = [...defaultQuickActionOrder]);
    }
  }

  Future<void> _persistOrderToDb() async {
    try {
      final db = context.read<AppDatabase>();
      final dao = QuickActionsOrderDao(db);
      await dao.saveOrder(_order.map(quickActionIdOf).toList());
    } catch (_) {
      // 순서 저장 실패가 패널 사용을 막지는 않는다.
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });

    await _persistOrderToDb();
  }

  void _openFullDashboard() {
    final tabs = context.read<MainTabController>();
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
    tabs.openShellRoute(Navigator.defaultRouteName);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Material(
        color: scheme.surface,
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '대시보드',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.all(12),
                      itemCount: _order.length,
                      onReorder: _reorder,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 1, end: 1.02).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      itemBuilder: (context, index) {
                        final type = _order[index];
                        final action = buildDashboardQuickAction(
                          context,
                          type,
                          onBeforeNavigate: widget.onClose,
                        );

                        return Padding(
                          key: ValueKey('quick-panel-${quickActionIdOf(type)}'),
                          padding: EdgeInsets.only(
                            bottom: index == _order.length - 1 ? 0 : 8,
                          ),
                          child: DashboardQuickActionListTile(
                            action: action,
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.drag_handle, size: 20),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: '전체 대시보드로 이동',
              child: InkWell(
                onTap: _openFullDashboard,
                child: Container(
                  width: 44,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.36),
                    border: Border(
                      left: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.primary,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
