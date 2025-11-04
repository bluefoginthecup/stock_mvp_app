import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/common/ui.dart';

import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../screens/stock/stock_inout_dialog.dart';

typedef UpdateProfileFn = Future<void> Function({
required String itemId,
String? unitIn,
String? unitOut,
double? conversionRate,
});

/// 입·출고 공용 플로우:
/// - 다이얼로그를 띄워 입력 받음
/// - delta 계산(+입고 / -출고)
/// - ItemRepo.adjustQty() 호출
/// - (선택) 단위/환산 프로필 업데이트
/// 반환: 변경이 있었으면 true
Future<bool> runStockInOutFlow(
    BuildContext context, {
      required bool isIn,
      required Item item,
      UpdateProfileFn? updateProfile, // 없으면 무시
    }) async {
  final res = await showStockInOutDialog(
    context,
    isIn: isIn,
    itemUnit: item.unit,
    unitInHint: item.unitIn,
    unitOutHint: item.unitOut,
    conversionRateHint: item.conversionRate,
    currentQtyHint: item.qty, // ← 추가
  );
  if (res == null) return false;

  final signedDelta = (res.enteredQty * res.conversionRate) * (isIn ? 1 : -1);
  final deltaRounded = signedDelta.round();
  final nextQty = item.qty +  signedDelta.round();

  // ❗ 출고 시 마이너스 방지: Snackbar로 안내 후 취소
    if (!isIn && nextQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('출고 불가: 현재 재고(${item.qty}${item.unit})보다 많이 출고할 수 없습니다.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

  final itemRepo = context.read<ItemRepo>();
  await itemRepo.adjustQty(
    itemId: item.id,
       delta: deltaRounded,
    refType: 'MANUAL',
    memo: res.memo, // ✅ 메모 전달
    note: [
      isIn ? '입고' : '출고',
      '(${res.enteredUnit} → ${res.targetUnit}, x${res.conversionRate})',
      if (res.memo != null) '[${res.memo}]',
    ].join(' '),
  );

   // ✅ 입·출고 완료 스낵바
   final absDelta = deltaRounded.abs();
   final doneMsg = isIn
       ? '입고 완료: $absDelta ${item.unit} (현재 재고 ${nextQty}${item.unit})'
       : '출고 완료: -$absDelta ${item.unit} (현재 재고 ${nextQty}${item.unit})';
   ScaffoldMessenger.of(context)
     ..hideCurrentSnackBar()
     ..showSnackBar(
       SnackBar(
         content: Text(doneMsg),
         behavior: SnackBarBehavior.floating,
         duration: const Duration(seconds: 2),
       ),
     );

  if (res.updateProfile && updateProfile != null) {
    await updateProfile(
      itemId: item.id,
      unitIn: isIn ? res.enteredUnit : item.unitIn,
      unitOut: isIn ? item.unitOut : res.enteredUnit,
      conversionRate: res.conversionRate,
    );


    // ✅ 변경된 단위/환산 정보까지 함께 표시
    final msg = StringBuffer('단위/환산 프로필이 업데이트되었습니다: ');
    if (res.enteredUnit.isNotEmpty && res.targetUnit.isNotEmpty) {
      msg.write('1 ${res.enteredUnit} = ${res.conversionRate} ${res.targetUnit}');
    } else {
      msg.write('환산율 ${res.conversionRate}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toString()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  return true;
}
