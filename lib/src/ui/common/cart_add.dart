import 'package:flutter/foundation.dart';
import '../../models/item.dart';

/// CartManager가 어떤 add API를 갖고 있든 흡수해서 1개씩 담아주는 헬퍼.
/// - browser 멀티선택 / 상세 단일담기 모두 이걸 재사용
void addItemsToCart(dynamic cart, List<Item> items) {
  for (final it in items) {
    if (cart.addFromItem is Function) {
      cart.addFromItem(it);
    } else if (cart.addItem is Function) {
      cart.addItem(it.id, 1);
    } else if (cart.addLine is Function) {
      cart.addLine({
        'itemId': it.id,
        'name': it.displayName ?? it.name,
        'qty': 1,
        'unit': it.unit,
      });
    } else {
      debugPrint('[CartManager] No known add method.');
    }
  }
}
