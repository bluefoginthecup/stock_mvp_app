import 'package:flutter/material.dart';

import '../models/item.dart';
import '../repos/repo_interfaces.dart';
import 'package:provider/provider.dart';

class StockService {
  static Future<void> applyItemQtyChange(
      BuildContext context,
      Item it,
      int finalDelta,
      ) async {
    final itemRepo = context.read<ItemRepo>();

    await itemRepo.adjustQty(
      itemId: it.id,
      delta: finalDelta,
      refType: 'MANUAL',
      note: 'setQty ${it.qty} → ${it.qty + finalDelta}',
    );
  }
}