// lib/src/models/bom.dart
/// 2단계 레시피 구조:
/// - Finished 레시피: finished(parent) → [semi | raw | sub]
/// - Semi 레시피:     semi(parent)     → [raw | sub]   (⚠️ semi 아래 semi 금지)
///
/// 이 파일은 순수 데이터 모델만 담습니다.

/// 레시피의 루트(부모) 타입
enum BomRoot { finished, semi }

/// 부모를 구성하는 컴포넌트의 종류
enum BomKind { semi, raw, sub }

class BomRow {
  /// 이 레시피가 속한 공간(완제품 레시피인지, 반제품 레시피인지)
  final BomRoot root;

  /// 레시피의 부모 아이템 ID (finished 또는 semi의 ID)
  final String parentItemId;

  /// 구성 아이템(컴포넌트) ID
  final String componentItemId;

  /// 구성 아이템의 종류(semi/raw/sub)
  final BomKind kind;

  /// 부모 1개를 만들 때 필요한 구성 아이템의 수량 (ea, m, 마 등 단위는 Item에서 해석)
  final double qtyPer;

  /// 여유/로스율 (0.0 ~ 1.0)
  final double wastePct;

  const BomRow({
    required this.root,
    required this.parentItemId,
    required this.componentItemId,
    required this.kind,
    required this.qtyPer,
    this.wastePct = 0.0,
  })  : assert(qtyPer > 0, 'qtyPer must be > 0'),
        assert(wastePct >= 0 && wastePct <= 1, 'wastePct must be within 0..1');

  /// parentQty 개를 만들 때 필요한 구성 수량
  double needFor(num parentQty) => (qtyPer * parentQty) * (1.0 + wastePct);

  BomRow copyWith({
    BomRoot? root,
    String? parentItemId,
    String? componentItemId,
    BomKind? kind,
    double? qtyPer,
    double? wastePct,
  }) {
    return BomRow(
      root: root ?? this.root,
      parentItemId: parentItemId ?? this.parentItemId,
      componentItemId: componentItemId ?? this.componentItemId,
      kind: kind ?? this.kind,
      qtyPer: qtyPer ?? this.qtyPer,
      wastePct: wastePct ?? this.wastePct,
    );
  }

  @override
  String toString() =>
      'BomRow(root=$root, parent=$parentItemId <- ${kind.name}:${componentItemId}, qtyPer=$qtyPer, waste=$wastePct)';
}


/// 문자열 ↔ enum 매핑 유틸 (시드 파싱용)e
extension BomRootX on BomRoot {
  static BomRoot fromString(String s) {
    switch (s) {
      case 'finished':
        return BomRoot.finished;
      case 'semi':
        return BomRoot.semi;
      default:
        throw ArgumentError('Invalid BomRoot: $s');
    }
  }
}

extension BomKindX on BomKind {
  static BomKind fromString(String s) {
    switch (s) {
      case 'semi':
        return BomKind.semi;
      case 'raw':
        return BomKind.raw;
      case 'sub':
        return BomKind.sub;
      default:
        throw ArgumentError('Invalid BomKind: $s');
    }
  }
}
