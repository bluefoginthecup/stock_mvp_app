import 'package:flutter/material.dart';
import '../../../models/item.dart';
import '../../../models/storage_location.dart';
import '../../../utils/item_registration.dart';

class StockItemSelectTile extends StatelessWidget {
  final Item item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap; // 일반 모드 탭(상세로)
  final VoidCallback onLongPress; // 롱프레스 → 선택모드 진입
  final VoidCallback onTogglePick; // 선택 토글
  final ItemLocationSummary? locationSummary;
  final VoidCallback? onTapLocation;

  const StockItemSelectTile({
    super.key,
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onTogglePick,
    this.locationSummary,
    this.onTapLocation,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.displayName ?? item.name;
    final needsReview = isNeedsRegistrationItem(item);
    final stockText = '재고: ${item.qty} ${item.unit}'
        '${needsReview ? ' · 정식등록 필요' : ''}';
    final locationText = _locationText(locationSummary);
    final locationColor = locationSummary?.hasLocation == true
        ? Theme.of(context).colorScheme.primary
        : Colors.black45;

    return ListTile(
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onTogglePick())
          : const Icon(Icons.inventory_2_outlined),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16, // ← 기존보다 +2 정도
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stockText,
            style: TextStyle(
              fontSize: 14, // 기본 12~13 -> 14로
              color: needsReview ? Colors.deepOrange.shade700 : Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: locationSummary?.hasLocation == true ? onTapLocation : null,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: locationColor),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    locationText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: locationColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      dense: true,
      // ⭐/⋮ 제거 → trailing 없음
      onTap: selectionMode ? onTogglePick : onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  String _locationText(ItemLocationSummary? summary) {
    if (summary == null || !summary.hasLocation) return '위치 미지정';
    final path = summary.primaryLocationPath ??
        summary.primaryLocation?.name ??
        '위치 미지정';
    if (summary.extraLocationCount <= 0) return path;
    return '$path 외 ${summary.extraLocationCount}곳';
  }
}
