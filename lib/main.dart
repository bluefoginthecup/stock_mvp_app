import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'src/app.dart';
import 'src/repos/inmem_repo.dart';
import 'src/repos/repo_interfaces.dart';
import 'src/repos/repo_views.dart';
import 'src/services/inventory_service.dart';  // ← 추가
import 'src/utils/item_presentation.dart';

import 'src/repos/inmem_seed_importer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ rootBundle 사용 시 필수

  final inmem = InMemoryRepo();
  final loader = InMemorySeedLoader(inmem);
  await loader.loadFromAsset('assets/seeds/initial_seed.json'); // ✅ await OK

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
