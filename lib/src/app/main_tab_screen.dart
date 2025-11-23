import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/screens/dashboard_screen.dart';
import 'package:stockapp_mvp/src/screens/orders/order_list_screen.dart';
import 'package:stockapp_mvp/src/screens/stock/stock_browser_screen.dart';
import 'package:stockapp_mvp/src/screens/txns/txn_list_screen.dart';
import 'package:stockapp_mvp/src/screens/works/work_list_screen.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_list_screen.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_detail_screen.dart';

import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'main_tab_controller.dart';


class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  // 탭별 Navigator 키
  final _dashKey     = GlobalKey<NavigatorState>();
  final _orderKey    = GlobalKey<NavigatorState>();
  final _stockKey    = GlobalKey<NavigatorState>();
  final _txnKey      = GlobalKey<NavigatorState>();
  final _workKey     = GlobalKey<NavigatorState>();
  final _purchaseKey = GlobalKey<NavigatorState>();


  // 현재 탭의 navigator 키 얻기
  GlobalKey<NavigatorState> _keyOf(int index) {
    switch (index) {
      case 0: return _dashKey;
      case 1: return _orderKey;
      case 2: return _stockKey;
      case 3: return _txnKey;
      case 4: return _workKey;
      case 5: return _purchaseKey;

      default: return _dashKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MainTabController>();

    // destinations 갯수(=6)에 맞게 index를 안전화
    final idx = (ctrl.index < 0 || ctrl.index > 5) ? 0 : ctrl.index;

    return WillPopScope(
      // 내부 스택이 남아있으면 pop만 하고 앱은 안나가도록
      onWillPop: () async {
        final key = _keyOf(idx);
        if (key.currentState?.canPop() == true) {
          key.currentState!.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: idx,
          children: [
            _buildDashboardNav(),
            _buildOrdersNav(),
            _buildStockNav(),
            _buildTxnsNav(),
            _buildWorksNav(),
            _buildPurchasesNav(context),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.read<MainTabController>().setIndex(i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard),     label: '대시보드'),
            NavigationDestination(icon: Icon(Icons.receipt_long),  label: '주문'),
            NavigationDestination(icon: Icon(Icons.inventory_2),   label: '재고'),
            NavigationDestination(icon: Icon(Icons.swap_vert),     label: '입출고기록'),
            NavigationDestination(icon: Icon(Icons.handyman),      label: '작업'),
            NavigationDestination(icon: Icon(Icons.local_shipping),label: '발주'),

          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 탭별 Navigator (루트는 기존 리스트 화면)
  // ─────────────────────────────────────────
  Widget _buildDashboardNav() {
    return Navigator(
      key: _dashKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
        settings: settings,
      ),
    );
  }

  Widget _buildOrdersNav() {
    return Navigator(
      key: _orderKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => const OrderListScreen(),
        settings: settings,
      ),
    );
  }

  Widget _buildStockNav() {
    return Navigator(
      key: _stockKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => const StockBrowserScreen(),
        settings: settings,
      ),
    );
  }

  Widget _buildTxnsNav() {
    return Navigator(
      key: _txnKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => const TxnListScreen(),
        settings: settings,
      ),
    );
  }

  Widget _buildWorksNav() {
    return Navigator(
      key: _workKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => const WorkListScreen(),
        settings: settings,
      ),
    );
  }

  /// ✅ 발주 탭은 상세 라우트('/detail')를 내부에 추가
  Widget _buildPurchasesNav(BuildContext context) {
    return Navigator(
      key: _purchaseKey,
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final String poId = settings.arguments as String;
          final repo = context.read<PurchaseOrderRepo>(); // PurchaseDetailScreen이 요구
          return MaterialPageRoute(
            builder: (_) => PurchaseDetailScreen(repo: repo, orderId: poId),
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
}
