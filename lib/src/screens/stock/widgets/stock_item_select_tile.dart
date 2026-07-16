import 'package:flutter/material.dart';
import '../../../models/item.dart';
import '../../../models/storage_location.dart';
import '../../../utils/item_registration.dart';
import '../../../utils/reorder_schedule_utils.dart';
import 'reorder_badge.dart';

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
    final pathText = _pathText(item);
    final locationText = _locationText(locationSummary);
    final locationColor = locationSummary?.hasLocation == true
        ? Theme.of(context).colorScheme.primary
        : Colors.black45;
    final stockChipColor = needsReview
        ? Colors.deepOrange.shade700
        : Theme.of(context).colorScheme.primary;

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
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 14, color: Colors.black45),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  pathText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
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
                    '위치: $locationText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: locationColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (needsReview) ...[
            const SizedBox(height: 2),
            Text(
              '정식등록 필요',
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepOrange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (ReorderScheduleUtils.effectiveNextReorderDate(item) != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.event_repeat, size: 14, color: Colors.black45),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    '다음 발주: ${_formatDate(ReorderScheduleUtils.effectiveNextReorderDate(item)!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
          ReorderBadge(item: item, dense: true),
        ],
      ),
      trailing: selectionMode
          ? null
          : _StockQtyChip(
              qty: item.qty,
              unit: item.unit,
              color: stockChipColor,
            ),
      dense: true,
      onTap: selectionMode ? onTogglePick : onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  String _pathText(Item item) {
    final names = <String>[
      item.folder,
      if ((item.subfolder ?? '').trim().isNotEmpty) item.subfolder!.trim(),
      if ((item.subsubfolder ?? '').trim().isNotEmpty)
        item.subsubfolder!.trim(),
    ].where((name) => name.trim().isNotEmpty).toList();
    return names.isEmpty ? '경로 없음' : names.join(' > ');
  }

  String _locationText(ItemLocationSummary? summary) {
    if (summary == null || !summary.hasLocation) return '위치 미지정';
    final path = summary.primaryLocationPath ??
        summary.primaryLocation?.name ??
        '위치 미지정';
    final qtyText = summary.primaryQty > 0 ? ' · ${summary.primaryQty}개' : '';
    if (summary.extraLocationCount <= 0) return '$path$qtyText';
    return '$path$qtyText 외 ${summary.extraLocationCount}곳';
  }

  String _formatDate(DateTime value) {
    final d = ReorderScheduleUtils.dateOnly(value);
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}

class _StockQtyChip extends StatelessWidget {
  const _StockQtyChip({
    required this.qty,
    required this.unit,
    required this.color,
  });

  final int qty;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$qty',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          if (unit.trim().isNotEmpty)
            Text(
              unit.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: 0.82),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}
