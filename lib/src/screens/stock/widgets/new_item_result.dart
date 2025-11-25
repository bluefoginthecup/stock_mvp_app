import '../../../models/item.dart';

class NewItemResult {
  final Item item;
  final List<String> pathIds; // [l1Id, l2Id, l3Id]
  const NewItemResult(this.item, this.pathIds);
}
