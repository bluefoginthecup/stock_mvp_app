import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders/order_list_screen.dart';
import 'screens/stock/stock_list_screen.dart';
import 'screens/txns/txn_list_screen.dart';
import 'screens/works/work_list_screen.dart';
import 'screens/purchases/purchase_list_screen.dart';

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockApp MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const DashboardScreen(),
        '/orders': (_) => const OrderListScreen(),
        '/stock': (_) => const StockListScreen(),
        '/txns': (_) => const TxnListScreen(),
        '/works': (_) => const WorkListScreen(),
        '/purchases': (_) => const PurchaseListScreen(),
      },
      initialRoute: '/',
    );
  }
}
