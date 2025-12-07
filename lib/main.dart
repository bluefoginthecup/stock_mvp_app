import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ 추가
import 'firebase_options.dart'; // ✅ 플랫폼별 FirebaseOptions
import 'package:firebase_auth/firebase_auth.dart';

import 'src/app.dart';

import 'src/repos/repo_interfaces.dart';
import 'src/services/inventory_service.dart';
import 'src/utils/item_presentation.dart';
import 'src/ui/nav/item_detail_opener.dart';
import 'src/providers/cart_manager.dart';
import 'src/models/purchase_order.dart';

// 탭/선택 컨트롤러
import 'src/app/main_tab_controller.dart';
import 'src/screens/stock/widgets/item_selection_controller.dart';

// ✅ 추가: Auth & Gate
import 'src/services/auth_service.dart';

// Drift + SQLite
import 'src/db/app_database.dart';
import 'src/repos/drift_unified_repo.dart';
import 'src/models/txn.dart';
import 'src/repos/timeline_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // ✅ macOS 포함 모든 플랫폼에서 필수
  );

  // Provider 경고 끄기 (필요 시)
  Provider.debugCheckInvalidValueType = null;

  // DB & Repo
  final db = AppDatabase();

  // 2) 통합 Drift Repo (Item / Txn / Order / Work / Purchase / Supplier / Paths 모두 포함)
  final unifiedRepo = DriftUnifiedRepo(db);

  // ✅ Provider가 트리에 올라가든 말든, 캐시만 미리 채워두면 됨
// (notifyListeners가 너무 빨리 호출돼도 문제 없음)
  Future.microtask(() => unifiedRepo.refreshBomSnapshot());


    // ⚠️ 자동 시드 임포트 비활성화: 설정 화면에서 버튼으로만 실행
    // (개발 중 임시로 쓰고 싶다면 아래 가드 플래그/디버그 모드로 감싸세요)
    // if (kDebugMode && kEnableDevAutoSeed) {
    //   final importer = UnifiedSeedImporter(
    //     itemRepo: unifiedRepo,
    //     bomRepo: unifiedRepo,
    //     verbose: true,
    //   );
    //   await importer.importUnifiedFromAssets(
    //     itemsAssetPath: 'assets/seeds/2025-10-26/items.json',
    //     foldersAssetPath: 'assets/seeds/2025-10-26/folders.json',
    //     bomAssetPath: 'assets/seeds/2025-10-26/bom.json',
    //     lotsAssetPath: 'assets/seeds/2025-10-26/lots.json',
    //     clearBefore: true,
    //   );
    // }


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
        // ✅ 통합 휴지통(TrashScreen)이 쓰는 Repo 노출
        Provider<TrashRepo>.value(value: unifiedRepo),
        Provider<TimelineRepo>(
          create: (_) => TimelineRepo(
            getOrderById: (id) async {
              final o = await unifiedRepo.getOrder(id); // OrderRepo 인터페이스 메서드
              if (o == null) throw Exception('Order not found: $id');
              return o;
            },
            listPOsByOrderId: (id) => unifiedRepo.listPurchaseOrdersByOrderId(id),
            listWorksByOrderId: (id) => unifiedRepo.listWorksByOrderId(id),
          ),
        ),



        // ✅ txns도 실시간 구독 (UI에서 context.watch<List<Txn>>()로 바로 사용)
        StreamProvider<List<Txn>>(
          create: (ctx) => unifiedRepo.watchTxns(),
          initialData: const [],
        ),


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
            items: ctx.read<ItemRepo>(),
          ),
        ),
      ],
      // ⛳️ 여기 **무조건** StockApp (MaterialApp 포함)
      child: const StockApp(),
    ),
  );

  // ✅ 로그인 세션 디버깅용
  FirebaseAuth.instance.authStateChanges().listen((user) {
    debugPrint('🔥 FirebaseAuth user: ${user?.uid}');
  });


}
