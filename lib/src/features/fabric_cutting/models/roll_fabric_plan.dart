import 'package:flutter/material.dart';

import 'roll_cut_item.dart';

enum RollLengthUnit {
  yard,
  meter,
  centimeter,
}

extension RollLengthUnitX on RollLengthUnit {
  String get label {
    switch (this) {
      case RollLengthUnit.yard:
        return 'yard';
      case RollLengthUnit.meter:
        return 'm';
      case RollLengthUnit.centimeter:
        return 'cm';
    }
  }

  double toCm(double value) {
    switch (this) {
      case RollLengthUnit.yard:
        return value * 91.44;
      case RollLengthUnit.meter:
        return value * 100;
      case RollLengthUnit.centimeter:
        return value;
    }
  }

  static RollLengthUnit fromName(String? name) {
    switch (name) {
      case 'm':
      case 'meter':
        return RollLengthUnit.meter;
      case 'cm':
      case 'centimeter':
        return RollLengthUnit.centimeter;
      case 'yard':
      default:
        return RollLengthUnit.yard;
    }
  }
}

class RollFabricPlan {
  final String id;
  final String name;
  final String colorName;
  final int colorValue;
  final double widthCm;
  final double totalLength;
  final RollLengthUnit unit;
  final List<RollCutItem> cuts;

  const RollFabricPlan({
    required this.id,
    required this.name,
    required this.colorName,
    required this.colorValue,
    required this.widthCm,
    required this.totalLength,
    required this.unit,
    required this.cuts,
  });

  Color get color => Color(colorValue);

  double get totalLengthCm => unit.toCm(totalLength);

  RollFabricPlan copyWith({
    String? id,
    String? name,
    String? colorName,
    int? colorValue,
    double? widthCm,
    double? totalLength,
    RollLengthUnit? unit,
    List<RollCutItem>? cuts,
  }) {
    return RollFabricPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      widthCm: widthCm ?? this.widthCm,
      totalLength: totalLength ?? this.totalLength,
      unit: unit ?? this.unit,
      cuts: cuts ?? this.cuts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorName': colorName,
        'colorValue': colorValue,
        'widthCm': widthCm,
        'totalLength': totalLength,
        'unit': unit.label,
        'cuts': cuts.map((e) => e.toJson()).toList(),
      };

  factory RollFabricPlan.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    return RollFabricPlan(
      id: json['id'] as String? ?? now,
      name: json['name'] as String? ?? '보유 원단',
      colorName: json['colorName'] as String? ?? '색상',
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          const Color(0xFFDDDDDD).toARGB32(),
      widthCm: (json['widthCm'] as num?)?.toDouble() ?? 140,
      totalLength: (json['totalLength'] as num?)?.toDouble() ?? 10,
      unit: RollLengthUnitX.fromName(json['unit'] as String?),
      cuts: ((json['cuts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RollCutItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class RollOptimizerPlanSet {
  final String id;
  final String name;
  final List<RollFabricPlan> rolls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RollOptimizerPlanSet({
    required this.id,
    required this.name,
    required this.rolls,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => name.trim().isEmpty ? '이름 없는 롤 최적화' : name.trim();

  RollOptimizerPlanSet copyWith({
    String? id,
    String? name,
    List<RollFabricPlan>? rolls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RollOptimizerPlanSet(
      id: id ?? this.id,
      name: name ?? this.name,
      rolls: rolls ?? this.rolls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rolls': rolls.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RollOptimizerPlanSet.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return RollOptimizerPlanSet(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      rolls: ((json['rolls'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RollFabricPlan.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
