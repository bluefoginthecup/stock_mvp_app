import 'package:flutter/material.dart';

/// ── ID 4자리 요약 (…a511)
String shortId(String id) {
  if (id.isEmpty) return '';
  final tail = id.length >= 4 ? id.substring(id.length - 4) : id;
  return '…$tail';
}

/// ── 상태 배지 위젯
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

/// ── 날짜 포맷 (YYYY-MM-DD HH:MM)
String fmtYmdHm(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

/// ── 공통 삭제 확인 다이얼로그
Future<bool> confirmDelete(
    BuildContext ctx, {
      required String title,
      required String message,
      String confirmLabel = '삭제',
      String cancelLabel = '취소',
    }) async {
  return await showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  ) ??
      false;
}

/// ── Undo 스낵바
void showUndoSnackBar(
    BuildContext ctx, {
      required String message,
      required VoidCallback onUndo,
      int seconds = 5,
      String undoLabel = '되돌리기',
    }) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
      duration: Duration(seconds: seconds),
    ),
  );
}
