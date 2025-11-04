import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  );
  if (res == null) return false;

  final signedDelta = (res.enteredQty * res.conversionRate) * (isIn ? 1 : -1);

  final itemRepo = context.read<ItemRepo>();
  await itemRepo.adjustQty(
    itemId: item.id,
    delta: signedDelta.round(), // 내부 qty가 int라면 round 유지
    refType: 'MANUAL',
    note: [
      isIn ? '입고' : '출고',
      '(${res.enteredUnit} → ${res.targetUnit}, x${res.conversionRate})',
      if (res.memo != null) '[${res.memo}]',
    ].join(' '),
  );

  if (res.updateProfile && updateProfile != null) {
    await updateProfile(
      itemId: item.id,
      unitIn: isIn ? res.enteredUnit : item.unitIn,
      unitOut: isIn ? item.unitOut : res.enteredUnit,
      conversionRate: res.conversionRate,
    );
  }

  return true;
}
