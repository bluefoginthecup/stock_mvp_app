import 'roll_cut_item.dart';
import 'roll_fabric_plan.dart';

enum RollOptimizationMode {
  empty,
  sameWidthLane,
  mixedWidthHeuristic,
  grouped,
}

class RollFabricOptimizationResult {
  final RollFabricPlan roll;
  final RollOptimizationMode mode;
  final bool possible;
  final double totalLengthCm;
  final double usedLengthCm;
  final double groupedLengthCm;
  final double remainLengthCm;
  final double savedLengthCm;
  final double laneWidthCm;
  final int laneCount;
  final double widthRemainCm;
  final List<RollLaneResult> lanes;
  final List<RollCutSummary> cutSummaries;

  const RollFabricOptimizationResult({
    required this.roll,
    required this.mode,
    required this.possible,
    required this.totalLengthCm,
    required this.usedLengthCm,
    required this.groupedLengthCm,
    required this.remainLengthCm,
    required this.savedLengthCm,
    required this.laneWidthCm,
    required this.laneCount,
    required this.widthRemainCm,
    required this.lanes,
    required this.cutSummaries,
  });

  bool get optimizedByLane => mode == RollOptimizationMode.sameWidthLane;

  bool get optimizedByMixedWidth =>
      mode == RollOptimizationMode.mixedWidthHeuristic;

  bool get optimized => optimizedByLane || optimizedByMixedWidth;
}

class RollLaneResult {
  final double lengthCm;
  final List<RollPlacedCut> items;

  const RollLaneResult({
    required this.lengthCm,
    required this.items,
  });
}

class RollPlacedCut {
  final RollCutItem cut;
  final int cutIndex;
  final double xCm;
  final double yCm;
  final double widthCm;
  final double lengthCm;

  const RollPlacedCut({
    required this.cut,
    required this.cutIndex,
    required this.xCm,
    required this.yCm,
    required this.widthCm,
    required this.lengthCm,
  });
}

class RollCutSummary {
  final RollCutItem cut;
  final int piecesPerColumn;
  final int columnsNeeded;
  final int placedQuantity;
  final double requiredLengthCm;
  final double remainingWidthCm;

  const RollCutSummary({
    required this.cut,
    required this.piecesPerColumn,
    required this.columnsNeeded,
    required this.placedQuantity,
    required this.requiredLengthCm,
    required this.remainingWidthCm,
  });
}
