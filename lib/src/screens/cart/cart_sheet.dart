import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_manager.dart';
import '../../repos/inmem_repo.dart';

class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartManager>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16,12,16,16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('장바구니 (${cart.count})', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(cart.mode == 'purchase' ? '발주' : '주문'),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.items.length,
                itemBuilder: (ctx, i) {
                  final it = cart.items[i];
                  return ListTile(
                    dense: true,
                    title: Text(it.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('수량: ${it.qty} ${it.unit}'),
                        TextField(
                          controller: TextEditingController(text: it.supplierName),
                          decoration: const InputDecoration(
                            labelText: '공급처(상호) - 비워도 됨',
                          ),
                          onChanged: (v) => context.read<CartManager>().updateSupplier(i, v),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => context.read<CartManager>().removeAt(i),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.read<CartManager>().clear(),
                    child: const Text('비우기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('발주서 만들기'),
                    onPressed: () async {
                      final repo = context.read<InMemoryRepo>();
                      final ids = await context.read<CartManager>().createPurchaseOrdersFromCart(repo);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('발주 초안 ${ids.length}건 생성')),
                      );

                      Navigator.pop(context); // 시트 닫기
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
