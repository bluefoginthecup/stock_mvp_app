import 'package:flutter/material.dart';


class StockMultiSelectBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onAddToCart;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onTrash;                // 🗑️ 추가
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
                  style: Theme.of(context).textTheme.bodyMedium, // 🔹 글씨 크기도 살짝 줄이기
                ),
              ),

              // 🔹 텍스트 버튼 공통 스타일
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6), // 좌우만 살짝 여유
                  minimumSize: const Size(0, 32), // 기본 40~48dp → 줄이기
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 터치영역 최소화
                  visualDensity: VisualDensity.compact, // 내부 간격 줄이기
                ),
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('전체'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onClear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('해제'),
              ),


              const SizedBox(width: 8),

          // ⭐ 즐겨찾기(일괄 토글)
                        TextButton.icon(
                              style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                    onPressed: selectedCount == 0 ? null : onToggleFavoriteAll,
                    icon: Icon(allSelectedAreFavorite ? Icons.star : Icons.star_border, size: 18),
                    label: Text(allSelectedAreFavorite ? '즐겨찾기 해제' : '즐겨찾기'),
                  ),
                  const SizedBox(width: 8),

                  // 🗑️ 휴지통(일괄)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: selectedCount == 0 ? null : onTrash,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('휴지통'),
                  ),
                  const SizedBox(width: 8),


          // 이동 버튼
                        TextButton.icon(
                              style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                    onPressed: selectedCount == 0 ? null : onMove,
                    icon: const Icon(Icons.drive_file_move, size: 18),
                    label: const Text('이동'),
                  ),
                  const SizedBox(width: 8),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: selectedCount == 0 ? null : onAddToCart,
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('담기'),
              ),
            ],
          ),
        ),

      ),
    );
  }
}
