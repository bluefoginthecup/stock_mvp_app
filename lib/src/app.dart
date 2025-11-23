import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/app/main_tab_screen.dart';
import 'screens/orders/order_list_screen.dart';
import 'screens/stock/stock_browser_screen.dart';
import 'screens/txns/txn_list_screen.dart';
import 'screens/works/work_list_screen.dart';
import 'screens/purchases/purchase_list_screen.dart';

// 다국어 앱 셋팅
import '/src/l10n/l10n.dart';
import '/src/ui/common/ui.dart';
import 'app/lang_controller.dart';
import '/src/screens/settings/language_settings_screen.dart';

import 'screens/stock/stock_item_detail_screen.dart';
import 'screens/purchases/purchase_detail_screen.dart';
import 'screens/suppliers/supplier_form_screen.dart';
import 'screens/suppliers/supplier_list_screen.dart';
import 'screens/receipts/receipt_create_screen.dart';
import 'screens/receipts/receipts_home_screen.dart';

import 'repos/repo_interfaces.dart';

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
      final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();
      final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
      final lang = context.watch<LangController>();

      return MaterialApp(
        navigatorKey: rootNavKey,
        scaffoldMessengerKey: messengerKey,
        locale: lang.locale,
        onGenerateTitle: (ctx) => L10n.of(ctx).app_title,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('es'),
        ],
        theme: ThemeData(/* ... */),

        // ✅ 앱 첫 화면: 로그인 게이트
        home: LaunchGate(
          // 로그인된 상태라면 여기로 진입
          signedInBuilder: (_) => const MainTabScreen(),
        ),

        // 나머지 라우트는 그대로 유지
        routes: {
          '/orders': (_) => const OrderListScreen(),
          '/stock': (_) => const StockBrowserScreen(),
          '/txns': (_) => const TxnListScreen(),
          '/works': (_) => const WorkListScreen(),
          '/purchases': (_) => const PurchaseListScreen(),
          '/settings/language': (_) => const LanguageSettingsScreen(),
          '/items/detail': (context) {
            final itemId = ModalRoute
                .of(context)!
                .settings
                .arguments as String;
            return StockItemDetailScreen(itemId: itemId);
          },
          '/purchases/detail': (context) {
            debugPrint('[Route] /purchases/detail builder called');
            final orderId = ModalRoute
                .of(context)!
                .settings
                .arguments as String;
            final poRepo = context.read<PurchaseOrderRepo>();
            return PurchaseDetailScreen(orderId: orderId, repo: poRepo);
          },
          '/suppliers/new': (context) => const SupplierFormScreen(),
          '/suppliers/edit': (context) {
            final id = ModalRoute
                .of(context)!
                .settings
                .arguments as String;
            return SupplierFormScreen(supplierId: id);
          },
          '/suppliers': (_) => const SupplierListScreen(),
          '/receipts': (_) => const ReceiptsHomeScreen(),
          '/receipts/new': (_) => const ReceiptCreateScreen(),
        },

      // ⚠️ home을 쓰면 initialRoute는 무시되므로 제거해도 됩니다.
      // initialRoute: '/',
      );
      },
      ),
    );
  }
  }
