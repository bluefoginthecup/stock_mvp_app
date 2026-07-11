import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/app.dart';

import 'src/repos/repo_interfaces.dart';
import 'src/services/dashboard_activity_service.dart';
import 'src/services/inventory_service.dart';
import 'src/ui/nav/item_detail_opener.dart';
import 'src/providers/cart_manager.dart';
import 'src/models/purchase_order.dart';
import 'src/utils/item_presentation.dart';

// 탭/선택 컨트롤러
import 'src/app/main_tab_controller.dart';

// Auth (있으면)
import 'src/services/auth_service.dart';
import 'src/services/reorder_reminder_service.dart';

// Drift + SQLite
import 'src/db/app_database.dart';
import 'src/repos/drift_unified_repo.dart';
import 'src/models/txn.dart';
import 'src/repos/timeline_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await ReorderReminderService.initialize();

  // ✅ Provider 타입 체크 완화 (기존 main.dart와 동일)
  Provider.debugCheckInvalidValueType = null;

  // DB & Repo
  final db = AppDatabase();
  final unifiedRepo = DriftUnifiedRepo(db);

  // BOM 캐시 예열 (main.dart와 동일)
  Future.microtask(() => unifiedRepo.refreshBomSnapshot());

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => const Uuid()),
        Provider<AppDatabase>.value(value: db),

        // DriftUnifiedRepo (Listenable)
        ChangeNotifierProvider<DriftUnifiedRepo>.value(value: unifiedRepo),

        // 인터페이스 alias 바인딩
        Provider<ItemRepo>.value(value: unifiedRepo),
        Provider<TxnRepo>.value(value: unifiedRepo),
        Provider<BomRepo>.value(value: unifiedRepo),
        Provider<OrderRepo>.value(value: unifiedRepo),
        Provider<WorkRepo>.value(value: unifiedRepo),
        Provider<PurchaseOrderRepo>.value(value: unifiedRepo),
        Provider<ScheduleRepo>.value(value: unifiedRepo),
        Provider<SupplierRepo>.value(value: unifiedRepo),
        Provider<ShippingDestinationRepo>.value(value: unifiedRepo),
        Provider<StorageLocationRepo>.value(value: unifiedRepo),
        Provider<FolderTreeRepo>.value(value: unifiedRepo),
        Provider<TrashRepo>.value(value: unifiedRepo),
        Provider<DashboardActivityService>(
          create: (ctx) => DashboardActivityService(ctx.read<AppDatabase>()),
        ),

        // 타임라인 리포 (기존 main.dart와 동일한 팩토리)
        Provider<TimelineRepo>(
          create: (_) => TimelineRepo(
            getOrderById: (id) async {
              final o = await unifiedRepo.getOrder(id);
              if (o == null) throw Exception('Order not found: $id');
              return o;
            },
            listPOsByOrderId: (id) =>
                unifiedRepo.listPurchaseOrdersByOrderId(id),
            listWorksByOrderId: (id) => unifiedRepo.listWorksByOrderId(id),
          ),
        ),

        // 스트림 프로바이더들
        StreamProvider<List<Txn>>(
          create: (ctx) => unifiedRepo.watchTxns(),
          initialData: const [],
        ),
        StreamProvider<List<PurchaseOrder>>(
          create: (ctx) =>
              ctx.read<PurchaseOrderRepo>().watchAllPurchaseOrders(),
          initialData: const [],
        ),

        // 컨트롤러들
        ChangeNotifierProvider(create: (_) => CartManager()),
        ChangeNotifierProvider(create: (_) => MainTabController()),

        // 유틸/서비스
        Provider<ItemDetailOpener>(create: (_) => AppItemDetailOpener()),
        Provider<ItemPathProvider>(
            create: (ctx) => RepoItemPathFacade(ctx.read<ItemRepo>())),
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
      ],
      // ⛳️ 모바일과 동일하게 StockApp을 그대로 사용 (MaterialApp 포함)
      child: const StockApp(),
    ),
  );
}
