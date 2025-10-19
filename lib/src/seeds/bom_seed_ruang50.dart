import 'package:uuid/uuid.dart';
import '../models/bom.dart';
import '../repos/bom_repo.dart';
import '../repos/repo_interfaces.dart'; // ItemRepo 등
import '../repos/repo_views.dart'; // ItemRepo 등


final _uuid = const Uuid();

Future<void> seedBom_RuangGrey_50BasicCover({
  required ItemRepo itemRepo,
  required BomRepo bomRepo,
}) async {
  // 1) 루트(완제품)
  final finished = await itemRepo.searchItemsGlobal('루앙 그레이 50기본형 방석커버');
  if (finished.isEmpty) {
    throw Exception('완제품 아이템이 없습니다: 루앙 그레이 50기본형 방석커버');
  }
  final finishedId = finished.first.id;

  // 2) 구성품 찾기
  Future<String> idOf(String q) async {
    final res = await itemRepo.searchItemsGlobal(q);
    if (res.isEmpty) throw Exception('아이템이 없습니다: $q');
    return res.first.id;
  }

  final idEmb  = await idOf('자수물 루앙 그레이');          // pcs 1
  final idSash = await idOf('솜샤시 50기본형');            // pcs 1
  final idBack = await idOf('뒷지 도트 화이트 50기본형');   // pcs 1
  final idPipe = await idOf('파이핑 화이트');               // m   2.0

  final now = DateTime.now();
  final bom = Bom(
    id: _uuid.v4(),
    itemId: finishedId,
    name: '루앙 그레이 50기본형 방석커버 BOM',
    lines: [
      BomLine(id: _uuid.v4(), itemId: idEmb,  qty: 1.0, unit: 'pcs'),
      BomLine(id: _uuid.v4(), itemId: idSash, qty: 1.0, unit: 'pcs'),
      BomLine(id: _uuid.v4(), itemId: idBack, qty: 1.0, unit: 'pcs'),
      BomLine(id: _uuid.v4(), itemId: idPipe, qty: 2.0, unit: 'm'),
    ],
    createdAt: now,
    updatedAt: now,
    enabled: true,
  );

  // 기존에 같은 itemId로 BOM이 있으면 교체(정책: 최신만 유지)
  final exist = await bomRepo.bomForItem(finishedId);
  if (exist != null) {
    await bomRepo.updateBom(bom.copyWith(id: exist.id));
  } else {
    await bomRepo.createBom(bom);
  }
}
