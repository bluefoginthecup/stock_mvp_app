import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/app/main_tab_screen.dart';
import 'models/purchase_order.dart';
import 'models/txn.dart';
import 'providers/cart_manager.dart';
import 'screens/orders/order_list_screen.dart';
import 'screens/stock/stock_browser_screen.dart';
import 'screens/txns/txn_list_screen.dart';
import 'screens/works/work_list_screen.dart';
import 'screens/purchases/purchase_list_screen.dart';
import 'screens/quotes/quote_list_screen.dart';
import 'screens/trash/trash_screen.dart';
import 'screens/cart/cart_screen.dart';
import '/src/screens/settings/settings_screen.dart';
import '/src/screens/settings/cloud_backup_list_screen.dart';
import '/src/screens/settings/shipping_destination_screen.dart';
import '/src/screens/settings/storage_location_screen.dart';
import 'screens/orders/order_detail_screen.dart';

// 다국어 앱 셋팅
import '/src/l10n/l10n.dart';
import '/src/ui/common/ui.dart';
import 'app/lang_controller.dart';
import '/src/screens/settings/language_settings_screen.dart';

import 'screens/stock/stock_item_detail_screen.dart';
import 'screens/purchases/purchase_detail_screen.dart';
import 'screens/quotes/quote_detail_screen.dart';
import 'screens/suppliers/supplier_form_screen.dart';
import 'screens/suppliers/supplier_list_screen.dart';
import 'screens/receipts/receipt_create_screen.dart';
import 'screens/receipts/receipts_home_screen.dart';
import 'screens/schedules/schedule_list_screen.dart';
import 'screens/schedules/schedule_edit_screen.dart';
import 'features/fabric_cutting/screens/fabric_cutting_home_screen.dart';

import 'app/main_tab_controller.dart';
import 'repos/repo_interfaces.dart';
import 'repos/drift_unified_repo.dart';
import 'services/app_path_service.dart';
import 'services/auth_service.dart';
import 'services/bom_service.dart';
import 'services/dashboard_activity_service.dart';
import 'services/db_auto_backup_service.dart';
import 'services/export_service.dart';
import 'services/folder_service.dart';
import 'services/inventory_service.dart';
import 'services/shortage_service.dart';
import 'services/schedule_widget_bridge.dart';
import 'services/system_seed_service.dart';
import 'db/app_database.dart';
import 'repos/timeline_repo.dart';
import 'ui/common/selection/item_selection_controller.dart';
import 'ui/intro_loading_screen.dart';
import 'ui/nav/item_detail_opener.dart';
import 'utils/item_presentation.dart';

// ✅ 추가: 로그인 게이트
import 'screens/auth/launch_gate.dart';

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LangController()..load(),
      child: Builder(
        builder: (context) {
          final GlobalKey<NavigatorState> rootNavKey =
              GlobalKey<NavigatorState>();
          final GlobalKey<ScaffoldMessengerState> messengerKey =
              GlobalKey<ScaffoldMessengerState>();
          final lang = context.watch<LangController>();

          return StreamBuilder(
            stream: context.read<AuthService>().userStream,
            initialData: context.read<AuthService>().currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data;
              final app = _StockMaterialApp(
                rootNavKey: rootNavKey,
                messengerKey: messengerKey,
                locale: lang.locale,
              );

              if (user == null) return app;

              return _AccountDataScope(
                key: ValueKey(user.uid),
                uid: user.uid,
                child: app,
              );
            },
          );
        },
      ),
    );
  }
}

class _StockMaterialApp extends StatefulWidget {
  final GlobalKey<NavigatorState> rootNavKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Locale? locale;

  const _StockMaterialApp({
    required this.rootNavKey,
    required this.messengerKey,
    required this.locale,
  });

  @override
  State<_StockMaterialApp> createState() => _StockMaterialAppState();
}

