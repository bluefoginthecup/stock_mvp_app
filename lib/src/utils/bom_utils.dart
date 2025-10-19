
import '../repos/repo_interfaces.dart'; // ItemRepo 등 (이미 프로젝트에 존재)
import '../services/inventory_service.dart'; // 재고 조회는 서비스에서


class ShortageLine {
  final String itemId;
  final double need;
  final double onHand;
  final double shortage;
  const ShortageLine({
    required this.itemId,
    required this.need,
    required this.onHand,
    required this.shortage,
  });
}

/// 루트 bomId 기준, multiplier(=생산수량)만큼 폭발하여 itemId별 필요수량을 합산
Future<Map<String, double>> explodeBom({
  required BomRepo bomRepo,
  required String bomId,
  double multiplier = 1.0,
}) async {
  final Map<String, double> acc = {};
  final visited = <String>{};

  Future<void> _recurse(String curBomId, double mul) async {
    if (visited.contains(curBomId)) {
      throw Exception('BOM 순환 감지: $curBomId');
    }
    visited.add(curBomId);

    final bom = await bomRepo.loadBom(curBomId);
    if (bom == null || !bom.enabled) {
      visited.remove(curBomId);
      return;
    }

    for (final line in bom.lines) {
      final need = line.qty * mul;

      // line.itemId가 또 다른 BOM의 루트(itemId)인지 확인
      final childBom = await bomRepo.bomForItem(line.itemId);
      if (childBom != null && childBom.enabled) {
        await _recurse(childBom.id, need);
      } else {
        acc[line.itemId] = (acc[line.itemId] ?? 0) + need;
      }
    }

    visited.remove(curBomId);
  }

  await _recurse(bomId, multiplier);
  return acc;
}

/// 폭발 결과 대비 현재 재고(onHand)로 부족량 계산
Future<List<ShortageLine>> calcShortagesForProduction({
  required BomRepo bomRepo,
  required InventoryService inventory,// getQtyOnHand(itemId) 존재 가정
  required String bomId,
  required double produceQty,
}) async {
  final needs = await explodeBom(bomRepo: bomRepo, bomId: bomId, multiplier: produceQty);
  final List<ShortageLine> out = [];
  for (final e in needs.entries) {
    final onHand = await inventory.getQtyOnHand(e.key); // 프로젝트 구현 사용
    final shortage = (e.value - onHand);
    if (shortage > 0) {
      out.add(ShortageLine(itemId: e.key, need: e.value, onHand: onHand, shortage: shortage));
    }
  }
  return out;
}
