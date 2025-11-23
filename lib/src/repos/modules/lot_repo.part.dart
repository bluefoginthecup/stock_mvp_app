part of '../drift_unified_repo.dart';

mixin LotRepoMixin on _RepoCore{
  Future<void> upsertLots(String itemId, List<Lot> lots) async {
    if (lots.isEmpty) return;

    List<Lot> normalized = lots.map((lot) {
      if (lot.itemId.isNotEmpty && lot.itemId != itemId) {
        // 다른 itemId면 lot 값을 신뢰(로그만 남긴다고 가정)
        return lot;
      }
      if (lot.itemId.isNotEmpty) return lot;
      // 비어 있으면 인자로 받은 itemId 채우기
      return Lot(
        itemId: itemId,
        lotNo: lot.lotNo,
        receivedQtyRoll: lot.receivedQtyRoll,
        measuredLengthM: lot.measuredLengthM,
        usableQtyM: lot.usableQtyM,
        status: lot.status,
        receivedAt: lot.receivedAt,
      );
    }).toList();

    String _lotId(Lot lot) => '${lot.itemId}__${lot.lotNo}';

    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.lots,
        normalized.map((lot) {
          return LotsCompanion(
            id: Value(_lotId(lot)),
            itemId: Value(lot.itemId),
            lotNo: Value(lot.lotNo),
            receivedQtyRoll: Value(lot.receivedQtyRoll),
            measuredLengthM: Value(lot.measuredLengthM),
            usableQtyM: Value(lot.usableQtyM),
            status: Value(lot.status),
            receivedAt: Value(lot.receivedAt.toIso8601String()),
          );
        }).toList(),
      );
    });
  }
}
