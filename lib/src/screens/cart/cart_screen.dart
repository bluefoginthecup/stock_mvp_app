import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stockapp_mvp/src/screens/purchases/purchase_list_screen.dart';

import '../../providers/cart_manager.dart';
import '../../repos/repo_interfaces.dart'; // ✅ 인터페이스로 주입
import '../../screens/orders/order_from_cart.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartManager>();
    final poRepo = context.read<PurchaseOrderRepo>(); // ✅ InMemoryRepo → PurchaseOrderRepo
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

    Future<void> _createPOs(BuildContext ctx) async {
      try {
        // ✅ 인자 타입을 PurchaseOrderRepo로 변경
        final ids = await cart.createPurchaseOrdersFromCart(
          poRepo: poRepo,
          itemRepo: itemRepo,
        );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('장바구니'),
        actions: [
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
                  if (ok == true) cart.clear();
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
          return Dismissible(
            key: ValueKey('cart_i_${it.itemId}'),
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
              ScaffoldMessenger.of(ctx).clearSnackBars();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('삭제됨: ${removed.name}'),
                  action: SnackBarAction(
                    label: '실행취소',
                    onPressed: () {
                      // 필요 시 CartManager에 addRaw(CartItem) 같은 복구용 메서드 추가 권장
                      // 지금은 간단히 다시 추가:
                      cart.insert(i, removed);
                    },
                  ),
                ),
              );
            },
            child: ListTile(
              leading: const Icon(Icons.inventory),
              title: Text(it.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('수량: ${it.qty.toStringAsFixed(0)}  (${it.unit})'),
                  Text(
                    it.supplierName.isEmpty
                        ? '(공급처 미지정)'
                        : '공급처: ${it.supplierName}',
                  ),
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
              // 내부 주문 생성(재고보충)
              ElevatedButton.icon(
                onPressed: () async => await onCreateInternalOrderPressed(context),
                icon: const Icon(Icons.shopping_bag),
                label: const Text('주문 생성'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
