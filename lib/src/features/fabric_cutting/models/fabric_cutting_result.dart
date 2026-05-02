import 'fabric_piece.dart';

class FabricPieceCuttingResult {
  final FabricPiece piece;
  final int piecesPerColumn;
  final int columnsNeeded;
  final double requiredLengthCm;
  final double remainingWidthCm;
  final bool fitsInFabricWidth;

  const FabricPieceCuttingResult({
    required this.piece,
    required this.piecesPerColumn,
    required this.columnsNeeded,
    required this.requiredLengthCm,
    required this.remainingWidthCm,
    required this.fitsInFabricWidth,
  });
}

class FabricCuttingResult {
  final int quantity;
  final double fabricWidthCm;
  final double finishedWidthCm;
  final List<FabricPieceCuttingResult> pieceResults;

  const FabricCuttingResult({
    required this.quantity,
    required this.fabricWidthCm,
    required this.finishedWidthCm,
    required this.pieceResults,
  });
}
