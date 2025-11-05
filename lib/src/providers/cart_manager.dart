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

  void clear() { _items.clear(); notifyListeners(); }

  void addFromItem(Item i, {double qty = 1}) {
    _items.add(CartItem(
      itemId: i.id,
      name: i.displayName ?? i.name,
      unit: i.unit,
      qty: qty,
      supplierName: i.supplierName?.trim() ?? '',
    ));
    notifyListeners();
  }
  
// ✅ cart_sheet.dart에서 호출
    void removeAt(int index) {
        if (index < 0 || index >= _items.length) return;
        _items.removeAt(index);
        notifyListeners();
      }

  void updateSupplier(int idx, String s) {
    _items[idx] = _items[idx].copyWith(supplierName: s.trim());
    notifyListeners();
  }

  Future<List<String>> createPurchaseOrdersFromCart(InMemoryRepo repo) async {
    final grouped = <String, List<CartItem>>{};
    for (final c in _items) {
      final k = c.supplierName.trim().isEmpty ? '(미지정)' : c.supplierName.trim();
      (grouped[k] ??= []).add(c);
    }
    final created = <String>[];
    for (final entry in grouped.entries) {
      final supplier = entry.key == '(미지정)' ? '' : entry.key;
      final id = 'po_${DateTime.now().microsecondsSinceEpoch}_${created.length}';
      final po = PurchaseOrder(
        id: id,
        supplierName: supplier,
        eta: DateTime.now().add(const Duration(days: 2)),
        status: PurchaseOrderStatus.draft,
      );
      await repo.createPurchaseOrder(po);

      final lines = entry.value.map((c) => PurchaseLine(
        id: 'pol_${DateTime.now().microsecondsSinceEpoch}_${c.itemId}',
        orderId: id,
        itemId: c.itemId,
        name: c.name,
        unit: c.unit,
        qty: c.qty,
      )).toList();

      await repo.upsertLines(id, lines);
      created.add(id);
    }
    clear();
    return created;
  }
}
