class RollCutItem {
  final String id;
  final String label;
  final double widthCm;
  final double lengthCm;
  final int quantity;

  const RollCutItem({
    required this.id,
    required this.label,
    required this.widthCm,
    required this.lengthCm,
    required this.quantity,
  });

  RollCutItem copyWith({
    String? id,
    String? label,
    double? widthCm,
    double? lengthCm,
    int? quantity,
  }) {
    return RollCutItem(
      id: id ?? this.id,
      label: label ?? this.label,
      widthCm: widthCm ?? this.widthCm,
      lengthCm: lengthCm ?? this.lengthCm,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'widthCm': widthCm,
        'lengthCm': lengthCm,
        'quantity': quantity,
      };

  factory RollCutItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    return RollCutItem(
      id: json['id'] as String? ?? now,
      label: json['label'] as String? ?? '재단항목',
      widthCm: (json['widthCm'] as num?)?.toDouble() ?? 10,
      lengthCm: (json['lengthCm'] as num?)?.toDouble() ?? 10,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}
