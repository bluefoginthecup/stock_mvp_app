import 'dart:math' as math;

import '../models/roll_cut_item.dart';
import '../models/roll_fabric_optimization_result.dart';
import '../models/roll_fabric_plan.dart';

class RollFabricOptimizer {
  const RollFabricOptimizer();

  List<RollFabricOptimizationResult> optimizeAll(List<RollFabricPlan> rolls) {
    return rolls.map(optimize).toList();
  }

  RollFabricOptimizationResult optimize(RollFabricPlan roll) {
    final cuts = roll.cuts
        .map(
          (cut) => cut.copyWith(
            widthCm: cut.widthCm <= 0 ? 0.1 : cut.widthCm,
            lengthCm: cut.lengthCm <= 0 ? 0.1 : cut.lengthCm,
            quantity: cut.quantity < 1 ? 1 : cut.quantity,
          ),
        )
        .toList();

    if (cuts.isEmpty) {
      return RollFabricOptimizationResult(
        roll: roll,
        optimizedByLane: false,
        possible: true,
        totalLengthCm: roll.totalLengthCm,
        usedLengthCm: 0,
        remainLengthCm: roll.totalLengthCm,
        savedLengthCm: 0,
        laneWidthCm: 0,
        laneCount: 0,
        widthRemainCm: roll.widthCm,
        lanes: const [],
        cutSummaries: const [],
      );
    }

    final firstWidth = cuts.first.widthCm;
    final sameWidth =
        cuts.every((cut) => (cut.widthCm - firstWidth).abs() < 0.0001);
    if (sameWidth) {
      final laneResult = _optimizeSameWidth(roll, cuts, firstWidth);
      if (laneResult != null) return laneResult;
    }

    return _groupByCut(roll, cuts);
  }

  RollFabricOptimizationResult? _optimizeSameWidth(
    RollFabricPlan roll,
    List<RollCutItem> cuts,
    double cutWidth,
  ) {
    final laneCount = math.max(1, roll.widthCm ~/ cutWidth);
    final plan = _solveLanePlan(cuts, laneCount);
    if (plan == null) return null;

    final usedLength = plan.map((lane) => _laneLength(lane, cuts)).fold<double>(
          0,
          math.max,
        );
    final totalCm = roll.totalLengthCm;
    final remainCm = totalCm - usedLength;
    final oldGroupedNeed = cuts.fold<double>(0, (sum, cut) {
      return sum + (cut.quantity / laneCount).ceil() * cut.lengthCm;
    });

    final lanes = <RollLaneResult>[];
    final summaries = <RollCutSummary>[];
    final placedByCut = List<int>.filled(cuts.length, 0);

    for (var laneIndex = 0; laneIndex < plan.length; laneIndex++) {
      final laneItems = plan[laneIndex];
      var x = 0.0;
      final placed = <RollPlacedCut>[];
      for (final item in laneItems) {
        final cut = cuts[item.cutIndex];
        placedByCut[item.cutIndex]++;
        placed.add(
          RollPlacedCut(
            cut: cut,
            cutIndex: item.cutIndex,
            xCm: x,
            yCm: laneIndex * cutWidth,
            widthCm: cutWidth,
            lengthCm: cut.lengthCm,
          ),
        );
        x += cut.lengthCm;
      }
      lanes.add(RollLaneResult(lengthCm: x, items: placed));
    }

    for (var i = 0; i < cuts.length; i++) {
      final cut = cuts[i];
      summaries.add(
        RollCutSummary(
          cut: cut,
          piecesPerColumn: laneCount,
          columnsNeeded: (cut.quantity / laneCount).ceil(),
          placedQuantity: placedByCut[i],
          requiredLengthCm: cut.lengthCm * cut.quantity,
          remainingWidthCm: roll.widthCm - laneCount * cutWidth,
        ),
      );
    }

    final widthRemain = (roll.widthCm - laneCount * cutWidth)
        .clamp(0, double.infinity)
        .toDouble();
    return RollFabricOptimizationResult(
      roll: roll.copyWith(cuts: cuts),
      optimizedByLane: true,
      possible: remainCm >= -0.0001,
      totalLengthCm: totalCm,
      usedLengthCm: usedLength,
      remainLengthCm: remainCm,
      savedLengthCm: math.max(0, oldGroupedNeed - usedLength),
      laneWidthCm: cutWidth,
      laneCount: laneCount,
      widthRemainCm: widthRemain,
      lanes: lanes,
      cutSummaries: summaries,
    );
  }

