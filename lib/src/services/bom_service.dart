import '../models/bom.dart';
import '../repos/repo_interfaces.dart';

class Explode2L {
  final Map<String, double> semiNeed;
  final Map<String, double> finishedRaw;
  final Map<String, double> finishedSub;
  final Map<String, double> rawFromSemi;
  final Map<String, double> subFromSemi;

  const Explode2L({
    required this.semiNeed,
    required this.finishedRaw,
    required this.finishedSub,
    required this.rawFromSemi,
    required this.subFromSemi,
  });
}

class BomService {
  final ItemRepo repo;
  BomService(this.repo);

  Map<String, double> _sum(Map<String, double> m, String id, double n) {
    m.update(id, (v) => v + n, ifAbsent: () => n);
    return m;
  }

  Explode2L explode2Levels({
    required String finishedId,
    required double finishedShortage}) {
    if (finishedShortage <= 0) {
      return const Explode2L(
        semiNeed: {},
        finishedRaw: {},
        finishedSub: {},
        rawFromSemi: {},
        subFromSemi: {},
      );
    }

    final top = repo.finishedBomOf(finishedId);
    final semiNeed = <String, double>{};
    final finishedRaw = <String, double>{};
    final finishedSub = <String, double>{};

    for (final r in top) {
      final need = r.needFor(finishedShortage);
      switch (r.kind) {
        case BomKind.semi:
          _sum(semiNeed, r.componentItemId, need);
          break;
        case BomKind.raw:
          _sum(finishedRaw, r.componentItemId, need);
          break;
        case BomKind.sub:
          _sum(finishedSub, r.componentItemId, need);
          break;
      }
    }

    final semiShort = <String, double>{};
    semiNeed.forEach((semiId, need) {
      final st = repo.stockOf(semiId).toDouble();
      final lack = need - st;
      if (lack > 0) semiShort[semiId] = lack;
    });

    final rawFromSemi = <String, double>{};
    final subFromSemi = <String, double>{};
    semiShort.forEach((semiId, lackQty) {
      final rows = repo.semiBomOf(semiId);
      for (final r in rows) {
        final need = r.needFor(lackQty);
        if (r.kind == BomKind.raw) _sum(rawFromSemi, r.componentItemId, need);
        else if (r.kind == BomKind.sub) _sum(subFromSemi, r.componentItemId, need);
      }
    });

    return Explode2L(
      semiNeed: semiNeed,
      finishedRaw: finishedRaw,
      finishedSub: finishedSub,
      rawFromSemi: rawFromSemi,
      subFromSemi: subFromSemi,
    );
  }
}
