import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'src/app.dart';
import 'src/repos/inmem_repo.dart';
import 'src/repos/repo_interfaces.dart';
import 'src/repos/repo_views.dart';
import 'src/services/inventory_service.dart';
import 'src/utils/item_presentation.dart';

import 'src/ui/nav/item_detail_opener.dart';
import 'src/services/seed_importer.dart';
import 'src/providers/cart_manager.dart';
import 'src/models/purchase_order.dart'; // ⬅️ 유지

// ⬇️⬇️ 추가: 탭 내비 컨트롤러 & 스크린
import 'src/app/main_tab_controller.dart';
import 'src/screens/stock/widgets/item_selection_controller.dart';

// ⬇️⬇️ Drift + SQLite 추가
import 'src/db/app_database.dart';
import 'src/repos/sqlite_item_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ rootBundle 사용 시 필수

  // 1) SQLite DB 인스턴스
  final db = AppDatabase();

  // 2) InMemoryRepo: 여전히 BOM/Txn/Work/발주/Supplier 저장용으로 사용
  final inmem = InMemoryRepo();

  // 3) Drift 기반 ItemRepo (BOM 관련은 inmem에 위임할 수 있게 옵션으로 넘김)
  final itemRepo = SqliteItemRepo(db, bomDelegate: inmem);

  // ✅ 새 임포터 시그니처에 맞춤
  //    - Item는 SQLite(DB)에 저장
  //    - BOM은 InMemoryRepo에 저장
  final importer = UnifiedSeedImporter(
    itemRepo: inmem,
    bomRepo: inmem,
    verbose: true,    // 👈 디버그 로그 ON
  );

  // ✅ 개별 파일 경로를 named 인자로 전달
  await importer.importUnifiedFromAssets(
    itemsAssetPath: 'assets/seeds/2025-10-26/items.json',
    foldersAssetPath: 'assets/seeds/2025-10-26/folders.json',
    bomAssetPath: 'assets/seeds/2025-10-26/bom.json',
    lotsAssetPath: 'assets/seeds/2025-10-26/lots.json',
    clearBefore: true,
  );

  print('[main] InMemoryRepo instance = ${identityHashCode(inmem)}');

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => const Uuid()),

        // 1) DB 주입
        Provider<AppDatabase>.value(value: db),

        // 2) InMemoryRepo는 여전히 ChangeNotifier (BOM/Txn/Work 등)
        ChangeNotifierProvider<InMemoryRepo>.value(value: inmem),
        ChangeNotifierProvider(create: (_) => CartManager()),

        // 하단 탭 상태 전용 컨트롤러
        ChangeNotifierProvider(create: (_) => MainTabController()),
        ChangeNotifierProvider<ItemSelectionController>(
          create: (_) => ItemSelectionController(),
        ),

        // TxnRepo 타입으로도 '같은 inmem 인스턴스'를 노출 (타입 바인딩용)
        Provider<TxnRepo>(
          create: (ctx) => TxnRepoView(ctx.read<InMemoryRepo>()),
        ),

        // 🔥 ItemRepo는 이제 Drift + SQLite 버전으로 교체
        Provider<ItemRepo>.value(value: itemRepo),

        // 나머지는 그대로 InMemoryRepo 래핑
        Provider<OrderRepo>(
          create: (ctx) => OrderRepoView(ctx.read<InMemoryRepo>()),
        ),
        Provider<BomRepo>(
          create: (ctx) => BomRepoView(ctx.read<InMemoryRepo>()),
        ),
        Provider<WorkRepo>(
          create: (ctx) => WorkRepoView(ctx.read<InMemoryRepo>()),
        ),

        // 1) Repo 파사드(비-Listenable) 주입
        Provider<PurchaseOrderRepo>(
          create: (ctx) => PurchaseRepoView(ctx.read<InMemoryRepo>()),
        ),

        // 2) 목록 갱신은 StreamProvider로 구독
        StreamProvider<List<PurchaseOrder>>(
          create: (ctx) => ctx.read<PurchaseOrderRepo>().watchAllPurchaseOrders(),
          initialData: const [],
        ),

        Provider<ItemDetailOpener>(create: (_) => AppItemDetailOpener()),

        // ItemPathProvider는 "비-Listenable 파사드"로 주입
        Provider<ItemPathProvider>(
          create: (ctx) => RepoItemPathFacade(ctx.read<InMemoryRepo>()),
        ),

        // ✅ SupplierRepo 주입: 비-Listenable 파사드로 감싸서 제공
        Provider<SupplierRepo>(
          create: (ctx) => SupplierRepoView(ctx.read<InMemoryRepo>()),
        ),

        // ✅ InventoryService 주입
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
      child: const StockApp(),
    ),
  );
}
