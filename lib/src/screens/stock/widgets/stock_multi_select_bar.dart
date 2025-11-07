import 'package:flutter/material.dart';

class StockMultiSelectBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onAddToCart;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  const StockMultiSelectBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onAddToCart,
    required this.onSelectAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE6E0F8),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text('선택됨 $selectedCount / $totalCount')),
              TextButton.icon(onPressed: onSelectAll, icon: const Icon(Icons.select_all), label: const Text('전체')),
              TextButton.icon(onPressed: onClear,     icon: const Icon(Icons.clear_all),  label: const Text('해제')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: selectedCount == 0 ? null : onAddToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('담기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
