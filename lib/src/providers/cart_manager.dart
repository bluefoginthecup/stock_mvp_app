// lib/src/providers/cart_manager.dart
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/item.dart';
import '../models/purchase_line.dart';
import '../models/purchase_order.dart';
import '../repos/repo_interfaces.dart'; // ✅ 인터페이스만 참조

enum CartMode { groupBySupplier, flat }

class CartManager extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get count => _items.length;

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
    final colorNo = (i.attrs?['color_no'] ?? '').toString().trim();
    _items.add(
      CartItem(
        itemId: i.id,
        name: i.displayName ?? i.name,
        unit: i.unit,
        qty: qty,
        supplierName: i.supplierName?.trim() ?? '',
        colorNo: colorNo,
      ),
    );
    notifyListeners();
  }

  /// ✅ 선택된 index들만 장바구니에서 제거 (내림차순 삭제로 안전)
  void removeByIndexes(Set<int> selected) {
    if (selected.isEmpty) return;
    final idxs = selected.toList()..sort((a, b) => b.compareTo(a));
    for (final i in idxs) {
      if (i >= 0 && i < _items.length) {
        _items.removeAt(i);
      }
    }
    notifyListeners();
  }

  /// (선택) 선택된 항목만 뽑기
  List<CartItem> pickByIndexes(Set<int> selected) {
    final out = <CartItem>[];
    for (final i in selected) {
      if (i >= 0 && i < _items.length) out.add(_items[i]);
    }
    return out;
  }


  /// UNDO 복구 등에 사용
  void insert(int index, CartItem item) {
    if (index < 0 || index > _items.length) {
      _items.add(item);
    } else {
      _items.insert(index, item);
    }
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void updateQty(int index, double qty) {
    if (index < 0 || index >= _items.length) return;
    if (qty <= 0) return;
    _items[index] = _items[index].copyWith(qty: qty);
    notifyListeners();
  }

  void updateSupplier(int idx, String s) {
    if (idx < 0 || idx >= _items.length) return;
    _items[idx] = _items[idx].copyWith(supplierName: s.trim());
    notifyListeners();
  }

  void setAllSupplier(String supplier) {
    final s = supplier.trim();
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(supplierName: s);
    }
    notifyListeners();
  }

  int get supplierCount => _items.map((e) => e.supplierName.trim()).toSet().length;
  double get totalQty => _items.fold(0.0, (acc, e) => acc + e.qty);

  /// ✅ 표준 인터페이스에 정확히 맞춤
  /// - PO 생성: createPurchaseOrder(po) → String (생성된 id)
  /// - 라인 저장: upsertLines(orderId, lines)
  /// - color_no 보강: itemRepo.getItem(itemId)
  Future<List<String>> createPurchaseOrdersFromCart({
    required PurchaseOrderRepo poRepo,
    required ItemRepo itemRepo,
  }) async {
    // 1) 공급처별 그룹핑
    final grouped = <String, List<CartItem>>{};
    for (final c in _items) {
      final key = c.supplierName.trim().isEmpty ? '(미지정)' : c.supplierName.trim();
      (grouped[key] ??= []).add(c);
    }

    // 2) 생성 루프
    final created = <String>[];

    for (final entry in grouped.entries) {
      final supplier = entry.key == '(미지정)' ? '' : entry.key;

      // id는 구현에 따라 내부에서 생성될 수도 있으므로, 모델에 임시 id를 넣어도 되고 비워도 됨.
      final po = PurchaseOrder(
        id: 'po_${DateTime.now().microsecondsSinceEpoch}_${created.length}',
        supplierName: supplier,
        eta: DateTime.now().add(const Duration(days: 2)),
        status: PurchaseOrderStatus.draft,
      );

      // 표준: 생성 후 실제 저장된 id 반환
      final savedId = await poRepo.createPurchaseOrder(po);

      // 라인 구성
      final lines = <PurchaseLine>[];
      for (var i = 0; i < entry.value.length; i++) {
        final c = entry.value[i];

        final it = await itemRepo.getItem(c.itemId);
        final colorNo = (c.colorNo?.trim().isNotEmpty == true)
            ? c.colorNo!.trim()
            : (it?.attrs?['color_no'] ?? '').toString().trim();

        lines.add(
          PurchaseLine(
            id: 'pol_${savedId}_$i',
            orderId: savedId,
            itemId: c.itemId,
            name: c.name,
            unit: c.unit,
            qty: c.qty,
            colorNo: colorNo,
          ),
        );
      }

      await poRepo.upsertLines(savedId, lines);
      created.add(savedId);
    }

    // 3) 정리
    clear();
    return created;
  }
  /// ✅ 선택된 항목(picked)만으로 발주서 생성
  Future<List<String>> createPurchaseOrdersFromPicked({
    required List<CartItem> picked,
    required PurchaseOrderRepo poRepo,
    required ItemRepo itemRepo,
  }) async {
    if (picked.isEmpty) return [];

    // 1) 공급처별 그룹핑
    final grouped = <String, List<CartItem>>{};
    for (final c in picked) {
      final key = c.supplierName.trim().isEmpty ? '(미지정)' : c.supplierName.trim();
      (grouped[key] ??= []).add(c);
    }

    // 2) 생성 루프
    final created = <String>[];

    for (final entry in grouped.entries) {
      final supplier = entry.key == '(미지정)' ? '' : entry.key;

      final po = PurchaseOrder(
        id: 'po_${DateTime.now().microsecondsSinceEpoch}_${created.length}',
        supplierName: supplier,
        eta: DateTime.now().add(const Duration(days: 2)),
        status: PurchaseOrderStatus.draft,
      );

      final savedId = await poRepo.createPurchaseOrder(po);

      final lines = <PurchaseLine>[];
      for (var i = 0; i < entry.value.length; i++) {
        final c = entry.value[i];

        final it = await itemRepo.getItem(c.itemId);
        final colorNo = (c.colorNo?.trim().isNotEmpty == true)
            ? c.colorNo!.trim()
            : (it?.attrs?['color_no'] ?? '').toString().trim();

        lines.add(
          PurchaseLine(
            id: 'pol_${savedId}_$i',
            orderId: savedId,
            itemId: c.itemId,
            name: c.name,
            unit: c.unit,
            qty: c.qty,
            colorNo: colorNo,
          ),
        );
      }

      await poRepo.upsertLines(savedId, lines);
      created.add(savedId);
    }

    return created;
  }

}
