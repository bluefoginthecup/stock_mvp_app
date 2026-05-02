import 'fabric_piece.dart';

class FabricCuttingProject {
  final String id;
  final String productName;
  final String? imagePath;
  final String memo;
  final int quantity;
  final double fabricWidthCm;
  final List<FabricPiece> pieces;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FabricCuttingProject({
    required this.id,
    required this.productName,
    required this.imagePath,
    required this.memo,
    required this.quantity,
    required this.fabricWidthCm,
    required this.pieces,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName =>
      productName.trim().isEmpty ? '이름 없는 재단 계산' : productName.trim();

  FabricCuttingProject copyWith({
    String? id,
    String? productName,
    String? imagePath,
    bool clearImagePath = false,
    String? memo,
    int? quantity,
    double? fabricWidthCm,
    List<FabricPiece>? pieces,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FabricCuttingProject(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      memo: memo ?? this.memo,
      quantity: quantity ?? this.quantity,
      fabricWidthCm: fabricWidthCm ?? this.fabricWidthCm,
      pieces: pieces ?? this.pieces,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': productName,
        'imagePath': imagePath,
        'memo': memo,
        'quantity': quantity,
        'fabricWidthCm': fabricWidthCm,
        'pieces': pieces.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FabricCuttingProject.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return FabricCuttingProject(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      productName: json['productName'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      memo: json['memo'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      fabricWidthCm: (json['fabricWidthCm'] as num?)?.toDouble() ?? 140,
      pieces: ((json['pieces'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => FabricPiece.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