class _StockMaterialAppState extends State<_StockMaterialApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScheduleWidgetBridge.initialize(navigatorKey: widget.rootNavKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.rootNavKey,
      scaffoldMessengerKey: widget.messengerKey,
      locale: widget.locale,
      onGenerateTitle: (ctx) => L10n.of(ctx).app_title,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('es'),
      ],
      theme: ThemeData(/* ... */),
      home: LaunchGate(
        signedInBuilder: (_) => const MainTabScreen(),
      ),
      routes: {
        '/orders': (_) => const OrderListScreen(),
        '/stock': (_) => const StockBrowserScreen(),
        '/txns': (_) => const TxnListScreen(),
        '/works': (_) => const WorkListScreen(),
        '/purchases': (_) => const PurchaseListScreen(),
        '/quotes': (_) => const QuoteListScreen(),
        '/settings/language': (_) => const LanguageSettingsScreen(),
        '/items/detail': (context) {
          final itemId = ModalRoute.of(context)!.settings.arguments as String;
          return StockItemDetailScreen(itemId: itemId);
        },
        '/purchases/detail': (context) {
          debugPrint('[Route] /purchases/detail builder called');
          final orderId = ModalRoute.of(context)!.settings.arguments as String;
          final poRepo = context.read<PurchaseOrderRepo>();
          return PurchaseDetailScreen(orderId: orderId, repo: poRepo);
        },
        '/quotes/detail': (context) {
          final quoteId = ModalRoute.of(context)!.settings.arguments as String;
          return QuoteDetailScreen(quoteId: quoteId);
        },
        '/trash': (_) => const TrashScreen(),
        '/cart': (_) => const CartScreen(),
        '/orders/detail': (context) {
          final orderId = ModalRoute.of(context)!.settings.arguments as String;
          return OrderDetailScreen(orderId: orderId);
        },
        '/settings': (_) => const SettingsScreen(),
        '/settings/cloud-backups': (_) => const CloudBackupListScreen(),
        '/settings/shipping-destinations': (_) =>
            const ShippingDestinationScreen(),
        '/settings/storage-locations': (_) => const StorageLocationScreen(),
        '/suppliers/new': (context) => const SupplierFormScreen(),
        '/suppliers/edit': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return SupplierFormScreen(supplierId: id);
        },
        '/suppliers': (_) => const SupplierListScreen(),
        '/receipts': (_) => const ReceiptsHomeScreen(),
        '/receipts/new': (_) => const ReceiptCreateScreen(),
        '/schedules': (_) => const ScheduleListScreen(),
        '/schedules/new': (_) => const ScheduleEditScreen(),
        '/fabric-cutting': (_) => const FabricCuttingHomeScreen(),
      },
    );
  }
}

class _AccountDataScope extends StatefulWidget {
  final String uid;
  final Widget child;

  const _AccountDataScope({
    super.key,
    required this.uid,
    required this.child,
  });

  @override
  State<_AccountDataScope> createState() => _AccountDataScopeState();
}

class _AccountDataScopeState extends State<_AccountDataScope> {
  late final Future<_AccountData> _future;

  @override
  void initState() {
    super.initState();
    _future = _openAccountData();
  }

  Future<_AccountData> _openAccountData() async {
    final startedAt = DateTime.now();
    AppPathService.setActiveUserId(widget.uid);
    await DbAutoBackupService.createPreMigrationBackup();

    final db = AppDatabase();
    debugPrint('DB schemaVersion: ${db.schemaVersion}');
    debugPrint(
        'DB path: ${(await const AppPathService().stockDatabaseFile()).path}');

    await DbAutoBackupService.run();

    final repo = DriftUnifiedRepo(db);
    await SystemSeedService.ensure(db);
    Future.microtask(() => repo.refreshBomSnapshot());

    final elapsed = DateTime.now().difference(startedAt);
    const minIntroDuration = Duration(milliseconds: 1500);
    if (elapsed < minIntroDuration) {
      await Future<void>.delayed(minIntroDuration - elapsed);
    }

    return _AccountData(db: db, repo: repo);
  }

