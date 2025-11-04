import 'package:flutter/material.dart';
import '../common/qty_control.dart';
import '../common/ui.dart';
// 위쪽에 showQtySetSheet, QtyControl 이미 있음

/// 수량 강제설정 바텀시트 공통 UI
/// 사용처에서는 반환값(int?)으로 새 수량을 받아 delta 계산만 하면 됨.
Future<int?> showQtySetSheet(
    BuildContext context, {
      required int initial,
      String? title,
      String? applyLabel,
      String? cancelLabel,
      String? unit,        // 예: 'EA', 'm' 표시용(선택)
      int? minQtyHint,     // 예: 임계치 배지 출력(선택)
    }) {
  int localQty = initial;

  return showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final t = ctx.t; // 로컬라이즈 확장 쓰고 있으면 그대로
      final theme = Theme.of(ctx);
      return Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSB) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      title ?? t.adjust_set_quantity_title,
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (unit != null) Chip(label: Text(unit)),
                    if (minQtyHint != null) ...[
                      const SizedBox(width: 6),
                      Chip(
                        label: Text('${t.field_threshold}: $minQtyHint'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                QtyControl(
                  value: localQty,
                  onChanged: (v) => setSB(() => localQty = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(cancelLabel ?? t.common_cancel),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.save),
                      onPressed: () => Navigator.pop(ctx, localQty),
                      label: Text(applyLabel ?? t.btn_apply),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
/// 수량 강제설정 전체 플로우:
/// - 시트 띄우기 → 새 수량 입력 받기
/// - 변경 없으면 false 반환
/// - 변경 있으면 apply(delta, newQty) 호출(try/catch 내부)
/// - 성공/실패 스낵바, 성공 시 onSuccess 호출
///
/// 반환: 실제 적용되었으면 true, 아니면 false
Future<bool> runQtySetFlow(
    BuildContext context, {
      required int currentQty,
      String? unit,
      int? minQtyHint,
      String? title,
      String? applyLabel,
      String? cancelLabel,

      /// 실제 반영 로직(예: repo.adjustQty)
      /// delta = newQty - currentQty
      required Future<void> Function(int delta, int newQty) apply,

      /// 성공 시 후처리(예: setState, reload)
      VoidCallback? onSuccess,

      /// 커스텀 스낵바 메시지(없으면 기본)
      String? successMessage,
      String? errorPrefix,
    }) async {
  // 1) 바텀시트로 새 수량 입력
  final newQty = await showQtySetSheet(
    context,
    initial: currentQty,
    unit: unit,
    minQtyHint: minQtyHint,
    title: title,
    applyLabel: applyLabel,
    cancelLabel: cancelLabel,
  );

  if (newQty == null || newQty == currentQty) return false;

  // 2) 적용
  try {
    final delta = newQty - currentQty;
    await apply(delta, newQty);

    // 3) 성공 스낵바 + 후처리
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage ?? '저장되었습니다')),
    );
    onSuccess?.call();
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${errorPrefix ?? '오류'}: $e')),
    );
    return false;
  }
}
