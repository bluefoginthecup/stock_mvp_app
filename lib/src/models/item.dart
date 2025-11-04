class Item {
  final String id;
  final String name;
  final String? displayName;
  final String sku;
  final String unit; // 'EA','SET','ROLL' etc.=
  final String folder;     // 레거시 카테고리
  final String? subfolder; // 레거시 서브카테고리
  /// 선택: 레거시 3단계 카테고리 (L3). 신규 시드/툴에서 사용 권장.
  final String? subsubfolder;
  final int minQty; // threshold
  final int qty;    // current stock
  /// 신규: Finished/SemiFinished/Sub 등 (없으면 null 허용)
  final String? kind;
  /// 신규: {design,color,form,size,cutSize} 등 유연 속성
  final Map<String, dynamic>? attrs;

  /// ---- 하이브리드 환산 핵심 필드(1급) ----
  /// 입고단위 / 출고단위 (예: Roll → M)
  final String unitIn;   // 예: 'Roll'
  final String unitOut;  // 예: 'M'
  /// 1 unitIn = conversionRate * unitOut (예: 1 Roll = 90 M)
  final double conversionRate;
  /// 'fixed' | 'lot' (기본값: 'fixed')
  final String conversionMode;

  /// 레거시: 초기 임포트용 메타(존치, 폴백 소스)
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

    // 신규 환산 필드 (옵션 파라미터 + 합리적 기본값)
    String? unitIn,
    String? unitOut,
    double? conversionRate,
    String? conversionMode,

    this.stockHints,
  })  : unitIn = unitIn ?? unit,                    // 기본값: 기존 unit
        unitOut = unitOut ?? unit,                  // 기본값: 기존 unit
        conversionRate = conversionRate ?? 1.0,     // 기본값: 1:1
        conversionMode = conversionMode ?? 'fixed'; // 기본값: 고정환산

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

    // 신규 환산 필드
    String? unitIn,
    String? unitOut,
    double? conversionRate,
    String? conversionMode,

    StockHints? stockHints,
  }) {
    final baseUnit = unit ?? this.unit;
    return Item(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      sku: sku ?? this.sku,
      unit: baseUnit,
      folder: folder ?? this.folder,
      subfolder: subfolder ?? this.subfolder,
      subsubfolder: subsubfolder ?? this.subsubfolder,
      minQty: minQty ?? this.minQty,
      qty: qty ?? this.qty,
      kind: kind ?? this.kind,
      attrs: attrs ?? this.attrs,

      unitIn: unitIn ?? ((this.unitIn == this.unit) ? baseUnit : this.unitIn),
      unitOut: unitOut ?? ((this.unitOut == this.unit) ? baseUnit : this.unitOut),

      conversionRate: conversionRate ?? this.conversionRate,
      conversionMode: conversionMode ?? this.conversionMode,

      stockHints: stockHints ?? this.stockHints,
    );
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    // 레거시 stockHints 폴백
    final hints = StockHints.fromJson(json['stockHints']);

    // top-level + snake/camel + hints 순서로 폴백
    String _pickStr(dynamic a, dynamic b, dynamic c, {String? or}) {
      return (a is String && a.isNotEmpty)
          ? a
          : (b is String && b.isNotEmpty)
          ? b
          : (c is String && c.isNotEmpty)
          ? c
          : (or ?? '');
    }

    double _pickNumAsDouble(dynamic a, dynamic b, dynamic c, {double or = 1.0}) {
      num? n;
      if (a is num) n = a;
      else if (b is num) n = b;
      else if (c is num) n = c;
      return (n ?? or).toDouble();
    }

    final unit = (json['unit'] ?? 'EA') as String;

    final unitIn = _pickStr(json['unit_in'], json['unitIn'], hints.unitIn, or: unit);
    final unitOut = _pickStr(json['unit_out'], json['unitOut'], hints.unitOut, or: unit);
    final convRate = _pickNumAsDouble(json['conversion_rate'], json['conversionRate'], hints.conversionRate, or: 1.0);
    final convMode = _pickStr(json['conversion_mode'], json['conversionMode'], null, or: 'fixed');

    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      sku: json['sku'] as String,
      unit: unit,
      folder: json['folder'] as String? ?? '',
      subfolder: json['subfolder'] as String?,
      subsubfolder: json['subsubfolder'] as String?,
      minQty: (json['minQty'] ?? 0) as int,
      qty: (json['qty'] ?? 0) as int,
      kind: json['kind'] as String?,
      attrs: (json['attrs'] is Map) ? Map<String, dynamic>.from(json['attrs']) : null,

      unitIn: unitIn,
      unitOut: unitOut,
      conversionRate: convRate,
      conversionMode: convMode,

      stockHints: hints,
    );
  }

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

    // 신규 환산 필드 (snake_case로 고정 출력)
    'unit_in': unitIn,
    'unit_out': unitOut,
    'conversion_rate': conversionRate,
    'conversion_mode': conversionMode,

    // 레거시 보존(있을 때만)
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