  RollFabricOptimizationResult _groupByCut(
    RollFabricPlan roll,
    List<RollCutItem> cuts,
  ) {
    final lanes = <RollLaneResult>[];
    final summaries = <RollCutSummary>[];
    var x = 0.0;
    final maxSlots = cuts
        .map((cut) => math.max(1, roll.widthCm ~/ cut.widthCm))
        .fold<int>(1, math.max);

    for (var cutIndex = 0; cutIndex < cuts.length; cutIndex++) {
      final cut = cuts[cutIndex];
      final perColumn = math.max(1, roll.widthCm ~/ cut.widthCm);
      final columns = (cut.quantity / perColumn).ceil();
      final remainWidth =
          (roll.widthCm - perColumn * cut.widthCm).clamp(0, double.infinity);
      final placed = <RollPlacedCut>[];
      var done = 0;

      for (var column = 0; column < columns; column++) {
        for (var row = 0; row < perColumn; row++) {
          if (done >= cut.quantity) break;
          placed.add(
            RollPlacedCut(
              cut: cut,
              cutIndex: cutIndex,
              xCm: x + column * cut.lengthCm,
              yCm: row * cut.widthCm,
              widthCm: cut.widthCm,
              lengthCm: cut.lengthCm,
            ),
          );
          done++;
        }
      }

      final requiredLength = columns * cut.lengthCm;
      lanes.add(RollLaneResult(lengthCm: x + requiredLength, items: placed));
      summaries.add(
        RollCutSummary(
          cut: cut,
          piecesPerColumn: perColumn,
          columnsNeeded: columns,
          placedQuantity: done,
          requiredLengthCm: requiredLength,
          remainingWidthCm: remainWidth.toDouble(),
        ),
      );
      x += requiredLength;
    }

    final totalCm = roll.totalLengthCm;
    final remainCm = totalCm - x;
    final smallestWidth = cuts.map((e) => e.widthCm).reduce(math.min);
    final laneWidth = smallestWidth <= 0 ? roll.widthCm : smallestWidth;
    final laneCount = math.max(1, roll.widthCm ~/ laneWidth);

    return RollFabricOptimizationResult(
      roll: roll.copyWith(cuts: cuts),
      optimizedByLane: false,
      possible: remainCm >= -0.0001,
      totalLengthCm: totalCm,
      usedLengthCm: x,
      remainLengthCm: remainCm,
      savedLengthCm: 0,
      laneWidthCm: laneWidth,
      laneCount: maxSlots > laneCount ? maxSlots : laneCount,
      widthRemainCm: (roll.widthCm - laneCount * laneWidth)
          .clamp(0, double.infinity)
          .toDouble(),
      lanes: lanes,
      cutSummaries: summaries,
    );
  }

  List<List<_LaneItem>>? _solveLanePlan(List<RollCutItem> cuts, int laneCount) {
    final lengths = cuts.map((cut) => cut.lengthCm).toList();
    final qtys = cuts.map((cut) => math.max(0, cut.quantity)).toList();
    final totalLen = cuts.fold<double>(
      0,
      (sum, cut) => sum + cut.lengthCm * cut.quantity,
    );
    final maxPiece = lengths.reduce(math.max);
    var low = math.max(maxPiece.ceil(), (totalLen / laneCount).ceil());
    var high = totalLen.ceil();
    List<List<_LaneItem>>? best;

    while (low <= high) {
      final mid = ((low + high) / 2).floor();
      final candidate = _assignLanesWithinCap(lengths, qtys, laneCount, mid);
      if (candidate != null) {
        best = candidate;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    if (best == null) return null;
    final lanes = best.map((lane) {
      final items = [...lane]..sort((a, b) => b.lengthCm.compareTo(a.lengthCm));
      return items;
    }).toList();
    lanes.sort((a, b) => _laneLength(b, cuts).compareTo(_laneLength(a, cuts)));
    return lanes;
  }

  List<List<_LaneItem>>? _assignLanesWithinCap(
    List<double> lengths,
    List<int> qtys,
    int laneCount,
    int cap,
  ) {
    final typeCount = lengths.length;
    final combos = <_Combo>[];

    void buildCombo(int i, List<int> counts, double len) {
      if (i == typeCount) {
        if (len > 0) combos.add(_Combo([...counts], len));
        return;
      }
      final maxN = math.min(qtys[i], ((cap - len) / lengths[i]).floor());
      for (var n = maxN; n >= 0; n--) {
        counts[i] = n;
        buildCombo(i + 1, counts, len + n * lengths[i]);
      }
      counts[i] = 0;
    }

    buildCombo(0, List<int>.filled(typeCount, 0), 0);
    combos.sort((a, b) => b.lengthCm.compareTo(a.lengthCm));

    final memo = <String>{};
    bool empty(List<int> rem) => rem.every((value) => value == 0);
    String key(int laneIdx, List<int> rem) => '$laneIdx|${rem.join(',')}';
    bool canUse(_Combo combo, List<int> rem) {
      for (var i = 0; i < combo.counts.length; i++) {
        if (combo.counts[i] > rem[i]) return false;
      }
      return true;
    }

    List<int> sub(List<int> rem, _Combo combo) {
      return List<int>.generate(rem.length, (i) => rem[i] - combo.counts[i]);
    }

    List<List<_LaneItem>>? dfs(int laneIdx, List<int> rem) {
      if (empty(rem)) return <List<_LaneItem>>[];
      if (laneIdx >= laneCount) return null;
      final memoKey = key(laneIdx, rem);
      if (memo.contains(memoKey)) return null;

      for (final combo in combos) {
        if (!canUse(combo, rem)) continue;
        final rest = dfs(laneIdx + 1, sub(rem, combo));
        if (rest != null) {
          final items = <_LaneItem>[];
          for (var cutIndex = 0; cutIndex < combo.counts.length; cutIndex++) {
            for (var j = 0; j < combo.counts[cutIndex]; j++) {
              items.add(_LaneItem(cutIndex, lengths[cutIndex]));
            }
          }
          return [items, ...rest];
        }
      }

      memo.add(memoKey);
      return null;
    }

    final result = dfs(0, [...qtys]);
    if (result == null) return null;
    while (result.length < laneCount) {
      result.add(<_LaneItem>[]);
    }
    return result;
  }

  double _laneLength(List<_LaneItem> lane, List<RollCutItem> cuts) {
    return lane.fold<double>(0, (sum, item) => sum + item.lengthCm);
  }
}

class _Combo {
  final List<int> counts;
  final double lengthCm;

  const _Combo(this.counts, this.lengthCm);
}

class _LaneItem {
  final int cutIndex;
  final double lengthCm;

  const _LaneItem(this.cutIndex, this.lengthCm);
}
