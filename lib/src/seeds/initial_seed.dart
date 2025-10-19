// lib/src/seeds/initial_seed.dart
import 'package:flutter/foundation.dart';
import '../repos/inmem_repo.dart';
import '../repos/repo_interfaces.dart'; // ItemRepo 등(이미 존재)
import 'bom_seed_ruang50.dart';         // 앞서 만든 레시피 시드
import '../repos/inmem_seed_importer.dart';     // 질문에 준 loader 코드 파일명에 맞춰 import

/// 앱 시작 시 1회 실행해 초기 데이터(폴더/아이템/BOM)를 준비.
/// - 폴더/아이템은 assets JSON에서 로드
/// - BOM(레시피)은 코드 시드로 주입
Future<void> runInitialSeeds({
  required InMemoryRepo inmem,  // 루트 생성/저장소 접근
  required ItemRepo itemRepo,
  required BomRepo bomRepo,
  String assetPath = 'assets/seeds/initial_seed.json',
}) async {
  final loader = InMemorySeedLoader(inmem);

  // 1) 루트 폴더 보장 (Finished / SemiFinished / Raw / Sub)
  await loader.ensureRootFolders();

  // 2) 폴더/아이템 JSON 시드 로드 (없으면 ensureRootFolders만 수행됨)
  try {
    await loader.loadFromAsset(assetPath);
  } catch (e) {
    // 에셋이 없거나 비어있어도 앱이 뜨도록 경고만 출력
    debugPrint('[InitialSeed] loadFromAsset($assetPath) skipped: $e');
  }

  // 3) 레시피(BOM) 시드 주입 (코드 기반)
  try {
    await seedBom_RuangGrey_50BasicCover(itemRepo: itemRepo, bomRepo: bomRepo);
    debugPrint('[InitialSeed] BOM seed (루앙 그레이 50기본형 방석커버) injected.');
  } catch (e) {
    debugPrint('[InitialSeed] BOM seed skipped: $e');
  }
}
