import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../repos/inmem_repo.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';
import '../models/item.dart';

enum CartMode { groupBySupplier, flat }


class CartManager extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get count => _items.length;


  // ✅ mode 게터/세터
  CartMode _mode = CartMode.groupBySupplier;

  CartMode get mode => _mode;

  void setMode(CartMode m) {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void addFromItem(Item i, {double qty = 1}) {
    final colorNo = (i.attrs?['color_no'] ?? '').toString().trim(); // ✅ 단일 경로

    _items.add(CartItem(
      itemId: i.id,
      name: i.displayName ?? i.name,
      unit: i.unit,
      qty: qty,
      supplierName: i.supplierName?.trim() ?? '',
      colorNo: colorNo, // ✅ 그대로 저장
    ));
    notifyListeners();
  }


// ✅ cart_sheet.dart에서 호출
  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  // ✅ 새로 추가: 수량 변경
  void updateQty(int index, double qty) {
    if (qty <= 0) return;
    _items[index] = _items[index].copyWith(qty: qty);
    notifyListeners();
  }

  void updateSupplier(int idx, String s) {
    _items[idx] = _items[idx].copyWith(supplierName: s.trim());
    notifyListeners();
  }

  // ✅ 새로 추가: 공급처 일괄 지정
  void setAllSupplier(String supplier) {
    final s = supplier.trim();
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(supplierName: s);
    }
    notifyListeners();
  }

  // ✅ 새로 추가: 요약
  int get supplierCount =>
      _items
          .map((e) => e.supplierName.trim())
          .toSet()
          .length;

  double get totalQty =>
      _items.fold(0.0, (acc, e) => acc + (e.qty));

  Future<List<String>> createPurchaseOrdersFromCart(InMemoryRepo repo) async {
    // 1) 공급처별 그룹핑
    final grouped = <String, List<CartItem>>{};
    for (final c in _items) {
      final k = c.supplierName
          .trim()
          .isEmpty ? '(미지정)' : c.supplierName.trim();
      (grouped[k] ??= []).add(c);
    }

    // 2) PO 생성 및 라인 생성
    final created = <String>[];

    for (final entry in grouped.entries) {
      final supplier = entry.key == '(미지정)' ? '' : entry.key;

      final poId = 'po_${DateTime
          .now()
          .microsecondsSinceEpoch}_${created.length}';
      final po = PurchaseOrder(
        id: poId,
        supplierName: supplier,
        eta: DateTime.now().add(const Duration(days: 2)),
        status: PurchaseOrderStatus.draft,
      );
      await repo.createPurchaseOrder(po);

      // ✅ 각 CartItem 단위로 color_no 계산하여 PurchaseLine 만들기
      final lines = <PurchaseLine>[];
      for (var i = 0; i < entry.value.length; i++) {
        final c = entry.value[i];
        final it = repo.getItemById(c.itemId);

        final colorNo = (c.colorNo
            ?.trim()
            .isNotEmpty == true)
            ? c.colorNo!.trim()
            : (it?.attrs?['color_no'] ?? '').toString().trim();

        lines.add(PurchaseLine(
          id: 'pol_${poId}_$i',
          // ✅ 라인 id는 poId 기준으로 안정적으로
          orderId: poId,
          itemId: c.itemId,
          name: c.name,
          unit: c.unit,
          qty: c.qty,
          colorNo: colorNo, // ✅ color_no 정확히 주입
        ));
      }

      await repo.upsertLines(poId, lines);
      created.add(poId);
    }

    // 3) 장바구니 비우기
    clear();

    return created;
  }
}
