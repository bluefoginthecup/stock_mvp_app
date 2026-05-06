import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'src/app/main_tab_controller.dart';
// ✅ Repo & DB
import 'src/db/app_database.dart';
import 'src/repos/drift_unified_repo.dart';
import 'src/repos/repo_interfaces.dart';

/// 아주 심플한 부트스트랩:
/// - rootBuilder가 주어지면 그 위젯을 사용
/// - 아니면 기존 StockApp 사용
/// - 만약 body가 이미 MaterialApp이면 그대로 반환
class AppBootstrap {
  static Future<Widget> buildApp({
    ThemeData Function(ThemeData base)? themeOverride,
    Widget Function()? rootBuilder, // ✅ 데스크톱에서 DesktopHome 주입에 사용
  }) async {
    final Widget body = rootBuilder?.call() ?? const StockApp();

    // 이미 MaterialApp인 경우 그대로
    if (body is MaterialApp) return body;

    final base = ThemeData(useMaterial3: true);
    final theme = themeOverride != null ? themeOverride(base) : base;

    // ✅ DB & 통합 Repo 생성
    final db = AppDatabase();
    final unified = DriftUnifiedRepo(db);

    // ✅ Provider 트리: 탭 컨트롤러  각 Repo 인터페이스 주입
    final Widget home = MultiProvider(
      providers: [
        // 컨트롤러
        ChangeNotifierProvider<MainTabController>(
            create: (_) => MainTabController()),

        // DB
        Provider<AppDatabase>.value(value: db),
        // ✅ DriftUnifiedRepo가 implements 하는 실제 인터페이스들 주입
        Provider<ItemRepo>.value(value: unified),
        Provider<TxnRepo>.value(value: unified),
        Provider<BomRepo>.value(value: unified),
        Provider<OrderRepo>.value(value: unified),
        Provider<WorkRepo>.value(value: unified),
        Provider<PurchaseOrderRepo>.value(value: unified),
        Provider<QuoteRepo>.value(value: unified),
        Provider<ScheduleRepo>.value(value: unified),
        Provider<SupplierRepo>.value(value: unified),
        Provider<FolderTreeRepo>.value(
            value: unified), // ← FolderRepo가 아니라 FolderTreeRepo
        Provider<TrashRepo>.value(value: unified),
        // e.g. Provider<TimelineRepo>(create: (_) => TimelineRepo(unified)),
      ],
      child: body,
    );

    return MaterialApp(
      theme: theme,
      home: home,
      debugShowCheckedModeBanner: false,
    );
  }
}
