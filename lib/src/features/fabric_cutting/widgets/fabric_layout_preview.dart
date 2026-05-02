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
              '${_fmt(pieceResult.requiredLengthCm)}×${_fmt(result.fabricWidthCm)}cm',
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _showFullscreenLayout(context),
            icon: const Icon(Icons.open_in_full, size: 18),
            label: const Text('전체화면 보기'),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                (constraints.maxWidth - _FabricLayoutPainter.sideLabelWidth)
                    .clamp(120, double.infinity)
                    .toDouble();
            final scaleX = maxWidth /
                pieceResult.requiredLengthCm.clamp(1, double.infinity);
            final scaleY = 230 / result.fabricWidthCm.clamp(1, double.infinity);
            final scale = scaleX < scaleY ? scaleX : scaleY;
            final width = pieceResult.requiredLengthCm * scale;
            final height = result.fabricWidthCm * scale;
            final canvasWidth = width + _FabricLayoutPainter.sideLabelWidth;

            return Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showFullscreenLayout(context),
                child: SizedBox(
                  width: canvasWidth,
                  height: height + _FabricLayoutPainter.topOffset + 24,
                  child: CustomPaint(
                    painter: _FabricLayoutPainter(
                      result: result,
                      pieceResult: pieceResult,
                      scale: scale,
                      textColor: _readableTextColor(piece.color),
                    ),
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

  void _showFullscreenLayout(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF111111),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _FabricFullscreenViewer(
                    result: result,
                    pieceResult: pieceResult,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 16,
                  right: 64,
                  child: Text(
                    '${pieceResult.piece.name} 배치도',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    tooltip: '닫기',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FabricFullscreenViewer extends StatelessWidget {
  final FabricCuttingResult result;
  final FabricPieceCuttingResult pieceResult;

  const _FabricFullscreenViewer({
    required this.result,
    required this.pieceResult,
  });

  @override
  Widget build(BuildContext context) {
    const detailScale = 4.0;
    final piece = pieceResult.piece;
    final width = pieceResult.requiredLengthCm * detailScale +
        _FabricLayoutPainter.sideLabelWidth;
    final height = result.fabricWidthCm * detailScale +
        _FabricLayoutPainter.topOffset +
        24;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(900),
      minScale: 0.15,
      maxScale: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _FabricLayoutPainter(
                result: result,
                pieceResult: pieceResult,
                scale: detailScale,
                textColor: _readableTextColor(piece.color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FabricLayoutPainter extends CustomPainter {
  static const topOffset = 28.0;
  static const sideLabelWidth = 60.0;

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
    final outer =
        Rect.fromLTWH(sideLabelWidth, topOffset, rollWidth, rollHeight);
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
        final top = topOffset + row * pieceHeight;
        final rect =
            Rect.fromLTWH(sideLabelWidth + left, top, columnWidth, pieceHeight);
        canvas.drawRect(rect, hasPiece ? fill : empty);
        canvas.drawRect(rect, border);
        if (hasPiece && columnWidth > 28 && pieceHeight > 18) {
          _drawCenteredText(
            canvas,
            rect,
            '${piece.name}\n${_fmt(piece.lengthCm)}×${_fmt(piece.widthCm)}',
            textColor,
            fontSize: scale >= 3 ? 15 : 11,
          );
        }
        if (hasPiece) done++;
      }

      if (pieceResult.remainingWidthCm > 0.01 &&
          pieceResult.fitsInFabricWidth) {
        final remainTop = topOffset + count * pieceHeight;
        final remainRect = Rect.fromLTWH(
          sideLabelWidth + left,
          remainTop,
          columnWidth,
          pieceResult.remainingWidthCm * scale,
        );
        canvas.drawRect(remainRect, empty);
        canvas.drawRect(remainRect, border);
      }
    }

    _drawAxisText(
      canvas,
      Offset(sideLabelWidth, 0),
      '길이 ${_fmt(piece.lengthCm)}cm / ${pieceResult.columnsNeeded}개씩',
      maxWidth: rollWidth,
    );
    _drawAxisText(
      canvas,
      Offset(0, topOffset + rollHeight / 2 - 16),
      '폭\n${_fmt(result.fabricWidthCm)}cm\n${pieceResult.piecesPerColumn}개씩',
      maxWidth: sideLabelWidth,
      textAlign: TextAlign.center,
    );
  }

  void _drawCenteredText(
    Canvas canvas,
    Rect rect,
    String text,
    Color color, {
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, height: 1.15),
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

  void _drawAxisText(
    Canvas canvas,
    Offset offset,
    String text, {
    double maxWidth = 120,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: scale >= 3 ? 18 : 13,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
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
