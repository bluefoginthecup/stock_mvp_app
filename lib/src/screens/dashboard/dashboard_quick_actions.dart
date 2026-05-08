import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/main_tab_controller.dart';
import '../../l10n/l10n_x.dart';

enum QuickActionType {
  orders,
  stock,
  txns,
  works,
  purchases,
  quotes,
  settings,
  suppliers,
  shippingDestinations,
  storageLocations,
  receipts,
  trash,
  shortage,
  memo,
  schedules,
  fabricCutting,
}

const defaultQuickActionOrder = <QuickActionType>[
  QuickActionType.orders,
  QuickActionType.stock,
  QuickActionType.txns,
  QuickActionType.works,
  QuickActionType.purchases,
  QuickActionType.quotes,
  QuickActionType.settings,
  QuickActionType.suppliers,
  QuickActionType.shippingDestinations,
  QuickActionType.storageLocations,
  QuickActionType.receipts,
  QuickActionType.trash,
  QuickActionType.shortage,
  QuickActionType.memo,
  QuickActionType.schedules,
  QuickActionType.fabricCutting,
];

String quickActionIdOf(QuickActionType type) => type.name;

QuickActionType? quickActionTypeOfOrNull(String id) {
  final normalized = id == 'language' ? 'settings' : id;
  for (final type in QuickActionType.values) {
    if (type.name == normalized) return type;
  }
  return null;
}

QuickActionType quickActionTypeOf(String id) {
  return quickActionTypeOfOrNull(id) ?? QuickActionType.orders;
}

List<QuickActionType> mergeQuickActionOrder(List<String> ids) {
  final saved = ids
      .map(quickActionTypeOf)
      .where(defaultQuickActionOrder.contains)
      .toList();
  final missing =
      defaultQuickActionOrder.where((type) => !saved.contains(type));
  return [...saved, ...missing];
}

class DashboardQuickAction {
  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DashboardQuickAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

DashboardQuickAction buildDashboardQuickAction(
  BuildContext context,
  QuickActionType type, {
  VoidCallback? onChanged,
  VoidCallback? onBeforeNavigate,
}) {
  switch (type) {
    case QuickActionType.orders:
      return DashboardQuickAction(
        key: const ValueKey('orders'),
        icon: Icons.assignment,
        label: context.t.dashboard_orders,
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.setIndex(1);
        },
      );
    case QuickActionType.stock:
      return DashboardQuickAction(
        key: const ValueKey('stock'),
        icon: Icons.inventory_2,
        label: context.t.dashboard_stock,
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.setIndex(2);
        },
      );
    case QuickActionType.txns:
      return DashboardQuickAction(
        key: const ValueKey('txns'),
        icon: Icons.swap_vert,
        label: context.t.dashboard_txns,
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.setIndex(3);
        },
      );
    case QuickActionType.works:
      return DashboardQuickAction(
        key: const ValueKey('works'),
        icon: Icons.precision_manufacturing,
        label: context.t.dashboard_works,
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.setIndex(4);
        },
      );
    case QuickActionType.purchases:
      return DashboardQuickAction(
        key: const ValueKey('purchases'),
        icon: Icons.local_shipping,
        label: context.t.dashboard_purchases,
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.setIndex(5);
        },
      );
    case QuickActionType.quotes:
      return DashboardQuickAction(
        key: const ValueKey('quotes'),
        icon: Icons.request_quote_outlined,
        label: '견적',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/quotes');
        },
      );
    case QuickActionType.settings:
      return DashboardQuickAction(
        key: const ValueKey('settings'),
        icon: Icons.settings,
        label: '설정',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/settings');
        },
      );
    case QuickActionType.suppliers:
      return DashboardQuickAction(
        key: const ValueKey('suppliers'),
        icon: Icons.business,
        label: '거래처 목록',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/suppliers');
        },
      );
    case QuickActionType.shippingDestinations:
      return DashboardQuickAction(
        key: const ValueKey('shippingDestinations'),
        icon: Icons.local_shipping_outlined,
        label: '배송지 관리',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/settings/shipping-destinations');
        },
      );
    case QuickActionType.storageLocations:
      return DashboardQuickAction(
        key: const ValueKey('storageLocations'),
        icon: Icons.location_on_outlined,
        label: '보관 위치 관리',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/settings/storage-locations');
        },
      );
    case QuickActionType.receipts:
      return DashboardQuickAction(
        key: const ValueKey('receipts'),
        icon: Icons.receipt_long,
        label: '영수증 관리',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/receipts');
        },
      );
    case QuickActionType.trash:
      return DashboardQuickAction(
        key: const ValueKey('trash'),
        icon: Icons.delete_outline,
        label: '통합 휴지통',
        onTap: () async {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          final changed = await tabs.openShellRoute<bool>('/trash');
          if (changed == true) onChanged?.call();
        },
      );
    case QuickActionType.shortage:
      return DashboardQuickAction(
        key: const ValueKey('shortage'),
        icon: Icons.rule_folder,
        label: '부족분계산',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/shortage');
        },
      );
    case QuickActionType.memo:
      return DashboardQuickAction(
        key: const ValueKey('memo'),
        icon: Icons.note_alt_outlined,
        label: '메모',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/memo');
        },
      );
    case QuickActionType.schedules:
      return DashboardQuickAction(
        key: const ValueKey('schedules'),
        icon: Icons.event_note,
        label: '일정/할일',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/schedules');
        },
      );
    case QuickActionType.fabricCutting:
      return DashboardQuickAction(
        key: const ValueKey('fabricCutting'),
        icon: Icons.content_cut,
        label: '배색 재단 계산기',
        onTap: () {
          final tabs = context.read<MainTabController>();
          onBeforeNavigate?.call();
          tabs.openShellRoute('/fabric-cutting');
        },
      );
  }
}

class DashboardQuickActionGridTile extends StatelessWidget {
  final DashboardQuickAction action;

  const DashboardQuickActionGridTile({
    super.key,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).dividerColor),
    );

    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      color: scheme.surface,
      shape: shape,
      child: InkWell(
        onTap: action.onTap,
        customBorder: shape,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardQuickActionListTile extends StatelessWidget {
  final DashboardQuickAction action;
  final Widget? trailing;

  const DashboardQuickActionListTile({
    super.key,
    required this.action,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Theme.of(context).dividerColor),
    );

    return Material(
      color: scheme.surface,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: shape,
      child: InkWell(
        onTap: action.onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(action.icon, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
