// lib/src/app/main_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stockapp_mvp/src/screens/settings/language_settings_screen.dart';
import 'package:stockapp_mvp/src/screens/txns/txn_list_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/stock/stock_browser_screen.dart';
import '../screens/orders/order_list_screen.dart';
import '../screens/works/work_list_screen.dart';
import '../screens/purchases/purchase_list_screen.dart';
import 'main_tab_controller.dart';

class MainTabScreen extends StatelessWidget {
  const MainTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final idx = context.watch<MainTabController>().index;

    // 각 탭은 자기 Scaffold를 이미 가지고 있다고 가정
    final screens = const <Widget>[
      DashboardScreen(),
      OrderListScreen(),
      StockBrowserScreen(),
      TxnListScreen(),
      WorkListScreen(),
      PurchaseListScreen(),
      LanguageSettingsScreen(),
    ];

    return Scaffold(
      // 각 탭 상태 유지 위해 IndexedStack 사용
      body: IndexedStack(index: idx, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) =>
            context.read<MainTabController>().setIndex(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: '대시보드'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: '주문'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: '재고'),
          NavigationDestination(icon: Icon(Icons.swap_vert), label: '입출고기록'),
          NavigationDestination(icon: Icon(Icons.handyman), label: '작업'),
          NavigationDestination(icon: Icon(Icons.local_shipping), label: '발주'),

        ],
      ),
    );
  }
}
