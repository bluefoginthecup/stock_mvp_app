import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders/order_list_screen.dart';
import 'screens/stock/stock_list_screen.dart';
import 'screens/txns/txn_list_screen.dart';
import 'screens/works/work_list_screen.dart';
import 'screens/purchases/purchase_list_screen.dart';
//다국어 앱 셋팅
import '/src/l10n/l10n.dart';
import '/src/ui/common/ui.dart';
import 'app/lang_controller.dart';
import 'package:provider/provider.dart';
import '/src/screens/settings/language_settings_screen.dart';


class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // 앱 시작 시 로딩
        create: (_) => LangController()..load(),
        child: Builder(
        builder: (context) {
    final lang = context.watch<LangController>();
    return MaterialApp(
      locale: lang.locale,
      onGenerateTitle: (ctx) => L10n.of(ctx).app_title,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('es'), // 스페인어 추가 시 주석 해제
      ],
      theme: ThemeData( /* ... */ ),
      routes: {
        '/': (_) => const DashboardScreen(),    // 아래 AppBar 타이틀도 i18n으로
        '/orders': (_) => const OrderListScreen(),
        '/stock': (_) => const StockListScreen(),
        '/txns': (_) => const TxnListScreen(),
        '/works': (_) => const WorkListScreen(),
        '/purchases': (_) => const PurchaseListScreen(),
        '/settings/language': (_) => const LanguageSettingsScreen(),
      },
      initialRoute: '/',
    );
        }
    ),
    );
  }
}


