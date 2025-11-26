// import 'package:flutter/material.dart';
// import '../../../models/item.dart';
//
// class StockItemSelectTile extends StatelessWidget {
//   final Item item;
//   final bool selectionMode;
//   final bool selected;
//   final VoidCallback onTap;           // 일반 모드 탭(상세로)
//   final VoidCallback onLongPress;     // 롱프레스 → 선택모드 진입
//   final VoidCallback onTogglePick;    // 선택 토글
//   final VoidCallback? onToggleFavorite; // 즐겨찾기 토글
//
//   // 👇 신규: 부모에서 실제 처리 (이동/삭제)
//   final VoidCallback? onRequestMove;
//   final VoidCallback? onRequestTrash;
//
//   const StockItemSelectTile({
//     super.key,
//     required this.item,
//     required this.selectionMode,
//     required this.selected,
//     required this.onTap,
//     required this.onLongPress,
//     required this.onTogglePick,
//     this.onToggleFavorite,
//     this.onRequestMove,
//     this.onRequestTrash,
//   });
//


//   @override
//   Widget build(BuildContext context) {
//     final title = item.displayName ?? item.name;
//
//     Future<void> _confirmTrash() async {
//       final ok = await showDialog<bool>(
//         context: context,
//         builder: (d) => AlertDialog(
//           title: const Text('삭제(휴지통)'),
//           content: Text('‘$title’을(를) 휴지통으로 이동할까요?'),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
//             TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('이동')),
//           ],
//         ),
//       );
//       if (ok == true) {
//         if (onRequestTrash != null) {
//           onRequestTrash!();
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('처리 핸들러가 연결되지 않았습니다.')),
//           );
//         }
//       }
//     }
//
//     return ListTile(
//       leading: selectionMode
//           ? Checkbox(value: selected, onChanged: (_) => onTogglePick())
//           : const Icon(Icons.inventory_2_outlined),
//       title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
//       subtitle: Text('재고: ${item.qty} ${item.unit}'),
//       trailing: selectionMode
//           ? null
//           : Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // ★ 즐겨찾기
//           IconButton(
//             tooltip: (item.isFavorite == true) ? '즐겨찾기 해제' : '즐겨찾기 추가',
//             constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
//             padding: const EdgeInsets.all(4),
//             icon: Icon(
//               (item.isFavorite == true) ? Icons.star : Icons.star_border,
//               size: 20,
//             ),
//             onPressed: () {
//               final next = !(item.isFavorite == true);
//               debugPrint('[Tile] ⭐ tap → id=${item.id}, "$title", next=$next');
//               onToggleFavorite?.call();
//             },
//           ),
//           // ⋮ 더보기
//           PopupMenuButton<String>(
//             tooltip: '더보기',
//             onSelected: (v) async {
//               switch (v) {
//                 case 'move':
//                   if (onRequestMove != null) {
//                     onRequestMove!();
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('이동 핸들러가 연결되지 않았습니다.')),
//                     );
//                   }
//                   break;
//                 case 'trash':
//                   await _confirmTrash();
//                   break;
//               }
//             },
//             itemBuilder: (_) => const [
//               PopupMenuItem(value: 'move', child: Text('아이템 이동')),
//               PopupMenuItem(value: 'trash', child: Text('삭제(휴지통)')),
//             ],
//             icon: const Icon(Icons.more_vert),
//           ),
//         ],
//       ),
//       onTap: selectionMode ? onTogglePick : onTap,
//       onLongPress: onLongPress,
//     );
//   }
// }
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
