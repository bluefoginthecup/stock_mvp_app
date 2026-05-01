import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main_tab_controller.dart';
import 'main_tab_screen.dart';

class DesktopHome extends StatelessWidget {
  const DesktopHome({super.key});
  static const _breakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bc) {
        final wide = bc.maxWidth >= _breakpoint;
        if (!wide) return const MainTabScreen();

        return Row(
          children: [
            const _DesktopRail(),
            const VerticalDivider(width: 1),
            const Expanded(child: MainTabScreen()),
          ],
        );
      },
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail();

  @override
  Widget build(BuildContext context) {
    final tabs = context.read<MainTabController>();
    final selected = context.select<MainTabController, int>((c) => c.index);

    return NavigationRail(
      selectedIndex: selected,
      onDestinationSelected: tabs.jumpTo,
      labelType: NavigationRailLabelType.all,
      minWidth: 80,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: Text('재고'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: Text('주문'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: Text('발주'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.engineering_outlined),
          selectedIcon: Icon(Icons.engineering),
          label: Text('작업'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('입출고'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('설정'),
        ),
      ],
    );
  }
}
