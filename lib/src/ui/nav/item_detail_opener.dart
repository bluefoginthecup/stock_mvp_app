import 'package:flutter/material.dart';
import '../../utils/item_presentation.dart'; // ← 인터페이스 불러오기
import '/src/screens/stock/stock_item_detail_screen.dart'; // ← 실제 아이템 상세 화면

/// 앱 전체에서 "ItemLabel(autoNavigate:true)"를 눌렀을 때
/// 어디로 이동할지를 정의하는 실제 구현체.
class AppItemDetailOpener implements ItemDetailOpener {
  @override
  Future<void> open(BuildContext context, String itemId) {
    // 여기서 자유롭게 Navigator 또는 GoRouter로 이동시키면 됩니다.
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockItemDetailScreen(itemId: itemId),
      ),
    );
  }
}
