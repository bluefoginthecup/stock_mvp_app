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

// Drift + SQLite
import 'src/db/app_database.dart';
import 'src/repos/drift_unified_repo.dart';  // ✅ 새 통합 Repo

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Provider 경고 끄기 (필요 시)
  Provider.debugCheckInvalidValueType = null;

  // DB & Repo
  final db = AppDatabase();

  // 2) 통합 Drift Repo (Item / Txn / Order / Work / Purchase / Supplier / Paths 모두 포함)
  final unifiedRepo = DriftUnifiedRepo(db);

  // 초기 시드 (필요 시)
  final importer = UnifiedSeedImporter(
    itemRepo: unifiedRepo,
    bomRepo: unifiedRepo,
    verbose: true,
  );
  await importer.importUnifiedFromAssets(
    itemsAssetPath: 'assets/seeds/2025-10-26/items.json',
    foldersAssetPath: 'assets/seeds/2025-10-26/folders.json',
    bomAssetPath: 'assets/seeds/2025-10-26/bom.json',
    lotsAssetPath: 'assets/seeds/2025-10-26/lots.json',
    clearBefore: true,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => const Uuid()),
        Provider<AppDatabase>.value(value: db),

        ChangeNotifierProvider<DriftUnifiedRepo>.value(value: unifiedRepo),
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
        ChangeNotifierProvider(create: (_) => ItemSelectionController()),

        StreamProvider<List<PurchaseOrder>>(
          create: (ctx) => ctx.read<PurchaseOrderRepo>().watchAllPurchaseOrders(),
          initialData: const [],
        ),

        Provider<ItemDetailOpener>(create: (_) => AppItemDetailOpener()),
        Provider<ItemPathProvider>(create: (ctx) => RepoItemPathFacade(ctx.read<ItemRepo>())),
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
      // ⛳️ 여기 **무조건** StockApp (MaterialApp 포함)
      child: const StockApp(),
    ),
  );
}
