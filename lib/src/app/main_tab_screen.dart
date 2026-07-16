import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stockapp_mvp/src/screens/dashboard_screen.dart';
import 'package:stockapp_mvp/src/features/fantasy_dashboard/fantasy_dashboard_screen.dart';
import 'package:stockapp_mvp/src/features/fabric_cutting/screens/fabric_cutting_home_screen.dart';
import 'package:stockapp_mvp/src/screens/orders/order_detail_screen.dart';
import 'package:stockapp_mvp/src/screens/orders/order_list_screen.dart';
import 'package:stockapp_mvp/src/screens/stock/stock_browser_screen.dart';
import 'package:stockapp_mvp/src/screens/stock/stock_item_detail_screen.dart';
import 'package:stockapp_mvp/src/screens/txns/txn_list_screen.dart';
import 'package:stockapp_mvp/src/screens/works/work_list_screen.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_list_screen.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_detail_screen.dart';
import 'package:stockapp_mvp/src/screens/quotes/quote_list_screen.dart';
import 'package:stockapp_mvp/src/screens/quotes/quote_detail_screen.dart';
import 'package:stockapp_mvp/src/screens/cart/cart_screen.dart';
import 'package:stockapp_mvp/src/screens/integrations/playauto_order_import_screen.dart';
import 'package:stockapp_mvp/src/screens/memo/memo_screen.dart';
import 'package:stockapp_mvp/src/screens/schedules/schedule_list_screen.dart';
import 'package:stockapp_mvp/src/screens/receipts/receipt_create_screen.dart';
import 'package:stockapp_mvp/src/screens/receipts/receipts_home_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/language_settings_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/cloud_backup_list_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/settings_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/shipping_destination_screen.dart';
import 'package:stockapp_mvp/src/screens/settings/storage_location_screen.dart';
import 'package:stockapp_mvp/src/screens/shortage/shortage_calc_screen.dart';
import 'package:stockapp_mvp/src/screens/suppliers/supplier_form_screen.dart';
import 'package:stockapp_mvp/src/screens/suppliers/supplier_list_screen.dart';
import 'package:stockapp_mvp/src/screens/trash/trash_screen.dart';

import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'package:stockapp_mvp/src/screens/dashboard/dashboard_quick_panel.dart';
import 'main_tab_controller.dart';

const _bottomTabOrderPrefsKey = 'main.bottomTabs.order.v1';
const _bottomTabHiddenPrefsKey = 'main.bottomTabs.hidden.v1';
const _playAutoTabId = 'playauto';

class _BottomTabSpec {
  final String id;
  final String label;
  final IconData icon;

