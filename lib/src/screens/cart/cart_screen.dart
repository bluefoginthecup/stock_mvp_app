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
  final Set<int> _selected = {}; // ✅ 멀티 선택(인덱스 기반)

  bool _isAllSelected(int total) => total > 0 && _selected.length == total;

  void _toggleSelectAll(int total) {
    setState(() {
      if (_isAllSelected(total)) {
        _selected.clear(); // ✅ 전체 해제
      } else {
        _selected
          ..clear()
          ..addAll(List<int>.generate(total, (i) => i)); // ✅ 전체 선택
      }
    });
  }

  void _toggleOne(int index) {
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

    // ✅ 선택된 항목에만 공급처 일괄 지정
    Future<void> _setSupplierForSelected(BuildContext ctx) async {
      if (_selected.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('선택된 항목이 없어요')),
        );
        return;
      }

      final c = TextEditingController();
      final v = await showDialog<String>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          title: Text('선택 ${_selected.length}개 공급처 일괄 지정'),
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
      if (v == null || v.isEmpty) return;

      // 인덱스 기반 업데이트 (중복/동일 아이템이어도 정확히 적용됨)
      for (final idx in _selected) {
        if (idx >= 0 && idx < cart.count) {
          cart.updateSupplier(idx, v);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('선택 ${_selected.length}개에 공급처 적용 완료')),
        );
      }
    }

    // ✅ 선택된 항목 삭제
    Future<void> _deleteSelected(BuildContext ctx) async {
      if (_selected.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('선택된 항목이 없어요')),
        );
        return;
      }

      final ok = await showDialog<bool>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          title: Text('선택 ${_selected.length}개 삭제할까요?'),
          content: const Text('선택된 품목들을 장바구니에서 삭제합니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('삭제')),
          ],
        ),
      );

      if (ok != true) return;

      // index 내림차순으로 removeAt (인덱스 밀림 방지)
      final idxs = _selected.toList()..sort((a, b) => b.compareTo(a));
      for (final i in idxs) {
        if (i >= 0 && i < cart.count) {
          cart.removeAt(i);
        }
      }
      _clearSelection();

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('선택 항목 삭제 완료')),
        );
      }
    }

    Future<void> _createPOs(BuildContext ctx) async {
      try {
        final ids = await cart.createPurchaseOrdersFromCart(
          poRepo: poRepo,
          itemRepo: itemRepo,
        );
        _clearSelection(); // 생성 후 선택 초기화
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

    final hasItems = cart.count > 0;
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: hasSelection
            ? Text('선택 ${_selected.length}개')
            : const Text('장바구니'),
        leading: hasSelection
            ? IconButton(
          tooltip: '선택 해제',
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        )
            : null,
        actions: [
          if (hasItems)
            IconButton(
              tooltip: _isAllSelected(cart.count) ? '전체 해제' : '전체 선택',
              icon: Icon(
                _isAllSelected(cart.count)
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
              ),
              onPressed: () => _toggleSelectAll(cart.count),
            ),

          // ✅ 선택된 항목이 있을 때만: 멀티 기능 메뉴 노출
          if (hasSelection)
            PopupMenuButton<String>(
              tooltip: '선택 항목 작업',
              onSelected: (key) async {
                switch (key) {
                  case 'selSupplier':
                    await _setSupplierForSelected(context);
                    break;
                  case 'selDelete':
                    await _deleteSelected(context);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'selSupplier', child: Text('선택 항목 공급처 지정')),
                PopupMenuItem(value: 'selDelete', child: Text('선택 항목 삭제')),
              ],
            ),
        ],

      ),
      body: !hasItems
          ? const Center(child: Text('장바구니가 비어 있습니다.'))
          : ListView.separated(
        itemCount: cart.count,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final it = cart.items[i];
          final selected = _selected.contains(i);

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
              // ✅ 인덱스 기반 선택은 삭제 시 깨질 수 있으니 안전하게 초기화
              _clearSelection();

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
              onTap: () => _toggleOne(i), // ✅ 탭으로 선택 토글
              leading: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? Theme.of(context).colorScheme.primary : null,
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
      bottomNavigationBar: !hasItems
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
                  '품목 ${cart.count} • 공급처 ${cart.supplierCount} • 총수량 ${cart.totalQty.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.shopping_bag),
                label: const Text('발주서 생성'),
                onPressed: () => _createPOs(context),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async => await onCreateInternalOrderPressed(context),
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
