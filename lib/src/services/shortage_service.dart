import '../repos/repo_interfaces.dart';
import 'bom_service.dart';

class Shortage2L {
  final int finishedShortage;
  final Map<String, double> semiNeed, semiShortage;
  final Map<String, double> rawNeed, rawShortage;
  final Map<String, double> subNeed, subShortage;

  const Shortage2L({
    required this.finishedShortage,
    required this.semiNeed,
    required this.semiShortage,
    required this.rawNeed,
    required this.rawShortage,
    required this.subNeed,
    required this.subShortage,
  });
}

class ShortageService {
  final ItemRepo repo;
  final BomService bom;
  ShortageService({required this.repo, required this.bom});

  int _stockI(String id) => repo.stockOf(id);

  Shortage2L compute({required String finishedId, required int orderQty}) {
    final finStock = _stockI(finishedId);
    final finShort = (orderQty - finStock).clamp(0, 1 << 30);
    if (finShort == 0) {
      return const Shortage2L(
        finishedShortage: 0,
        semiNeed: {},
        semiShortage: {},
        rawNeed: {},
        rawShortage: {},
        subNeed: {},
        subShortage: {},
      );
    }

    final ex = bom.explode2Levels(finishedId: finishedId, finishedShortage: finShort);

    Map<String, double> _merge(Map<String, double> a, Map<String, double> b) {
      final r = <String, double>{}..addAll(a);
      b.forEach((k, v) => r.update(k, (x) => x + v, ifAbsent: () => v));
      return r;
    }

    final rawNeed = _merge(ex.finishedRaw, ex.rawFromSemi);
    final subNeed = _merge(ex.finishedSub, ex.subFromSemi);

    Map<String, double> _lack(Map<String, double> need) {
      final m = <String, double>{};
      need.forEach((id, n) {
        final st = _stockI(id).toDouble();
        final lack = n - st;
        if (lack > 0) m[id] = lack;
      });
      return m;
    }

    final semiShort = <String, double>{};
    ex.semiNeed.forEach((id, n) {
      final st = _stockI(id).toDouble();
      final lack = n - st;
      if (lack > 0) semiShort[id] = lack;
    });

    return Shortage2L(
      finishedShortage: finShort,
      semiNeed: ex.semiNeed,
      semiShortage: semiShort,
      rawNeed: rawNeed,
      rawShortage: _lack(rawNeed),
      subNeed: subNeed,
      subShortage: _lack(subNeed),
    );
  }
}
