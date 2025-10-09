class BomRow {
  final String id;
  final String parentItemId;  // finished or semi-finished
  final String materialItemId; // raw or sub
  final double qtyPer;         // required qty per 1 of parent

  BomRow({
    required this.id,
    required this.parentItemId,
    required this.materialItemId,
    required this.qtyPer,
  });
}
