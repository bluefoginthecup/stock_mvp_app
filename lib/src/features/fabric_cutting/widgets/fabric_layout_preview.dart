import 'package:flutter/material.dart';

import '../models/fabric_cutting_result.dart';

class FabricLayoutPreview extends StatelessWidget {
  final FabricCuttingResult result;

  const FabricLayoutPreview({
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
            Text('배치도', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '가로는 원단 길이, 세로는 원단폭입니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...result.pieceResults.map(
              (pieceResult) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _PieceLayout(result: result, pieceResult: pieceResult),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceLayout extends StatelessWidget {
  final FabricCuttingResult result;
  final FabricPieceCuttingResult pieceResult;

  const _PieceLayout({
    required this.result,
    required this.pieceResult,
  });

  @override
  Widget build(BuildContext context) {
    final piece = pieceResult.piece;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: piece.color,
                borderRadius: BorderRadius.circular(4),
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
            Text(
                '${_fmt(pieceResult.requiredLengthCm)}×${_fmt(result.fabricWidthCm)}cm'),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final scaleX = maxWidth /
                pieceResult.requiredLengthCm.clamp(1, double.infinity);
            final scaleY = 230 / result.fabricWidthCm.clamp(1, double.infinity);
            final scale = scaleX < scaleY ? scaleX : scaleY;
            final width = pieceResult.requiredLengthCm * scale;
            final height = result.fabricWidthCm * scale;

            return Center(
              child: SizedBox(
                width: width,
                height: height + 24,
                child: CustomPaint(
                  painter: _FabricLayoutPainter(
                    result: result,
                    pieceResult: pieceResult,
                    scale: scale,
                    textColor: _readableTextColor(piece.color),
                  ),
                ),
              ),
            );
          },
        ),
        if (!pieceResult.fitsInFabricWidth)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '재단 폭이 원단폭보다 큽니다. 폭 값을 확인해주세요.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _FabricLayoutPainter extends CustomPainter {
  final FabricCuttingResult result;
  final FabricPieceCuttingResult pieceResult;
  final double scale;
  final Color textColor;

  const _FabricLayoutPainter({
    required this.result,
    required this.pieceResult,
    required this.scale,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final piece = pieceResult.piece;
    final border = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()
      ..color = piece.color
      ..style = PaintingStyle.fill;
    final empty = Paint()
      ..color = piece.color.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final rollWidth = pieceResult.requiredLengthCm * scale;
    final rollHeight = result.fabricWidthCm * scale;
    final outer = Rect.fromLTWH(0, 18, rollWidth, rollHeight);
    canvas.drawRect(outer, Paint()..color = Colors.white);
    canvas.drawRect(outer, border);

    final columnWidth = piece.lengthCm * scale;
    final pieceHeight = piece.widthCm * scale;
    var done = 0;

    for (var col = 0; col < pieceResult.columnsNeeded; col++) {
      final left = col * columnWidth;
      final count =
          pieceResult.fitsInFabricWidth ? pieceResult.piecesPerColumn : 1;
      for (var row = 0; row < count; row++) {
        final hasPiece = done < result.quantity;
        final top = 18 + row * pieceHeight;
        final rect = Rect.fromLTWH(left, top, columnWidth, pieceHeight);
        canvas.drawRect(rect, hasPiece ? fill : empty);
        canvas.drawRect(rect, border);
        if (hasPiece && columnWidth > 28 && pieceHeight > 18) {
          _drawCenteredText(
            canvas,
            rect,
            '${piece.name}\n${_fmt(piece.lengthCm)}×${_fmt(piece.widthCm)}',
            textColor,
          );
        }
        if (hasPiece) done++;
      }

      if (pieceResult.remainingWidthCm > 0.01 &&
          pieceResult.fitsInFabricWidth) {
        final remainTop = 18 + count * pieceHeight;
        final remainRect = Rect.fromLTWH(
          left,
          remainTop,
          columnWidth,
          pieceResult.remainingWidthCm * scale,
        );
        canvas.drawRect(remainRect, empty);
        canvas.drawRect(remainRect, border);
      }
    }

    _drawAxisText(canvas, Offset(0, 0), '길이 ${_fmt(piece.lengthCm)}cm 단위');
    _drawAxisText(canvas, Offset(rollWidth - 78, rollHeight + 21),
        '폭 ${_fmt(result.fabricWidthCm)}cm');
  }

  void _drawCenteredText(Canvas canvas, Rect rect, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9, height: 1.15),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: rect.width - 4);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _drawAxisText(Canvas canvas, Offset offset, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black54, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FabricLayoutPainter oldDelegate) {
    return oldDelegate.result != result ||
        oldDelegate.pieceResult != pieceResult ||
        oldDelegate.scale != scale;
  }
}

Color _readableTextColor(Color color) {
  final brightness = ThemeData.estimateBrightnessForColor(color);
  return brightness == Brightness.dark ? Colors.white : Colors.black87;
}

String _fmt(double n) => n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
