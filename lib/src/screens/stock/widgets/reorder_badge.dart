import 'package:flutter/material.dart';

import '../../../models/item.dart';
import '../../../utils/reorder_schedule_utils.dart';

class ReorderBadge extends StatelessWidget {
  final Item item;
  final bool dense;

  const ReorderBadge({
    super.key,
    required this.item,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = ReorderScheduleUtils.statusFor(item);
    if (!status.shouldShow) return const SizedBox.shrink();
    final color = status.overdue
        ? Colors.deepOrange.shade700
        : Theme.of(context).colorScheme.primary;
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      avatar: Icon(Icons.event_repeat, size: dense ? 14 : 16, color: color),
      label: Text(
        status.label,
        style: TextStyle(
          fontSize: dense ? 11 : 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}
