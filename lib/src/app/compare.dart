import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/purchases/purchase_list_screen.dart';
import '../screens/stock/stock_browser_screen.dart';
import '../screens/dashboard_screen.dart';
import '../repos/inmem_repo.dart';
import '../screens/purchases/purchase_detail_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _index = 0;

  // 탭별 Navigator 키
  final _dashboardKey = GlobalKey<NavigatorState>();
  final _purchasesKey = GlobalKey<NavigatorState>();
  final _stockKey     = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 안쪽 Navigator가 pop 가능하면 그걸 먼저 pop
      onWillPop: () async {
        final currentKey = [_dashboardKey, _purchasesKey, _stockKey][_index];
        if (currentKey.currentState?.canPop() == true) {
          currentKey.currentState!.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _buildDashboardNav(),
            _buildPurchasesNav(context),
            _buildStockNav(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: '대시보드'),
            NavigationDestination(icon: Icon(Icons.list_alt),  label: '발주서'),
            NavigationDestination(icon: Icon(Icons.inventory), label: '재고'),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 각 탭용 Navigator
  // ─────────────────────────────────────────
  Widget _buildDashboardNav() {
    return Navigator(
      key: _dashboardKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
          settings: settings,
        );
      },
    );
  }

  Widget _buildPurchasesNav(BuildContext context) {
    return Navigator(
      key: _purchasesKey,
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final id = settings.arguments as String;
          final repo = context.read<InMemoryRepo>();
          return MaterialPageRoute(
            builder: (_) => PurchaseDetailScreen(repo: repo, orderId: id),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const PurchaseListScreen(),
          settings: settings,
        );
      },
    );
  }

  Widget _buildStockNav() {
    return Navigator(
      key: _stockKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const StockBrowserScreen(),
          settings: settings,
        );
      },
    );
  }
}
