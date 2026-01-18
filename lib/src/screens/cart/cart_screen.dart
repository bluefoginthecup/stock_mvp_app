import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_list_screen.dart';

import '../../providers/cart_manager.dart';
import '../../repos/repo_interfaces.dart';
import '../../screens/orders/order_from_cart.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Set<int> _selected = {};

  bool get _selectMode => _selected.isNotEmpty;

  void _toggleSelect(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartManager>();
    final poRepo = context.read<PurchaseOrderRepo>();
    final itemRepo = context.read<ItemRepo>();

    // 선택 목록(현재 스냅샷)
    final picked = cart.pickByIndexes(_selected);

    Future<void> _editQty(BuildContext ctx, int index, double current) async {
      final c = TextEditingController(text: current.toStringAsFixed(0));
      final v = await showDialog<double>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          title: const Text('수량 변경'),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '수량'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('취소')),
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(c.text.trim());
                Navigator.pop(dctx, (parsed == null || parsed <= 0) ? null : parsed);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (v != null) cart.updateQty(index, v);
    }

    Future<void> _editSupplier(BuildContext ctx, int index, String current) async {
      final c = TextEditingController(text: current);
      final v = await showDialog<String>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          title: const Text('공급처 변경'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: '예: OO상사'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('취소')),
            TextButton(
              onPressed: () => Navigator.pop(dctx, c.text.trim()),
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (v != null) cart.updateSupplier(index, v);
    }

    Future<void> _setSupplierForAll(BuildContext ctx) async {
      final c = TextEditingController();
      final v = await showDialog<String>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          title: const Text('공급처 일괄 지정'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: '예: OO상사'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('취소')),
            TextButton(
              onPressed: () => Navigator.pop(dctx, c.text.trim()),
              child: const Text('적용'),
            ),
          ],
        ),
      );
      if (v != null && v.isNotEmpty) cart.setAllSupplier(v);
    }

    Future<void> _createPOsFromPicked(BuildContext ctx) async {
      if (picked.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('선택된 항목이 없어요')),
        );
        return;
      }

      try {
        // ⚠️ 현재 CartManager API는 "전체 장바구니" 기준이므로,
        // 선택분만 발주서 생성하려면 CartManager에 선택분 버전을 추가하거나,
        // 여기서 임시로 "선택분만 남기고" 실행하면 안됨(데이터 꼬임).
        //
        // ✅ 최소 수정 전략:
        // 1) 선택분을 복제하여 CartManager의 기존 함수 로직을 여기서 재사용하지 않고
        // 2) CartManager에 createPurchaseOrdersFromPicked(...) 를 추가하는 것이 정석.
        //
        // 지금은 “중복 최소” 원칙대로 CartManager에 picked 버전 추가를 추천하지만,
        // 코드 덩치 최소로 가려면 아래처럼 "picked를 공급처별로 직접 생성"도 가능.
        //
        // 여기서는 CartManager에 createPurchaseOrdersFromPicked(...)를 추가했다고 가정하고 호출:
        //
        final ids = await cart.createPurchaseOrdersFromPicked(
          picked: picked,
          poRepo: poRepo,
          itemRepo: itemRepo,
        );

        // ✅ 생성 성공 → 선택분만 장바구니에서 제거
        cart.removeByIndexes(_selected);
        _clearSelection();

        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('발주서 ${ids.length}건 생성 완료!'),
              action: SnackBarAction(
                label: '목록 보기',
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const PurchaseListScreen()),
                  );
                },
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('발주서 생성 실패: $e')),
        );
      }
    }

    Future<void> _createInternalOrderFromPicked(BuildContext ctx) async {
      if (picked.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('선택된 항목이 없어요')),
        );
        return;
      }

      await createInternalOrderFromPicked(ctx, picked: picked);

      // ✅ 주문 생성 후 선택분 제거(중복 방지)
      cart.removeByIndexes(_selected);
      _clearSelection();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '장바구니 (선택 ${_selected.length})' : '장바구니'),
        leading: _selectMode
            ? IconButton(
          icon: const Icon(Icons.close),
          tooltip: '선택 해제',
          onPressed: _clearSelection,
        )
            : null,
        actions: [
          if (_selectMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: '전체 선택',
              onPressed: () {
                setState(() {
                  _selected
                    ..clear()
                    ..addAll(List.generate(cart.count, (i) => i));
                });
              },
            ),
          PopupMenuButton<String>(
            onSelected: (key) async {
              switch (key) {
                case 'bulkSupplier':
                  await _setSupplierForAll(context);
                  break;
                case 'clearAll':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('모두 삭제할까요?'),
                      content: const Text('장바구니의 모든 품목을 삭제합니다.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('삭제')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    cart.clear();
                    _clearSelection();
                  }
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'bulkSupplier', child: Text('공급처 일괄 지정')),
              PopupMenuItem(value: 'clearAll', child: Text('모두 비우기')),
            ],
          ),
        ],
      ),
      body: cart.count == 0
          ? const Center(child: Text('장바구니가 비어 있습니다.'))
          : ListView.separated(
        itemCount: cart.count,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final it = cart.items[i];
          final checked = _selected.contains(i);

          return Dismissible(
            key: ValueKey('cart_i_${it.itemId}_$i'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.redAccent,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) {
              final removed = it;
              cart.removeAt(i);
              setState(() {
                // 인덱스 기반 선택은 삭제 시 흔들리기 쉬움 → 안전하게 선택 해제
                _selected.remove(i);
              });
              ScaffoldMessenger.of(ctx).clearSnackBars();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('삭제됨: ${removed.name}'),
                  action: SnackBarAction(
                    label: '실행취소',
                    onPressed: () {
                      cart.insert(i, removed);
                    },
                  ),
                ),
              );
            },
            child: ListTile(
              onTap: () => _toggleSelect(i),
              leading: Checkbox(
                value: checked,
                onChanged: (_) => _toggleSelect(i),
              ),
              title: Text(it.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('수량: ${it.qty.toStringAsFixed(0)}  (${it.unit})'),
                  Text(it.supplierName.isEmpty ? '(공급처 미지정)' : '공급처: ${it.supplierName}'),
                ],
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: '수량 변경',
                    icon: const Icon(Icons.exposure),
                    onPressed: () => _editQty(ctx, i, it.qty),
                  ),
                  IconButton(
                    tooltip: '공급처 변경',
                    icon: const Icon(Icons.store),
                    onPressed: () => _editSupplier(ctx, i, it.supplierName),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: cart.count == 0
          ? null
          : SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectMode
                      ? '선택 ${_selected.length}개'
                      : '품목 ${cart.count} • 공급처 ${cart.supplierCount} • 총수량 ${cart.totalQty.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.shopping_bag),
                label: const Text('발주서 생성'),
                onPressed: () => _createPOsFromPicked(context),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _createInternalOrderFromPicked(context),
                icon: const Icon(Icons.receipt_long),
                label: const Text('주문 생성'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