  @override
  void dispose() {
    AppDatabase.closeInstance();
    AppPathService.setActiveUserId(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AccountData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: IntroLoadingScreen(),
          );
        }

        final data = snapshot.data!;
        final repo = data.repo;

        return MultiProvider(
          providers: [
            Provider<AppDatabase>.value(value: data.db),
            ChangeNotifierProvider<DriftUnifiedRepo>.value(value: repo),
            Provider<ItemRepo>.value(value: repo),
            Provider<TxnRepo>.value(value: repo),
            Provider<BomRepo>.value(value: repo),
            Provider<OrderRepo>.value(value: repo),
            Provider<WorkRepo>.value(value: repo),
            Provider<PurchaseOrderRepo>.value(value: repo),
            Provider<QuoteRepo>.value(value: repo),
            Provider<ScheduleRepo>.value(value: repo),
            Provider<SupplierRepo>.value(value: repo),
            Provider<ShippingDestinationRepo>.value(value: repo),
            Provider<StorageLocationRepo>.value(value: repo),
            Provider<FolderTreeRepo>.value(value: repo),
            Provider<TrashRepo>.value(value: repo),
            Provider<ExportService>(
              create: (ctx) => ExportService(
                itemRepo: ctx.read<ItemRepo>(),
                folderRepo: ctx.read<FolderTreeRepo>(),
              ),
            ),
            Provider<FolderService>(
              create: (context) =>
                  FolderService(context.read<DriftUnifiedRepo>()),
            ),
            Provider<DashboardActivityService>(
              create: (context) =>
                  DashboardActivityService(context.read<AppDatabase>()),
            ),
            Provider<TimelineRepo>(
              create: (_) => TimelineRepo(
                getOrderById: (id) async {
                  final order = await repo.getOrder(id);
                  if (order == null) throw Exception('Order not found: $id');
                  return order;
                },
                listPOsByOrderId: (id) => repo.listPurchaseOrdersByOrderId(id),
                listWorksByOrderId: (id) => repo.listWorksByOrderId(id),
              ),
            ),
            StreamProvider<List<Txn>>(
              create: (ctx) => repo.watchTxns(),
              initialData: const [],
            ),
            StreamProvider<List<PurchaseOrder>>(
              create: (ctx) =>
                  ctx.read<PurchaseOrderRepo>().watchAllPurchaseOrders(),
              initialData: const [],
            ),
            ChangeNotifierProvider(create: (_) => CartManager()),
            ChangeNotifierProvider(create: (_) => MainTabController()),
            ChangeNotifierProvider(create: (_) => ItemSelectionController()),
            Provider<ItemDetailOpener>(create: (_) => AppItemDetailOpener()),
            Provider<ItemPathProvider>(
              create: (ctx) => RepoItemPathFacade(ctx.read<ItemRepo>()),
            ),
            Provider<InventoryService>(
              create: (ctx) => InventoryService(
                works: ctx.read<WorkRepo>(),
                purchases: ctx.read<PurchaseOrderRepo>(),
                txns: ctx.read<TxnRepo>(),
                boms: ctx.read<BomRepo>(),
                orders: ctx.read<OrderRepo>(),
                items: ctx.read<ItemRepo>(),
              ),
            ),
            Provider<BomService>(
              create: (ctx) => BomService(ctx.read<ItemRepo>()),
            ),
            Provider<ShortageService>(
              create: (ctx) => ShortageService(
                repo: ctx.read<ItemRepo>(),
                bom: ctx.read<BomService>(),
              ),
            ),
          ],
          child: ScheduleWidgetSync(
            repo: repo,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _AccountData {
  final AppDatabase db;
  final DriftUnifiedRepo repo;

  const _AccountData({
    required this.db,
    required this.repo,
  });
}
