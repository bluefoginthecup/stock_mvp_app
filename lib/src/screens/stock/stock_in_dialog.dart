// lib/src/screens/txns/stock_in_dialog.dart
import 'package:flutter/material.dart';
import '../../models/item.dart';

class StockInDialog extends StatefulWidget {
  final Item item;
  const StockInDialog({super.key, required this.item});

  @override
  State<StockInDialog> createState() => _StockInDialogState();
}

class _StockInDialogState extends State<StockInDialog> {
  // 한 군데만 정의해서 재사용
  static const kUnits = ['EA', 'm', 'roll', 'cone'];

  bool isBulk = false;
  String unitIn = '';
  String unitOut = '';
  double enteredQtyIn = 0;
  double conversionRate = 1;

  @override
  void initState() {
    super.initState();
    unitOut = widget.item.unit ?? 'm';
    unitIn = unitOut; // 기본값: 출고단위와 동일

    // ✅ 안전장치: value가 리스트에 없으면 첫 항목으로 보정
    if (!kUnits.contains(unitIn)) unitIn = kUnits.first;
    if (!kUnits.contains(unitOut)) unitOut = kUnits.first;
  }

  // ✅ 총 입고량(출고 단위 기준) 계산
  double get totalOutQty => isBulk ? (enteredQtyIn * conversionRate) : enteredQtyIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('입고 등록'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 모드 선택
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('낱개 입고'),
                    value: false,
                    groupValue: isBulk,
                    onChanged: (v) => setState(() => isBulk = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('벌크 입고'),
                    value: true,
                    groupValue: isBulk,
                    onChanged: (v) => setState(() {
                      isBulk = v!;
                      // UX 보정: 벌크 전환 시 입고단위가 m이면 roll로 제안
                      if (isBulk && unitIn == 'm') unitIn = 'roll';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 입고 단위 선택
            Row(
              children: [
                SizedBox(width: 80, child: Text('입고 단위', style: theme.textTheme.bodyMedium)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: unitIn,
                    items: kUnits
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => unitIn = v ?? unitIn),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 입고 수량 입력
            TextField(
              decoration: const InputDecoration(labelText: '입고 수량'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => enteredQtyIn = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 12),

            // 환산식 (벌크일 때만)
            if (isBulk) ...[
              Row(
                children: [
                  Text('환산식', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),

// 수정
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6, // 줄바꿈 시 세로 간격
                      children: [
                        const Text('1'),
                        DropdownButton<String>(
                          isDense: true,                // 높이/폭 축소
                          underline: const SizedBox(),  // 밑줄 제거로 높이 절약
                          value: unitIn,
                          items: kUnits
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => unitIn = v ?? unitIn),
                        ),
                        const Text('='),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            decoration: const InputDecoration(isDense: true, hintText: '예: 30'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => setState(() => conversionRate = double.tryParse(v) ?? 1),
                          ),
                        ),
                        Text(unitOut),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 총 입고량 미리보기
            Text(
              '총 입고량: ${totalOutQty.toStringAsFixed(2)} $unitOut',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('입고 완료'),
          onPressed: () {
            Navigator.pop(context, {
              'enteredQtyIn': enteredQtyIn,
              'unitIn': unitIn,
              'unitOut': unitOut,
              'conversionRate': conversionRate,
              'isBulk': isBulk,
            });
          },
        ),
      ],
    );
  }
}
