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
    tabs.setIndex(0);
  }

  @override
  Widget build(BuildContext context) {
    final actions = _order
        .map(
          (type) => buildDashboardQuickAction(
            context,
            type,
            onBeforeNavigate: widget.onClose,
          ),
        )
        .toList();

    return SafeArea(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Text(
                    '대시보드',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '전체 대시보드',
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                    onPressed: _openFullDashboard,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: actions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return DashboardQuickActionListTile(
                    key: action.key,
                    action: action,
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
