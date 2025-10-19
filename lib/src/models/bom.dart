import 'package:meta/meta.dart';

@immutable
class BomLine {
  final String id;        // 고유 id
  final String itemId;    // 구성품 item id
  final double qty;       // 루트 1개당 필요 수량
  final String unit;      // 예: pcs, m, kg
  final double? unitCost; // 선택: 라인 단가(원가 집계용)

  const BomLine({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.unit,
    this.unitCost,
  });

  BomLine copyWith({
    String? id,
    String? itemId,
    double? qty,
    String? unit,
    double? unitCost,
  }) {
    return BomLine(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'qty': qty,
    'unit': unit,
    'unitCost': unitCost,
  };

  static BomLine fromJson(Map<String, dynamic> j) => BomLine(
    id: j['id'] as String,
    itemId: j['itemId'] as String,
    qty: (j['qty'] as num).toDouble(),
    unit: j['unit'] as String,
    unitCost: j['unitCost'] == null ? null : (j['unitCost'] as num).toDouble(),
  );
}

@immutable
class Bom {
  final String id;            // bom id
  final String itemId;        // 완제품 item id
  final String name;          // 표시명
  final List<BomLine> lines;  // 구성
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool enabled;

  const Bom({
    required this.id,
    required this.itemId,
    required this.name,
    required this.lines,
    required this.createdAt,
    required this.updatedAt,
    this.enabled = true,
  });

  Bom copyWith({
    String? id,
    String? itemId,
    String? name,
    List<BomLine>? lines,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? enabled,
  }) {
    return Bom(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      lines: lines ?? this.lines,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'name': name,
    'lines': lines.map((l) => l.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'enabled': enabled,
  };

  static Bom fromJson(Map<String, dynamic> j) => Bom(
    id: j['id'] as String,
    itemId: j['itemId'] as String,
    name: j['name'] as String,
    lines: (j['lines'] as List)
        .map((e) => BomLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    enabled: j['enabled'] as bool? ?? true,
  );
}
