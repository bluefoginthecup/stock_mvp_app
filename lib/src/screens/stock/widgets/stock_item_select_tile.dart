
import 'package:flutter/material.dart';
import '../../../models/item.dart';

class StockItemSelectTile extends StatelessWidget {
  final Item item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;        // 일반 모드 탭(상세로)
  final VoidCallback onLongPress;  // 롱프레스 → 선택모드 진입
  final VoidCallback onTogglePick; // 선택 토글

  const StockItemSelectTile({
    super.key,
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onTogglePick,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.displayName ?? item.name;

    return ListTile(
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onTogglePick())
          : const Icon(Icons.inventory_2_outlined),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,style: const TextStyle(
        fontSize: 16,        // ← 기존보다 +2 정도
        fontWeight: FontWeight.w500,
      ),),
      subtitle: Text('재고: ${item.qty} ${item.unit}', style: const TextStyle(
        fontSize: 14,        // 기본 12~13 -> 14로
        color: Colors.black54,
      ),
      ),
      dense: true,
      // ⭐/⋮ 제거 → trailing 없음
      onTap: selectionMode ? onTogglePick : onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    );
  }
}
