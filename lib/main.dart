import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'src/app.dart';
import 'src/repos/inmem_repo.dart';
import 'src/repos/repo_interfaces.dart';
import 'src/repos/repo_views.dart';
import 'src/services/inventory_service.dart';
import 'src/utils/item_presentation.dart';

// ⬇️ 초기 시드(루트폴더+JSON 아이템/폴더+레시피BOM) 일괄 실행
import 'src/seeds/initial_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) ChangeNotifier 단일 인스턴스
  final inmem = InMemoryRepo();

  // 2) 같은 View 인스턴스를 시드와 Provider에 **공유**해서 일관성 유지
  final itemRepoView = ItemRepoView(inmem);
  final orderRepoView = OrderRepoView(inmem);
  final txnRepoView   = TxnRepoView(inmem);
  final workRepoView  = WorkRepoView(inmem);
  final purchaseRepoView = PurchaseRepoView(inmem);
  final bomRepoView   = BomRepoView(inmem);
  final pathFacade    = RepoItemPathFacade(inmem);

  // 3) 초기 시드 실행 (폴더 루트 보장 → assets JSON 로드 → 레시피(BOM) 주입)
  //    assetPath는 프로젝트에 맞게 유지
  try {
    await runInitialSeeds(
      inmem: inmem,
      itemRepo: itemRepoView,
      bomRepo: bomRepoView,
      assetPath: 'assets/seeds/initial_seed.json',
    );
  } catch (e) {
    // 에셋이 비어있거나 없더라도 앱은 뜨도록 로그만 남김
    debugPrint('[main] runInitialSeeds skipped: $e');
  }

  debugPrint('[main] InMemoryRepo instance = ${identityHashCode(inmem)}');

  // 4) runApp + Provider 주입
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => const Uuid()),

        // 단일 변경 통지자
        ChangeNotifierProvider<InMemoryRepo>.value(value: inmem),

        // 인터페이스(비-Listenable) 주입 — 위에서 만든 View 인스턴스를 그대로 공유
        Provider<ItemRepo>.value(value: itemRepoView),
        Provider<OrderRepo>.value(value: orderRepoView),
        Provider<TxnRepo>.value(value: txnRepoView),
        Provider<WorkRepo>.value(value: workRepoView),
        Provider<PurchaseRepo>.value(value: purchaseRepoView),
        Provider<BomRepo>.value(value: bomRepoView),

        // 경로 파사드
        Provider<ItemPathProvider>.value(value: pathFacade),

        // 서비스
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