  const _BottomTabSpec({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _ScrollableBottomTabs extends StatelessWidget {
  final List<_BottomTabSpec> tabs;
  final String selectedId;
  final ScrollController scrollController;
  final ValueChanged<String> onSelect;
  final VoidCallback onEdit;

  const _ScrollableBottomTabs({
    required this.tabs,
    required this.selectedId,
    required this.scrollController,
    required this.onSelect,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SizedBox(
          height: 76,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: false,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: tabs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 1),
              itemBuilder: (context, index) {
                if (index == tabs.length) {
                  return _BottomTabEditButton(onTap: onEdit);
                }
                final tab = tabs[index];
                return _BottomTabButton(
                  tab: tab,
                  selected: tab.id == selectedId,
                  onTap: () => onSelect(tab.id),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTabButton extends StatelessWidget {
  final _BottomTabSpec tab;
  final bool selected;
  final VoidCallback onTap;

  const _BottomTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final background =
        selected ? scheme.primaryContainer.withValues(alpha: 0.54) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Material(
        color: background ?? Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 66,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, color: color, size: 24),
                  const SizedBox(height: 5),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
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

class _BottomTabEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BottomTabEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 56,
            child: Center(
              child: Tooltip(
                message: '하단 탭 편집',
                child: Icon(
                  Icons.edit_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTabEditResult {
  final List<String> order;
  final Set<String> visibleIds;

  const _BottomTabEditResult({
    required this.order,
    required this.visibleIds,
  });
}

class _BottomTabEditorSheet extends StatefulWidget {
  final List<_BottomTabSpec> allTabs;
  final List<String> order;
  final Set<String> visibleIds;

  const _BottomTabEditorSheet({
    required this.allTabs,
    required this.order,
    required this.visibleIds,
  });

  @override
  State<_BottomTabEditorSheet> createState() => _BottomTabEditorSheetState();
}

class _BottomTabEditorSheetState extends State<_BottomTabEditorSheet> {
  late List<String> _order;
  late Set<String> _visibleIds;

  @override
  void initState() {
    super.initState();
    _order = [...widget.order];
    _visibleIds = {...widget.visibleIds};
    _visibleIds.add(MainTabController.dashboardTabId);
  }

  _BottomTabSpec _tabById(String id) {
    return widget.allTabs.firstWhere(
      (tab) => tab.id == id,
      orElse: () => widget.allTabs.first,
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final id = _order.removeAt(oldIndex);
      _order.insert(newIndex, id);
    });
  }

  void _reset() {
    setState(() {
      _order = widget.allTabs.map((tab) => tab.id).toList(growable: false);
      _visibleIds = _order.toSet();
    });
  }

  void _save() {
    _visibleIds.add(MainTabController.dashboardTabId);
    Navigator.of(context).pop(
      _BottomTabEditResult(
        order: _order,
        visibleIds: _visibleIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height * 0.78;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  Text(
                    '하단 탭 편집',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('기본값'),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('완료'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _order.length,
                onReorder: _reorder,
                itemBuilder: (context, index) {
                  final id = _order[index];
                  final tab = _tabById(id);
                  final fixed = id == MainTabController.dashboardTabId;
                  final visible = _visibleIds.contains(id);

                  return ListTile(
                    key: ValueKey('bottom-tab-editor-$id'),
                    leading: Icon(tab.icon, color: scheme.primary),
                    title: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: fixed ? const Text('항상 표시') : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: visible,
                          onChanged: fixed
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value) {
                                      _visibleIds.add(id);
                                    } else {
                                      _visibleIds.remove(id);
                                    }
                                  });
                                },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle_rounded),
                        ),
                      ],
                    ),
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

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _navigatorKeys = <String, GlobalKey<NavigatorState>>{};
  final _bottomScrollController = ScrollController();
  late final List<_BottomTabSpec> _allTabs;
  late List<String> _tabOrder;
  Set<String> _visibleTabIds = {};
  final Set<String> _builtTabIds = {MainTabController.dashboardTabId};
  late final Future<Object?> Function(
    String routeName, {
    Object? arguments,
    int tabIndex,
  }) _shellRouteOpener;
  MainTabController? _tabController;

  @override
  void initState() {
    super.initState();
    _allTabs = _buildAllTabs();
    _tabOrder = _allTabs.map((tab) => tab.id).toList(growable: false);
    _visibleTabIds = _tabOrder.toSet();
    _shellRouteOpener = _openShellRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBottomTabs());
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
    _bottomScrollController.dispose();
    super.dispose();
  }

  List<_BottomTabSpec> _buildAllTabs() {
    return const [
      _BottomTabSpec(
        id: MainTabController.dashboardTabId,
        label: '대시보드',
        icon: Icons.dashboard,
      ),
      _BottomTabSpec(
        id: 'fantasyDashboard',
        label: '작업실',
        icon: Icons.castle_rounded,
      ),
      _BottomTabSpec(id: 'orders', label: '주문', icon: Icons.receipt_long),
      _BottomTabSpec(
        id: _playAutoTabId,
        label: '플토',
        icon: Icons.fact_check_outlined,
      ),
      _BottomTabSpec(id: 'stock', label: '재고', icon: Icons.inventory_2),
      _BottomTabSpec(id: 'txns', label: '입출고기록', icon: Icons.swap_vert),
      _BottomTabSpec(id: 'works', label: '작업', icon: Icons.handyman),
      _BottomTabSpec(id: 'purchases', label: '발주', icon: Icons.local_shipping),
      _BottomTabSpec(
        id: 'quotes',
        label: '견적',
        icon: Icons.request_quote_outlined,
      ),
      _BottomTabSpec(id: 'settings', label: '설정', icon: Icons.settings),
      _BottomTabSpec(id: 'suppliers', label: '거래처', icon: Icons.business),
      _BottomTabSpec(
        id: 'shippingDestinations',
        label: '배송지',
        icon: Icons.local_shipping_outlined,
      ),
      _BottomTabSpec(
        id: 'storageLocations',
        label: '보관위치',
        icon: Icons.location_on_outlined,
      ),
      _BottomTabSpec(id: 'receipts', label: '영수증', icon: Icons.receipt_long),
      _BottomTabSpec(id: 'trash', label: '휴지통', icon: Icons.delete_outline),
      _BottomTabSpec(id: 'shortage', label: '부족분', icon: Icons.rule_folder),
      _BottomTabSpec(id: 'memo', label: '메모', icon: Icons.note_alt_outlined),
      _BottomTabSpec(id: 'schedules', label: '일정', icon: Icons.event_note),
      _BottomTabSpec(id: 'fabricCutting', label: '재단', icon: Icons.content_cut),
    ];
  }

  GlobalKey<NavigatorState> _keyOfTab(String id) {
    return _navigatorKeys.putIfAbsent(id, GlobalKey<NavigatorState>.new);
  }

  List<_BottomTabSpec> get _visibleTabs {
    final byId = {for (final tab in _allTabs) tab.id: tab};
    final result = <_BottomTabSpec>[];
    for (final id in _tabOrder) {
      final tab = byId[id];
      if (tab != null && _visibleTabIds.contains(id)) result.add(tab);
    }
    if (!result.any((tab) => tab.id == MainTabController.dashboardTabId)) {
      result.insert(0, byId[MainTabController.dashboardTabId]!);
    }
    return result;
  }

  Future<void> _loadBottomTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_bottomTabOrderPrefsKey);
      final hidden = prefs.getStringList(_bottomTabHiddenPrefsKey) ?? const [];
      if (!mounted) return;

      setState(() {
        _tabOrder = _mergeTabOrder(savedOrder);
        final normalizedHidden = _normalizeHiddenTabIds(hidden);
        _visibleTabIds = _allTabs
            .where((tab) => !normalizedHidden.contains(tab.id))
            .map((tab) => tab.id)
            .toSet();
        _visibleTabIds.add(MainTabController.dashboardTabId);
      });
      await _persistBottomTabs();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tabOrder = _allTabs.map((tab) => tab.id).toList(growable: false);
        _visibleTabIds = _tabOrder.toSet();
      });
    }
  }

  List<String> _mergeTabOrder(List<String>? savedIds) {
    final allIds = _allTabs.map((tab) => tab.id).toList(growable: false);
    final seen = <String>{};
    final merged = <String>[];
    for (final id in savedIds ?? const <String>[]) {
      final normalizedId = _normalizeTabId(id);
      if (allIds.contains(normalizedId) && seen.add(normalizedId)) {
        merged.add(normalizedId);
      }
    }
    for (final id in allIds) {
      if (seen.add(id)) merged.add(id);
    }
    return merged;
  }

  String _normalizeTabId(String id) {
    return switch (id) {
      'playautoOrders' || 'playautoFulfillment' => _playAutoTabId,
      _ => id,
    };
  }

  Set<String> _normalizeHiddenTabIds(List<String> hiddenIds) {
    final hidden = hiddenIds.toSet();
    final normalized = hidden.map(_normalizeTabId).toSet();
    final hidOnlyOneLegacyPlayAuto = hidden.contains('playautoOrders') !=
        hidden.contains('playautoFulfillment');
    if (hidOnlyOneLegacyPlayAuto && !hidden.contains(_playAutoTabId)) {
      normalized.remove(_playAutoTabId);
    }
    return normalized;
  }

  Future<void> _persistBottomTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bottomTabOrderPrefsKey, _tabOrder);
      await prefs.setStringList(
        _bottomTabHiddenPrefsKey,
        _allTabs
            .where((tab) => !_visibleTabIds.contains(tab.id))
            .map((tab) => tab.id)
            .toList(growable: false),
      );
    } catch (_) {
      // 탭 설정 저장 실패가 앱 이동을 막지는 않는다.
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

  String _tabIdForLegacyIndex(int index) {
    switch (index) {
      case 1:
        return 'orders';
      case 2:
        return 'stock';
      case 3:
        return 'txns';
      case 4:
        return 'works';
      case 5:
        return 'purchases';
      default:
        return MainTabController.dashboardTabId;
    }
  }

  Future<Object?> _openShellRoute(
    String routeName, {
    Object? arguments,
    int tabIndex = 0,
  }) async {
    final tabId = _tabIdForLegacyIndex(tabIndex);
    _builtTabIds.add(tabId);
    context.read<MainTabController>().setTabId(tabId);
    final nav = _keyOfTab(tabId).currentState;
    if (nav == null) return null;
    nav.popUntil((route) => route.isFirst);
    if (routeName == Navigator.defaultRouteName || routeName == '/') {
      return null;
    }
    return nav.pushNamed(routeName, arguments: arguments);
  }

  void _selectTab(String id) {
    final controller = context.read<MainTabController>();
    setState(() => _builtTabIds.add(id));
    controller.setTabId(id);
    _keyOfTab(id).currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> _showBottomTabEditor() async {
    final result = await showModalBottomSheet<_BottomTabEditResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _BottomTabEditorSheet(
        allTabs: _allTabs,
        order: _tabOrder,
        visibleIds: _visibleTabIds,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _tabOrder = result.order;
      _visibleTabIds = result.visibleIds;
      _visibleTabIds.add(MainTabController.dashboardTabId);
    });

    final selectedId = context.read<MainTabController>().tabId;
    if (!_visibleTabIds.contains(selectedId)) {
      context
          .read<MainTabController>()
          .setTabId(MainTabController.dashboardTabId);
    }
    await _persistBottomTabs();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MainTabController>();
    final tabs = [..._visibleTabs];
    var selectedId = ctrl.tabId;
    if (!tabs.any((tab) => tab.id == selectedId)) {
      final selectedHiddenTab = _allTabs.where((tab) => tab.id == selectedId);
      if (selectedHiddenTab.isEmpty) {
        selectedId = MainTabController.dashboardTabId;
      } else {
        tabs.add(selectedHiddenTab.first);
      }
    }
    _builtTabIds.add(selectedId);
    final stackTabs = _allTabs
        .where((tab) => _builtTabIds.contains(tab.id))
        .toList(growable: false);
    final selectedIndex = stackTabs.indexWhere((tab) => tab.id == selectedId);

    // ignore: deprecated_member_use
    return WillPopScope(
      // 내부 스택이 남아있으면 pop만 하고 앱은 안나가도록
      onWillPop: () async {
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          Navigator.of(context).pop();
          return false;
        }

        final key = _keyOfTab(selectedId);
        if (key.currentState?.canPop() == true) {
          key.currentState!.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: selectedIndex < 0 ? 0 : selectedIndex,
          children: [
            for (final tab in stackTabs) _buildTabNavigator(context, tab.id),
          ],
        ),
        bottomNavigationBar: _ScrollableBottomTabs(
          tabs: tabs,
          selectedId: selectedId,
          scrollController: _bottomScrollController,
          onSelect: (id) {
            if (id == MainTabController.dashboardTabId &&
                selectedId == MainTabController.dashboardTabId) {
              _openDashboardQuickPanel();
              return;
            }
            _selectTab(id);
          },
          onEdit: _showBottomTabEditor,
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
  Widget _buildTabNavigator(BuildContext context, String tabId) {
    if (tabId == MainTabController.dashboardTabId) {
      return _buildDashboardNav();
    }

    return Navigator(
      key: _keyOfTab(tabId),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => _screenForTabRoute(context, tabId, settings),
        settings: settings,
      ),
    );
  }

  Widget _screenForTabRoute(
    BuildContext context,
    String tabId,
    RouteSettings settings,
  ) {
    if (tabId == 'stock' && settings.name == '/stock/path') {
      return StockBrowserScreen(
        initialPath: (settings.arguments as List).cast<String>(),
      );
    }
    if (tabId == 'stock' && settings.name == '/items/detail') {
      return StockItemDetailScreen(itemId: settings.arguments as String);
    }
    if (tabId == 'orders' && settings.name == '/orders/detail') {
      return OrderDetailScreen(orderId: settings.arguments as String);
    }
    if (tabId == 'purchases' && settings.name == '/detail') {
      final orderId = settings.arguments as String;
      return PurchaseDetailScreen(
        repo: context.read<PurchaseOrderRepo>(),
        orderId: orderId,
      );
    }
    if (tabId == 'quotes' && settings.name == '/quotes/detail') {
      return QuoteDetailScreen(quoteId: settings.arguments as String);
    }
    return _rootScreenForTab(context, tabId);
  }

  Widget _rootScreenForTab(BuildContext context, String tabId) {
    switch (tabId) {
      case 'orders':
        return const OrderListScreen();
      case 'fantasyDashboard':
        return const FantasyDashboardScreen();
      case _playAutoTabId:
        return const PlayAutoOrderImportScreen();
      case 'stock':
        return const StockBrowserScreen();
      case 'txns':
        return const TxnListScreen();
      case 'works':
        return const WorkListScreen();
      case 'purchases':
        return const PurchaseListScreen();
      case 'quotes':
        return const QuoteListScreen();
      case 'settings':
        return const SettingsScreen();
      case 'suppliers':
        return const SupplierListScreen();
      case 'shippingDestinations':
        return const ShippingDestinationScreen();
      case 'storageLocations':
        return const StorageLocationScreen();
      case 'receipts':
        return const ReceiptsHomeScreen();
      case 'trash':
        return const TrashScreen();
      case 'shortage':
        return const ShortageCalcScreen();
      case 'memo':
        return const MemoScreen();
      case 'schedules':
        return const ScheduleListScreen();
      case 'fabricCutting':
        return const FabricCuttingHomeScreen();
      default:
        return const DashboardScreen();
    }
  }

  Widget _buildDashboardNav() {
    return Navigator(
      key: _keyOfTab(MainTabController.dashboardTabId),
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
          case '/settings/shipping-destinations':
            screen = const ShippingDestinationScreen();
            break;
          case '/settings/storage-locations':
            screen = const StorageLocationScreen();
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
          case '/schedules':
            screen = const ScheduleListScreen();
            break;
          case '/fabric-cutting':
            screen = const FabricCuttingHomeScreen();
            break;
          case '/playauto-test':
            screen = const PlayAutoOrderImportScreen();
            break;
          case '/cart':
            screen = const CartScreen();
            break;
          case '/quotes':
            screen = const QuoteListScreen();
            break;
          case '/quotes/detail':
            screen = QuoteDetailScreen(quoteId: settings.arguments as String);
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
}
