import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/screens/dashboard_screen.dart';
import 'package:stockapp_mvp/src/features/fabric_cutting/screens/fabric_cutting_home_screen.dart';
import 'package:stockapp_mvp/src/screens/orders/order_list_screen.dart';
import 'package:stockapp_mvp/src/screens/stock/stock_browser_screen.dart';
import 'package:stockapp_mvp/src/screens/txns/txn_list_screen.dart';
import 'package:stockapp_mvp/src/screens/works/work_list_screen.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_list_screen.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_detail_screen.dart';
import 'package:stockapp_mvp/src/screens/cart/cart_screen.dart';
import 'package:stockapp_mvp/src/screens/memo/memo_screen.dart';
import 'package:stockapp_mvp/src/screens/receipts/receipt_create_screen.dart';
import 'package:stockapp_mvp/src/screens/receipts/receipts_home_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/language_settings_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/cloud_backup_list_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/settings_screen.dart';
import 'package:stockapp_mvp/src/screens/shortage/shortage_calc_screen.dart';
import 'package:stockapp_mvp/src/screens/suppliers/supplier_form_screen.dart';
import 'package:stockapp_mvp/src/screens/suppliers/supplier_list_screen.dart';
import 'package:stockapp_mvp/src/screens/trash/trash_screen.dart';

import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'package:stockapp_mvp/src/screens/dashboard/dashboard_quick_panel.dart';
import 'main_tab_controller.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // 탭별 Navigator 키
  final _dashKey = GlobalKey<NavigatorState>();
  final _orderKey = GlobalKey<NavigatorState>();
  final _stockKey = GlobalKey<NavigatorState>();
  final _txnKey = GlobalKey<NavigatorState>();
  final _workKey = GlobalKey<NavigatorState>();
  final _purchaseKey = GlobalKey<NavigatorState>();
  late final Future<Object?> Function(
    String routeName, {
    Object? arguments,
    int tabIndex,
  }) _shellRouteOpener;
  MainTabController? _tabController;

  @override
  void initState() {
    super.initState();
    _shellRouteOpener = _openShellRoute;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<MainTabController>();
    if (_tabController == controller) return;
    _tabController?.detachShellRouteOpener(_shellRouteOpener);
    _tabController = controller;
    controller.attachShellRouteOpener(_shellRouteOpener);
  }

  @override
  void dispose() {
    _tabController?.detachShellRouteOpener(_shellRouteOpener);
    super.dispose();
  }

  // 현재 탭의 navigator 키 얻기
  GlobalKey<NavigatorState> _keyOf(int index) {
    switch (index) {
      case 0:
        return _dashKey;
      case 1:
        return _orderKey;
      case 2:
        return _stockKey;
      case 3:
        return _txnKey;
      case 4:
        return _workKey;
      case 5:
        return _purchaseKey;

      default:
        return _dashKey;
    }
  }

  void _openDashboardQuickPanel() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _closeDashboardQuickPanel() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  Future<Object?> _openShellRoute(
    String routeName, {
    Object? arguments,
    int tabIndex = 0,
  }) async {
    context.read<MainTabController>().setIndex(tabIndex);
    final nav = _keyOf(tabIndex).currentState;
    if (nav == null) return null;
    nav.popUntil((route) => route.isFirst);
    return nav.pushNamed(routeName, arguments: arguments);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MainTabController>();

    // destinations 갯수(=6)에 맞게 index를 안전화
    final idx = (ctrl.index < 0 || ctrl.index > 5) ? 0 : ctrl.index;

    return WillPopScope(
      // 내부 스택이 남아있으면 pop만 하고 앱은 안나가도록
      onWillPop: () async {
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          Navigator.of(context).pop();
          return false;
        }

        final key = _keyOf(idx);
        if (key.currentState?.canPop() == true) {
          key.currentState!.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
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
          onDestinationSelected: (i) {
            if (i == 0) {
              _openDashboardQuickPanel();
              return;
            }

            context.read<MainTabController>().setIndex(i);

            // 🔥 핵심 (현재 탭 navigator 정리)
            final key = _keyOf(i);
            key.currentState?.popUntil((route) => route.isFirst);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: '대시보드'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: '주문'),
            NavigationDestination(icon: Icon(Icons.inventory_2), label: '재고'),
            NavigationDestination(icon: Icon(Icons.swap_vert), label: '입출고기록'),
            NavigationDestination(icon: Icon(Icons.handyman), label: '작업'),
            NavigationDestination(
                icon: Icon(Icons.local_shipping), label: '발주'),
          ],
        ),
        drawer: Drawer(
          width: math.min(360, MediaQuery.of(context).size.width * 0.88),
          child: DashboardQuickPanel(
            onClose: _closeDashboardQuickPanel,
          ),
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
      onGenerateRoute: (settings) {
        Widget screen;
        switch (settings.name) {
          case '/settings':
            screen = const SettingsScreen();
            break;
          case '/settings/language':
            screen = const LanguageSettingsScreen();
            break;
          case '/settings/cloud-backups':
            screen = const CloudBackupListScreen();
            break;
          case '/suppliers':
            screen = const SupplierListScreen();
            break;
          case '/suppliers/new':
            screen = const SupplierFormScreen();
            break;
          case '/suppliers/edit':
            screen =
                SupplierFormScreen(supplierId: settings.arguments as String);
            break;
          case '/receipts':
            screen = const ReceiptsHomeScreen();
            break;
          case '/receipts/new':
            screen = const ReceiptCreateScreen();
            break;
          case '/trash':
            screen = const TrashScreen();
            break;
          case '/shortage':
            screen = const ShortageCalcScreen();
            break;
          case '/memo':
            screen = const MemoScreen();
            break;
          case '/fabric-cutting':
            screen = const FabricCuttingHomeScreen();
            break;
          case '/cart':
            screen = const CartScreen();
            break;
          default:
            screen = const DashboardScreen();
        }

        return MaterialPageRoute(
          builder: (_) => screen,
          settings: settings,
        );
      },
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
      onGenerateRoute: (settings) {
        final screen = settings.name == '/stock/path'
            ? StockBrowserScreen(
                initialPath: (settings.arguments as List).cast<String>(),
              )
            : const StockBrowserScreen();

        return MaterialPageRoute(
          builder: (_) => screen,
          settings: settings,
        );
      },
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
          final repo =
              context.read<PurchaseOrderRepo>(); // PurchaseDetailScreen이 요구
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
