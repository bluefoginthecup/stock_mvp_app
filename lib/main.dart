import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:firebase_core/firebase_core.dart'; // ✅ 추가

import 'src/app.dart';

import 'src/repos/repo_interfaces.dart';
import 'src/services/inventory_service.dart';
import 'src/utils/item_presentation.dart';

import 'src/ui/nav/item_detail_opener.dart';
import 'src/services/seed_importer.dart';
import 'src/providers/cart_manager.dart';
import 'src/models/purchase_order.dart';

// 탭/선택 컨트롤러
import 'src/app/main_tab_controller.dart';
import 'src/screens/stock/widgets/item_selection_controller.dart';

// ✅ 추가: Auth & Gate
import 'src/services/auth_service.dart';
import 'src/screens/auth/launch_gate.dart';

// Drift + SQLite
import 'src/db/app_database.dart';
import 'src/repos/drift_unified_repo.dart';  // ✅ 새 통합 Repo

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ⬇⬇⬇ 요 줄 추가 (Provider 경고 끄기)
  Provider.debugCheckInvalidValueType = null;

  // 1) Drift DB 인스턴스
  final db = AppDatabase();

  // 2) 통합 Drift Repo (Item / Txn / Order / Work / Purchase / Supplier / Paths 모두 포함)
  final unifiedRepo = DriftUnifiedRepo(db);

  // 3) SeedImporter: 이제 DriftUnifiedRepo에 바로 주입
  final importer = UnifiedSeedImporter(
    itemRepo: unifiedRepo,
    bomRepo: unifiedRepo,
    // 필요하다면 txns: unifiedRepo, orders: unifiedRepo ... 이런 식으로도 확장 가능
    verbose: true,
  );

  await importer.importUnifiedFromAssets(
    itemsAssetPath: 'assets/seeds/2025-10-26/items.json',
    foldersAssetPath: 'assets/seeds/2025-10-26/folders.json',
    bomAssetPath: 'assets/seeds/2025-10-26/bom.json',
    lotsAssetPath: 'assets/seeds/2025-10-26/lots.json',
    clearBefore: true,
  );

  print('[main] DriftUnifiedRepo instance = ${identityHashCode(unifiedRepo)}');
  await unifiedRepo.debugPrintAllFolders();

  runApp(
    MultiProvider(
      providers: [
        // ✅ AuthService 전역 주입
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => const Uuid()),

        // DB 인스턴스
        Provider<AppDatabase>.value(value: db),

        // ✅ DriftUnifiedRepo는 ChangeNotifierProvider로 한 번 올려두고
        ChangeNotifierProvider<DriftUnifiedRepo>.value(
          value: unifiedRepo,
        ),

        // ✅ 인터페이스별 Provider 다시 살리기 (전부 unifiedRepo를 가리킴)
        Provider<ItemRepo>.value(value: unifiedRepo),
        Provider<TxnRepo>.value(value: unifiedRepo),
        Provider<BomRepo>.value(value: unifiedRepo),
        Provider<OrderRepo>.value(value: unifiedRepo),
        Provider<WorkRepo>.value(value: unifiedRepo),
        Provider<PurchaseOrderRepo>.value(value: unifiedRepo),
        Provider<SupplierRepo>.value(value: unifiedRepo),
        Provider<FolderTreeRepo>.value(value: unifiedRepo),

        ChangeNotifierProvider(create: (_) => CartManager()),
        ChangeNotifierProvider(create: (_) => MainTabController()),
        ChangeNotifierProvider<ItemSelectionController>(
          create: (_) => ItemSelectionController(),
        ),

        // ✅ 발주 목록 스트림
        StreamProvider<List<PurchaseOrder>>(
          create: (ctx) =>
              ctx.read<PurchaseOrderRepo>().watchAllPurchaseOrders(),
          initialData: const [],
        ),

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
          ),
        ),
      ],
      // ⛳️ 여기만 바뀜: 로그인 게이트로 감싼 뒤, 로그인 완료되면 StockApp 진입
      child: LaunchGate(
        signedInBuilder: (_) => const StockApp(),
      ),
    ),
  );
}
