//위젯: 주문아이디 4자리 요약

import 'package:flutter/material.dart';

String shortId(String id) {
  if (id.isEmpty) return '';
  final tail = id.length >= 4 ? id.substring(id.length - 4) : id;
  return '…$tail'; // 예: …a511
}

// 위젯 2) 뱃지(진행중...등등)
Widget badge(String text, Color color, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.30)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
      ],
      Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.1)),
    ]),
  );
}
//3) 위젯 날짜표시
String fmtYmdHm(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
