import 'package:flutter/material.dart';
import '../../ui/common/ui.dart';

class StockInOutResult {
  final bool isIn;                 // true=입고, false=출고
  final double enteredQty;         // 사용자가 입력한 수량 (enteredUnit 기준)
  final String enteredUnit;        // 사용자가 입력한 단위 (ex. Roll, EA, M)
  final String targetUnit;         // 실제 재고단위(=아이템 단위) 또는 선택한 출고단위
  final double conversionRate;     // 1 enteredUnit = conversionRate targetUnit
  final String? memo;              // 메모
  final bool updateProfile;        // 이번 설정을 아이템 프로필에 반영할지

  const StockInOutResult({
    required this.isIn,
    required this.enteredQty,
    required this.enteredUnit,
    required this.targetUnit,
    required this.conversionRate,
    this.memo,
    required this.updateProfile,
  });
}

Future<StockInOutResult?> showStockInOutDialog(
    BuildContext context, {
      required bool isIn,
      required String itemUnit,          // 아이템 현재 기본 단위 (ex. M, EA)
      String? unitInHint,                // 기존 unitIn 힌트
      String? unitOutHint,               // 기존 unitOut 힌트
      double? conversionRateHint,       // 기존 환산율 힌트
      int? currentQtyHint, // int/double 앱 스키마에 맞춰서
    }) {
  final formKey = GlobalKey<FormState>();

  // 초기값: 입고는 unitIn, 출고는 unitOut 힌트를 우선 사용
  String enteredUnit = isIn
      ? (unitInHint ?? itemUnit)
      : (unitOutHint ?? itemUnit);
  String targetUnit = itemUnit; // 실제 qty가 적립/차감되는 단위

  final qtyC = TextEditingController(text: '');
  final safeConv = (conversionRateHint ?? 0) > 0 ? conversionRateHint! : 1.0;
  final convC = TextEditingController(text: safeConv.toString());

  final memoC = TextEditingController();
  bool updateProfile = false; // <-- 지역 상태


  double previewTarget() {
    final q = double.tryParse(qtyC.text) ?? 0;
    final c = double.tryParse(convC.text) ?? 1;
    // 1 enteredUnit = c targetUnit
    return q * c;
  }

    int previewNextQtySigned() {
        final delta = previewTarget() * (isIn ? 1 : -1);
        return ((currentQtyHint ?? 0) + delta).round();
      }

  return showDialog<StockInOutResult>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.of(ctx).size.height * 0.8; // 다이얼로그 최대 높이
      final kb = MediaQuery.of(ctx).viewInsets.bottom;    // 키보드 높이

      return AlertDialog(
           insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                 title: Text(isIn ? ctx.t.common_stock_in : ctx.t.common_stock_out),
             content: ConstrainedBox(
               constraints: BoxConstraints(maxHeight: maxH),
               child: SingleChildScrollView(
                 padding: EdgeInsets.only(bottom: kb > 0 ? kb : 0),
                 child: Form(
                   key: formKey,
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
              // 수량
              TextFormField(
                controller: qtyC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isIn ? ctx.t.label_in_qty : ctx.t.label_out_qty,
                  hintText: '예: 3',
                ),
                validator: (v) {
                  final d = double.tryParse((v ?? '').trim());
                  if (d == null || d <= 0) return ctx.t.validate_positive_number;
                  return null;
                },
                onChanged: (_) => (ctx as Element).markNeedsBuild(),
              ),
              const SizedBox(height: 8),

              // 단위 선택 (입력단위)
              DropdownButtonFormField<String>(
                value: enteredUnit,
                items: <String>{
                  enteredUnit, // 현재값 보존
                  unitInHint ?? '',
                  unitOutHint ?? '',
                  itemUnit,
                }
                    .where((e) => e != null && e.trim().isNotEmpty)
                    .cast<String>()
                    .toSet()
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                decoration: InputDecoration(
                  labelText: isIn ? ctx.t.label_in_unit : ctx.t.label_out_unit,
                ),
                onChanged: (v) {
                  if (v == null) return;
                  enteredUnit = v;
                  (ctx as Element).markNeedsBuild();
                },
              ),
              const SizedBox(height: 8),

              // 환산율 (1 입력단위 = ? targetUnit)
              TextFormField(
                controller: convC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ctx.t.label_conversion_rate(enteredUnit, targetUnit),
                  hintText: isIn ? '예: 90 (1 Roll = 90 M)' : '예: 1 (동일단위)',
                ),
                validator: (v) {
                  final d = double.tryParse((v ?? '').trim());
                  if (d == null || d <= 0) return ctx.t.validate_positive_number;
                  return null;
                },
                onChanged: (_) => (ctx as Element).markNeedsBuild(),
              ),

              const SizedBox(height: 12),
              // 미리보기
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             isIn
                                 ? '미리보기: +${previewTarget().toStringAsFixed(2)} $targetUnit'
                                 : '미리보기: -${previewTarget().toStringAsFixed(2)} $targetUnit',
                             style: Theme.of(ctx).textTheme.bodyMedium,
                           ),
                           const SizedBox(height: 4),
                           if (currentQtyHint != null) // ✅ 이 위치가 중요함: children 리스트 안에서만 가능
                             Text(
                               '변경 후 재고: ${previewNextQtySigned()} $targetUnit',
                               style: Theme.of(ctx).textTheme.bodyMedium,
                             ),
                         ],
                       ),


                       const SizedBox(height: 8),
              TextFormField(
                controller: memoC,
                decoration: InputDecoration(
                  labelText: ctx.t.field_memo_optional,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),

              // 프로필 반영 체크
                       StatefulBuilder(
                         builder: (ctx2, setSB) => CheckboxListTile(
                           contentPadding: EdgeInsets.zero,
                           value: updateProfile,
                           onChanged: (v) => setSB(() => updateProfile = v ?? false),
                           title: const Text('이번 단위/환산 설정을 아이템 프로필에 반영'),
                           controlAffinity: ListTileControlAffinity.leading,
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
                 ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(ctx.t.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final entered = double.tryParse(qtyC.text.trim())!;
              final conv = double.tryParse(convC.text.trim())!;
              Navigator.pop(
                ctx,
                StockInOutResult(
                  isIn: isIn,
                  enteredQty: entered,
                  enteredUnit: enteredUnit,
                  targetUnit: targetUnit,
                  conversionRate: conv,
                  memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),
                  updateProfile: updateProfile, // ← 여기!
                ),
              );
            },
            child: Text(ctx.t.btn_apply),
          ),
        ],
      );
    },
  );
}
