import '../repos/repo_interfaces.dart';
import 'bom_service.dart';


class Shortage2L {
  final double finishedStock;
  final double finishedShortage;
  final Map<String, double> semiNeed, semiShortage;
  final Map<String, double> rawNeed, rawShortage;
  final Map<String, double> subNeed, subShortage;

  const Shortage2L({
    required this.finishedStock,
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
    const lengthUnits = {'M','CM','MM','METER','METERS','YD','YARD','IN','FT'};
    return lengthUnits.contains(s);
  }

  String _unitOutOf(String id) {
    final dyn = repo as dynamic;

    // 🔍 unitOut 조회 로그
    print('[ShortageService] _unitOutOf($id) 호출');

    try {
      if (dyn.hintUnitOut is Function) {
        final u = dyn.hintUnitOut(id);
        print('[ShortageService]  hintUnitOut($id) => $u');
        if (u is String && u.trim().isNotEmpty) return u;
      }
    } catch (e, st) {
      print('[ShortageService]  hintUnitOut($id) 에러: $e\n$st');
    }

    try {
      if (dyn.getItem is Function) {
        final it = dyn.getItem(id);
        print('[ShortageService]  dyn.getItem($id) => ${it.runtimeType}');
        if (it is Future) {
          // DriftUnifiedRepo 처럼 비동기면 여기서 바로 리턴 ''
          return '';
        } else if (it != null && it.unit is String) {
          return (it.unit as String);
        }
      }
    } catch (e, st) {
      print('[ShortageService]  dyn.getItem($id) 에러: $e\n$st');
    }
    return '';
  }

  // ── 가용치 폴백: 개수/미터 각각 ────────────────────────────────────
  double _stockQtyOrHint(String id) {
    final st = repo.stockOf(id).toDouble();
    if (st > 0) {
      print('[ShortageService] _stockQtyOrHint($id) => stockOf=$st');
      return st;
    }
    final dyn = repo as dynamic;
    try {
      if (dyn.hintQtyOut is Function) {
        final v = dyn.hintQtyOut(id);
        print('[ShortageService] hintQtyOut($id) => $v');
        if (v is num && v > 0) return v.toDouble();
      }
    } catch (e, st) {
      print('[ShortageService] hintQtyOut($id) 에러: $e\n$st');
    }
    print('[ShortageService] _stockQtyOrHint($id) => 0 (no stock/hint)');
    return 0;
  }

  double _stockMetersOrHint(String id) {
    final dyn = repo as dynamic;
    try {
      if (dyn.hintUsableMeters is Function) {
        final v = dyn.hintUsableMeters(id);
        print('[ShortageService] hintUsableMeters($id) => $v');
        if (v is num && v > 0) return v.toDouble();
      }
    } catch (e, st) {
      print('[ShortageService] hintUsableMeters($id) 에러: $e\n$st');
    }
    print('[ShortageService] _stockMetersOrHint($id) => 0');
    return 0;
  }

  double _availableByItemUnit(String id) {
    final u = _unitOutOf(id);
    final isLen = _isLengthUnit(u);
    final v = isLen ? _stockMetersOrHint(id) : _stockQtyOrHint(id);
    print('[ShortageService] _availableByItemUnit($id): unitOut="$u" '
        '=> isLen=$isLen, available=$v');
    return v;
  }

  Shortage2L compute({required String finishedId, required int orderQty}) {
    // 🔍 1) compute 진입 로그
    print('======== [ShortageService] compute START ========');
    print('[ShortageService] finishedId=$finishedId, orderQty=$orderQty');

    // 완제품도 단위 기준으로 계산(대부분 EA겠지만, 안전하게 단위 확인)
    final finStock = _availableByItemUnit(finishedId);
    final finShort = ((orderQty - finStock).clamp(0, 1 << 30)).toDouble();

    print('[ShortageService] finStock=$finStock, finShort=$finShort');

    if (finShort == 0) {
      print('[ShortageService] finShort == 0 → 부족 없음, 바로 리턴');
      print('======== [ShortageService] compute END (no shortage) ========');
      return Shortage2L(
        finishedStock: finStock,
        finishedShortage: 0,
        semiNeed: {},
        semiShortage: {},
        rawNeed: {},
        rawShortage: {},
        subNeed: {},
        subShortage: {},
      );
    }

    // 🔍 2) BOM explode 들어가기 직전
    print('[ShortageService] bom.explode2Levels 호출 '
        '(finishedId=$finishedId, finishedShortage=$finShort)');

    final ex = bom.explode2Levels(
      finishedId: finishedId,
      finishedShortage: finShort,
    );

    // 🔍 3) BOM explode 결과 요약

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

    final result = Shortage2L(
      finishedStock: finStock,
      finishedShortage: finShort,
      semiNeed: ex.semiNeed,
      semiShortage: semiShort,
      rawNeed: rawNeed,
      rawShortage: _lackByItemUnit(rawNeed),
      subNeed: subNeed,
      subShortage: _lackByItemUnit(subNeed),
    );


    return result;
  }
  Shortage2L computeForMake({required String finishedId, required int makeQty}) {

    final double make = makeQty.toDouble();
    if (make <= 0) {
      return Shortage2L(
        finishedStock: _availableByItemUnit(finishedId), // 의미상 있어도 되고 0도 가능
        finishedShortage: 0,

        semiNeed: const {},
        semiShortage: const {},
        rawNeed: const {},
        rawShortage: const {},
        subNeed: const {},
        subShortage: const {},
      );
    }


    // ✅ finishedShortage 자리에 "만들 수량"을 그대로 넣고 폭발
    final ex = bom.explode2Levels(
      finishedId: finishedId,
      finishedShortage: make,
    );

    Map<String, double> _merge(Map<String, double> a, Map<String, double> b) {
      final r = <String, double>{}..addAll(a);
      b.forEach((k, v) => r.update(k, (x) => x + v, ifAbsent: () => v));
      return r;
    }

    final rawNeed = _merge(ex.finishedRaw, ex.rawFromSemi);
    final subNeed = _merge(ex.finishedSub, ex.subFromSemi);

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
    final finStock = _availableByItemUnit(finishedId);

    final result = Shortage2L(
      finishedStock: finStock,
      finishedShortage: make, // 의미: "이번에 만들 수량"
      semiNeed: ex.semiNeed,
      semiShortage: semiShort,
      rawNeed: rawNeed,
      rawShortage: _lackByItemUnit(rawNeed),
      subNeed: subNeed,
      subShortage: _lackByItemUnit(subNeed),
    );

    return result;
  }

}
