import 'package:flutter/material.dart';

import '../models/fabric_cutting_result.dart';

class FabricResultSummary extends StatelessWidget {
  final FabricCuttingResult result;

  const FabricResultSummary({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final formula = result.pieceResults
        .map((e) =>
            '(${_fmt(e.piece.widthCm)}-${_fmt(e.piece.seamAllowanceCm)})')
        .join(' + ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('계산 결과', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _MetricRow(
              label: '제품 완성폭',
              value: '${_fmt(result.finishedWidthCm)}cm',
              emphasize: true,
            ),
            _MetricRow(label: '제작 개수', value: '${result.quantity}개'),
            _MetricRow(label: '원단폭', value: '${_fmt(result.fabricWidthCm)}cm'),
            const Divider(height: 24),
            Text(
              formula.isEmpty
                  ? '원단을 추가하면 완성폭 계산식이 표시됩니다.'
                  : '$formula = ${_fmt(result.finishedWidthCm)}cm',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _MetricRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

String _fmt(double n) => n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
