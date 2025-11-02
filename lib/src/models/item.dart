class Item {
  final String id;
  final String name;
  final String? displayName;
  final String sku;
  final String unit; // 'EA','SET','ROLL' etc.=
  @Deprecated('Use tree path via repo (itemPathIds / itemPathNames).')
  final String folder;     // 레거시 카테고리
  @Deprecated('Use tree path via repo (itemPathIds / itemPathNames).')
  final String? subfolder; // 레거시 서브카테고리
  /// 선택: 레거시 3단계 카테고리 (L3). 신규 시드/툴에서 사용 권장.
  final String? subsubfolder;
  final int minQty; // threshold
  final int qty;    // current stock
  /// 신규: Finished/SemiFinished/Sub 등 (없으면 null 허용)
  final String? kind;
  /// 신규: {design,color,form,size,cutSize} 등 유연 속성
  final Map<String, dynamic>? attrs;
  /// 신규: 롤→미터 환산 등 힌트 (초기 임포트용 메타)
  final StockHints? stockHints;

  Item({
    required this.id,
    required this.name,
    this.displayName,
    required this.sku,
    required this.unit,
    required this.folder,
    this.subfolder,
    this.subsubfolder,
    required this.minQty,
    required this.qty,
    this.kind,
    this.attrs,
    this.stockHints,
  });

  Item copyWith({
    String? name,
    String? displayName,
    String? sku,
    String? unit,
    @Deprecated('Use tree path via repo.') String? folder,
    @Deprecated('Use tree path via repo.') String? subfolder,
    String? subsubfolder,
    int? minQty,
    int? qty,
    String? kind,
    Map<String, dynamic>? attrs,
    StockHints? stockHints,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      folder: folder ?? this.folder,
      subfolder: subfolder ?? this.subfolder,
      subsubfolder: subsubfolder ?? this.subsubfolder,
      minQty: minQty ?? this.minQty,
      qty: qty ?? this.qty,
      kind: kind ?? this.kind,
      attrs: attrs ?? this.attrs,
      stockHints: stockHints ?? this.stockHints,
    );
  }
  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: json['id'],
    name: json['name'],
    displayName: json['displayName'], // ✅ 추가
    sku: json['sku'],
    unit: (json['unit'] ?? 'EA'),
    folder: json['folder'],
    subfolder: json['subfolder'],
    subsubfolder: json['subsubfolder'], // 없으면 null
    minQty: json['minQty'] ?? 0,
    qty: json['qty'] ?? 0, // 초기재고 매핑은 Importer에서 세팅
    kind: json['kind'],
    attrs: (json['attrs'] is Map) ? Map<String,dynamic>.from(json['attrs']) : null,
    stockHints: StockHints.fromJson(json['stockHints']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (displayName != null) 'displayName': displayName, // ✅ 추가
    'sku': sku,
    'unit': unit,
    'folder': folder,
    'subfolder': subfolder,
    'subsubfolder': subsubfolder,
    'minQty': minQty,
    'qty': qty,
    if (kind != null) 'kind': kind,
    if (attrs != null && attrs!.isNotEmpty) 'attrs': attrs,
    if (stockHints != null) 'stockHints': stockHints!.toJson(),
  };
}

class StockHints {
  final String? unitIn;          // 예: 'Roll'
  final String? unitOut;         // 예: 'M'
  final num? conversionRate;     // 예: 90 (1 Roll = 90 M)
  final int? qty;                // 초기 롤 수량 등
  final num? usableQtyM;         // 미터 환산 수량 등

  const StockHints({this.unitIn, this.unitOut, this.conversionRate, this.qty, this.usableQtyM});
  factory StockHints.fromJson(dynamic j) {
    if (j is! Map) return const StockHints();
    final m = Map<String, dynamic>.from(j);
    return StockHints(
      unitIn: m['unit_in'] ?? m['unitIn'],
      unitOut: m['unit_out'] ?? m['unitOut'],
      conversionRate: m['conversion_rate'] ?? m['conversionRate'],
      qty: m['qty'],
      usableQtyM: m['usable_qty_m'] ?? m['usableQtyM'],
    );
  }
  Map<String, dynamic> toJson() => {
    if (unitIn != null) 'unit_in': unitIn,
    if (unitOut != null) 'unit_out': unitOut,
    if (conversionRate != null) 'conversion_rate': conversionRate,
    if (qty != null) 'qty': qty,
    if (usableQtyM != null) 'usable_qty_m': usableQtyM,
  };
}
