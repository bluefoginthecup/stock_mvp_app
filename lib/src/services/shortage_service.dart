import '../repos/repo_interfaces.dart';
import 'bom_service.dart';

class Shortage2L {
  final double finishedShortage;
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

    // ── unit 판정: 아이템별 길이기반인지? ──────────────────────────────
    bool _isLengthUnit(String? u) {
        if (u == null) return false;
        final s = u.trim().toUpperCase();
        // 필요시 여기에 더 추가: 'FT','IN','YARD','YD','CM','MM' 등
        const lengthUnits = {'M','CM','MM','METER','METERS','YD','YARD','IN','FT'};
        return lengthUnits.contains(s);
      }
    String _unitOutOf(String id) {
        final dyn = repo as dynamic;
        try {
          if (dyn.hintUnitOut is Function) {
            final u = dyn.hintUnitOut(id);
            if (u is String && u.trim().isNotEmpty) return u;
          }
        } catch (_) {}
        // hintUnitOut이 없으면 Item.unit을 쓰도록 repo에서 노출돼 있다고 가정
        try {
          if (dyn.getItem is Function) {
            final it = dyn.getItem(id);
            if (it is Future) {
              // 동기 접근이 아니면 그냥 빈 문자열 반환
              return '';
            } else if (it != null && it.unit is String) {
              return (it.unit as String);
            }
          }
        } catch (_) {}
        return '';
      }

    // ── 가용치 폴백: 개수/미터 각각 ────────────────────────────────────
    double _stockQtyOrHint(String id) {
        final st = repo.stockOf(id).toDouble();
        if (st > 0) return st;
        final dyn = repo as dynamic;
        try {
          if (dyn.hintQtyOut is Function) {
            final v = dyn.hintQtyOut(id);
            if (v is num && v > 0) return v.toDouble();
          }
        } catch (_) {}
        return 0;
      }
    double _stockMetersOrHint(String id) {
        final dyn = repo as dynamic;
        try {
          if (dyn.hintUsableMeters is Function) {
            final v = dyn.hintUsableMeters(id);
            if (v is num && v > 0) return v.toDouble();
          }
        } catch (_) {}
        return 0;
      }
    double _availableByItemUnit(String id) {
        final u = _unitOutOf(id);
        return _isLengthUnit(u) ? _stockMetersOrHint(id) : _stockQtyOrHint(id);
      }
  Shortage2L compute({required String finishedId, required int orderQty}) {
    // 완제품도 단위 기준으로 계산(대부분 EA겠지만, 안전하게 단위 확인)
        final finStock = _availableByItemUnit(finishedId);
        final finShort = ((orderQty - finStock).clamp(0, 1 << 30)).toDouble();
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

    // 아이템별 단위에 따라 자동 판정하여 부족 계산
        Map<String, double> _lackByItemUnit(Map<String, double> need) {
          final m = <String, double>{};
      need.forEach((id, n) {
        final st = _availableByItemUnit(id);
        final lack = n - st;
        if (lack > 0) m[id] = lack;
      });
      return m;
    }

    final semiShort = <String, double>{};
    ex.semiNeed.forEach((id, n) {
      final st = _availableByItemUnit(id);
      final lack = n - st;
      if (lack > 0) semiShort[id] = lack;
    });

    return Shortage2L(
      finishedShortage: finShort,
      semiNeed: ex.semiNeed,
      semiShortage: semiShort,
      rawNeed: rawNeed,
      rawShortage: _lackByItemUnit(rawNeed),
      subNeed: subNeed,
      subShortage: _lackByItemUnit(subNeed),
    );
  }
}
