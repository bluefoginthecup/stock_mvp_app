import 'package:flutter/material.dart';
import '../../../models/item.dart';

class StockItemSelectTile extends StatelessWidget {
  final Item item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;           // 일반 모드 탭(상세로)
  final VoidCallback onLongPress;     // 롱프레스 → 선택모드 진입
  final VoidCallback onTogglePick;    // 선택 토글
  final VoidCallback? onToggleFavorite; // ✅ 추가

  const StockItemSelectTile({
    super.key,
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onTogglePick,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.displayName ?? item.name;
    return ListTile(
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onTogglePick())
          : const Icon(Icons.inventory_2_outlined),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('재고: ${item.qty} ${item.unit}'),
        // ✅ 선택 모드가 아닐 때: 우상단에 ★ 토글 + > 표시
              trailing: selectionMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                      children: [
                    IconButton(
                      tooltip: (item.isFavorite == true) ? '즐겨찾기 해제' : '즐겨찾기 추가',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: const EdgeInsets.all(4),
                      icon: Icon(
                        (item.isFavorite == true) ? Icons.star : Icons.star_border,
                        size: 20,
                      ),
                      onPressed: () {
                      final next = !(item.isFavorite == true);
                      debugPrint('[Tile] ⭐ tap → id=${item.id}, title="$title", '
                      'was=${item.isFavorite}, next=$next');
                      onToggleFavorite?.call(); // 부모에서 실제 저장 수행
                        }

                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
      onTap: selectionMode ? onTogglePick : onTap,
      onLongPress: onLongPress,
    );
  }
}
