import 'package:flutter/material.dart';
import '../screens/trash/trash_screen.dart';
import '../screens/stock/stock_browser_screen.dart';


void openTrashFromNav(NavigatorState nav) {
  nav.push(
    MaterialPageRoute(builder: (_) => const TrashScreen()),
  );
}

void openStockAndJump(
    NavigatorState nav,
    List<String> pathIds,
    ) {
  nav.push(
    MaterialPageRoute(
      builder: (_) => StockBrowserScreen(
        initialPath: pathIds, // 🔥 핵심
      ),
    ),
  );
}