import 'package:flutter/material.dart';

class FabricPiece {
  final String id;
  final String name;
  final double widthCm;
  final double lengthCm;
  final double seamAllowanceCm;
  final int colorValue;

  const FabricPiece({
    required this.id,
    required this.name,
    required this.widthCm,
    required this.lengthCm,
    required this.seamAllowanceCm,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  double get finishedWidthCm =>
      (widthCm - seamAllowanceCm).clamp(0, double.infinity).toDouble();

  FabricPiece copyWith({
    String? id,
    String? name,
    double? widthCm,
    double? lengthCm,
    double? seamAllowanceCm,
    int? colorValue,
  }) {
    return FabricPiece(
      id: id ?? this.id,
      name: name ?? this.name,
      widthCm: widthCm ?? this.widthCm,
      lengthCm: lengthCm ?? this.lengthCm,
      seamAllowanceCm: seamAllowanceCm ?? this.seamAllowanceCm,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'widthCm': widthCm,
        'lengthCm': lengthCm,
        'seamAllowanceCm': seamAllowanceCm,
        'colorValue': colorValue,
      };

  factory FabricPiece.fromJson(Map<String, dynamic> json) {
    return FabricPiece(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '원단',
      widthCm: (json['widthCm'] as num?)?.toDouble() ?? 10,
      lengthCm: (json['lengthCm'] as num?)?.toDouble() ?? 55,
      seamAllowanceCm: (json['seamAllowanceCm'] as num?)?.toDouble() ?? 0,
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          const Color(0xFFDDDDDD).value,
    );
  }
}
