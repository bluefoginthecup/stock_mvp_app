class Item {
  final String id;
  final String name;
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

  Item({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.folder,
    this.subfolder,
    this.subsubfolder,
    required this.minQty,
    required this.qty,
  });

  Item copyWith({
    String? name,
    String? sku,
    String? unit,
    @Deprecated('Use tree path via repo.') String? folder,
    @Deprecated('Use tree path via repo.') String? subfolder,
    String? subsubfolder,
    int? minQty,
    int? qty}) {
    return Item(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      folder: folder ?? this.folder,
      subfolder: subfolder ?? this.subfolder,
            subsubfolder: subsubfolder ?? this.subsubfolder,
      minQty: minQty ?? this.minQty,
      qty: qty ?? this.qty,
    );
  }
  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: json['id'],
    name: json['name'],
    sku: json['sku'],
    unit: json['unit'],
    folder: json['folder'],
    subfolder: json['subfolder'],
    subsubfolder: json['subsubfolder'], // 없으면 null
    minQty: json['minQty'] ?? 0,
    qty: json['qty'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
      'id': id,
      'name': name,
      'sku': sku,
      'unit': unit,
      'folder': folder,
      'subfolder': subfolder,
      'subsubfolder': subsubfolder,
      'minQty': minQty,
      'qty': qty,
    };

}
