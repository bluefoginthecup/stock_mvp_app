import 'package:flutter/material.dart';

import '../models/fabric_cutting_result.dart';

class FabricCuttingTable extends StatelessWidget {
  final FabricCuttingResult result;

  const FabricCuttingTable({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (result.pieceResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('재단 수량표', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...result.pieceResults.map((item) {
              final piece = item.piece;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: piece.color,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            piece.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text('${_fmt(item.requiredLengthCm)}cm 필요'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.fitsInFabricWidth
                          ? '${_fmt(piece.widthCm)}×${_fmt(piece.lengthCm)}cm × ${result.quantity}장 / 한 칸 ${item.piecesPerColumn}장 / ${item.columnsNeeded}칸'
                          : '원단 폭보다 재단 폭이 커서 배치 확인이 필요합니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

String _fmt(double n) => n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
