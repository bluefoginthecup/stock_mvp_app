import 'package:flutter/material.dart';
import '../../models/types.dart';

/// 입·출고 수량 뱃지
/// - planned(예정): 회색
/// - actual(실제): 입고=초록, 출고=빨강
class QtyBadge extends StatelessWidget {
  final int qty;
  final TxnType direction;   // in_ / out_
  final TxnStatus status;    // planned / actual
  final bool showSign;
  final bool compact;

  const QtyBadge({
    super.key,
    required this.qty,
    required this.direction,
    required this.status,
    this.showSign = true,
    this.compact = true,
  }) : assert(qty > 0);

  @override
  Widget build(BuildContext context) {
    final isIn = direction == TxnType.in_;
    final sign = showSign ? (isIn ? '+' : '-') : '';

    // ✅ 색상 규칙
    final color = switch (status) {
      TxnStatus.planned => Colors.grey,         // 작업등록(예정)
      TxnStatus.actual =>
      isIn ? Colors.green : Colors.red,     // 입고/출고 실제
    };

    final label = '$sign$qty';

    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}
