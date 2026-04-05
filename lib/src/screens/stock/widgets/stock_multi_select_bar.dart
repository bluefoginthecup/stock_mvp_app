import 'package:flutter/material.dart';


class StockMultiSelectBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onAddToCart;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onTrash;                // 🗑️ 추가
  final VoidCallback onCopy;
  final bool allSelectedAreFavorite;         // ⭐ 추가
  final VoidCallback onToggleFavoriteAll;    // ⭐ 추가



  const StockMultiSelectBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onAddToCart,
    required this.onSelectAll,
    required this.onClear,
    required this.onMove,
  required this.onTrash,
    required this.onCopy,
    required this.allSelectedAreFavorite,
      required this.onToggleFavoriteAll,

});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE6E0F8),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 🔹 상하 여백 줄임
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '선택됨 $selectedCount / $totalCount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium, // 🔹 글씨 크기도 살짝 줄이기
                ),
              ),
// 전체 선택
                        Tooltip(
                              message: '전체 선택',
                              child: IconButton(
                                onPressed: onSelectAll,
                                icon: const Icon(Icons.select_all),
                            iconSize: 20,
                            padding: const EdgeInsets.all(6),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),
                  // 선택 해제

    // ⭐ 즐겨찾기(일괄 토글)
                  Tooltip(
                    message: allSelectedAreFavorite ? '즐겨찾기 해제' : '즐겨찾기',
                    child: IconButton(
                      onPressed: selectedCount == 0 ? null : onToggleFavoriteAll,
                      icon: Icon(allSelectedAreFavorite ? Icons.star : Icons.star_border),
                      iconSize: 20,
                      padding: const EdgeInsets.all(6),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),

    // 🗑️ 휴지통(일괄)
                  Tooltip(
                    message: '휴지통으로 이동',
                    child: IconButton(
                      onPressed: selectedCount == 0 ? null : onTrash,
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                      iconSize: 20,
                      padding: const EdgeInsets.all(6),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),
    // 이동
                  Tooltip(
                    message: '이동',
                    child: IconButton(
                      onPressed: selectedCount == 0 ? null : onMove,
                      icon: const Icon(Icons.drive_file_move),
                      iconSize: 20,
                      padding: const EdgeInsets.all(6),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),

          // 📋 복사
              Tooltip(
                    message: '복사',
                    child: IconButton(
                  onPressed: selectedCount == 0 ? null : onCopy,
                      icon: const Icon(Icons.copy),
                  iconSize: 20,
                  padding: const EdgeInsets.all(6),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),


    // 담기(강조) — 아이콘만, Material 3이면 filled 변형 사용 가능
                  Tooltip(
                    message: '담기',
                    child: IconButton.filled(
                      onPressed: selectedCount == 0 ? null : onAddToCart,
                      icon: const Icon(Icons.add_shopping_cart),
                      iconSize: 20,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                  ),
            ],
          ),
        ),

      ),
    );
  }
}
