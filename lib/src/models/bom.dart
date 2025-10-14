class BomRow {
  final String id;
  final String outputItemId;  // finished or semi-finished
  final String inputItemId; // raw or sub
  final double qtyPer;         // required qty per 1 of parent

  BomRow({
    required this.id,
    required this.outputItemId,
    required this.inputItemId,
    required this.qtyPer,
  });
}
