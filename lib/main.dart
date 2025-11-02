import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'src/app.dart';
import 'src/repos/inmem_repo.dart';
import 'src/repos/repo_interfaces.dart';
import 'src/repos/repo_views.dart';
import 'src/services/inventory_service.dart';
import 'src/utils/item_presentation.dart';

// ▼ 기존 로더가 더 이상 필요 없다면 주석/삭제
// import 'src/repos/inmem_seed_importer.dart';

import 'src/ui/nav/item_detail_opener.dart';
import 'src/services/seed_importer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ rootBundle 사용 시 필수

  final inmem = InMemoryRepo();

  // ✅ 새 임포터 시그니처에 맞춤 (InMemoryRepo가 ItemRepo & BomRepo를 모두 구현)
  final importer = UnifiedSeedImporter(
    itemRepo: inmem,
    bomRepo: null, // 만약 BomRepo를 구현하지 않으면 null로 두세요.
    verbose: true,    // 👈 디버그 로그 ON
  );

  // ✅ 개별 파일 경로를 named 인자로 전달
  await importer.importUnifiedFromAssets(
    itemsAssetPath: 'assets/seeds/2025-10-26/items.json',
    foldersAssetPath: 'assets/seeds/2025-10-26/folders.json',
    // bomAssetPath: 'assets/seeds/2025-10-26/bom.json',
    clearBefore: true,
  );

  print('[main] InMemoryRepo instance = ${identityHashCode(inmem)}');

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => const Uuid()),

        // 변경 통지자는 단 하나: InMemoryRepo (ChangeNotifier)
        ChangeNotifierProvider<InMemoryRepo>.value(value: inmem),

        // 화면엔 인터페이스(비-Listenable)로 주입 → Provider OK
        Provider<ItemRepo>(create: (ctx) => ItemRepoView(ctx.read<InMemoryRepo>())),
        Provider<OrderRepo>(create: (ctx) => OrderRepoView(ctx.read<InMemoryRepo>())),
        Provider<TxnRepo>(create: (ctx) => TxnRepoView(ctx.read<InMemoryRepo>())),
        Provider<BomRepo>(create: (ctx) => BomRepoView(ctx.read<InMemoryRepo>())),
        Provider<WorkRepo>(create: (ctx) => WorkRepoView(ctx.read<InMemoryRepo>())),
        Provider<PurchaseRepo>(create: (ctx) => PurchaseRepoView(ctx.read<InMemoryRepo>())),
        Provider<ItemDetailOpener>(create: (_) => AppItemDetailOpener()),

        // ItemPathProvider는 "비-Listenable 파사드"로 주입
        Provider<ItemPathProvider>(
          create: (ctx) => RepoItemPathFacade(ctx.read<InMemoryRepo>()),
        ),

        // ✅ InventoryService 주입
        Provider<InventoryService>(
          create: (ctx) => InventoryService(
            works: ctx.read<WorkRepo>(),
            purchases: ctx.read<PurchaseRepo>(),
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
