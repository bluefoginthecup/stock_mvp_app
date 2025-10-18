class Item {
  final String id;
  final String name;
  final String sku;
  final String unit; // 'EA','SET','ROLL' etc.=
  @Deprecated('Use tree path via repo (itemPathIds / itemPathNames).')
  final String folder;     // 레거시 카테고리
  @Deprecated('Use tree path via repo (itemPathIds / itemPathNames).')
  final String? subfolder; // 레거시 서브카테고리
  final int minQty; // threshold
  final int qty;    // current stock

  Item({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.folder,
    this.subfolder,
    required this.minQty,
    required this.qty,
  });

  Item copyWith({
    String? name,
    String? sku,
    String? unit,
    @Deprecated('Use tree path via repo.') String? folder,
    @Deprecated('Use tree path via repo.') String? subfolder,
    int? minQty,
    int? qty}) {
    return Item(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      folder: folder ?? this.folder,
      subfolder: subfolder ?? this.subfolder,
      minQty: minQty ?? this.minQty,
      qty: qty ?? this.qty,
    );
  }
}
