import '../models/fabric_cutting_project.dart';
import '../models/fabric_cutting_result.dart';

class FabricCuttingCalculator {
  const FabricCuttingCalculator();

  FabricCuttingResult calculate(FabricCuttingProject project) {
    final quantity = project.quantity < 1 ? 1 : project.quantity;
    final fabricWidth =
        project.fabricWidthCm <= 0 ? 1.0 : project.fabricWidthCm;
    final finishedWidth = project.pieces.fold<double>(
      0,
      (sum, piece) => sum + piece.finishedWidthCm,
    );

    final results = project.pieces.map((piece) {
      final rawPerColumn =
          piece.widthCm <= 0 ? 0 : fabricWidth ~/ piece.widthCm;
      final fits = rawPerColumn > 0;
      final piecesPerColumn = fits ? rawPerColumn : 1;
      final columnsNeeded = (quantity / piecesPerColumn).ceil();
      final usedWidth = fits ? piecesPerColumn * piece.widthCm : piece.widthCm;

      return FabricPieceCuttingResult(
        piece: piece,
        piecesPerColumn: fits ? piecesPerColumn : 0,
        columnsNeeded: columnsNeeded,
        requiredLengthCm: columnsNeeded * piece.lengthCm,
        remainingWidthCm:
            (fabricWidth - usedWidth).clamp(0, double.infinity).toDouble(),
        fitsInFabricWidth: fits,
      );
    }).toList();

    return FabricCuttingResult(
      quantity: quantity,
      fabricWidthCm: fabricWidth,
      finishedWidthCm: finishedWidth,
      pieceResults: results,
    );
  }
}
