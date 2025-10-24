import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/item.dart';
import '../models/folder_node.dart';
import 'inmem_repo.dart';
import '../models/bom.dart';
import 'dart:collection' show SplayTreeSet;

/// InMemoryRepo용 시드 로더
class InMemorySeedLoader {
  final InMemoryRepo repo;
  InMemorySeedLoader(this.repo);

  /// 1️⃣ 초기 폴더 루트 (Finished / SemiFinished / Raw / Sub)
  Future<void> ensureRootFolders() async {
    if (repo.folderCount > 0) return;

    const roots = ['Finished', 'SemiFinished', 'Raw', 'Sub'];
    for (final name in roots) {
      final id = repo.uuid.v4();
      final node = FolderNode(
        id: id,
        name: name,
        depth: 1,
        parentId: null,
        order: 0,
      );
      repo.folders[id] = node;
      repo.childrenIndex.putIfAbsent(null, () => SplayTreeSet(
            (a, b) => repo.folders[a]!.name.compareTo(repo.folders[b]!.name),
      )).add(id);
    }
  }
  /// 2️⃣ JSON 시드 불러오기 (예: assets/seeds/initial_stock.json)
  Future<void> loadFromAsset(String assetPath) async {
    final text = await rootBundle.loadString(assetPath);
    final data = jsonDecode(text);

    final folders = (data['folders'] as List?)
        ?.map((e) => FolderNode.fromJson(e))
        .toList() ?? [];
    final items = (data['items'] as List?)
        ?.map((e) => Item.fromJson(e))
        .toList() ?? [];

    // 🔴 중요: 시드에 폴더가 없을 때만 루트 생성
    if (folders.isEmpty) {
      await ensureRootFolders();
    }

    await repo.importSeed(folders: folders, items: items);


    // ✅ BOM 시드 처리: "boms" 섹션이 있으면 upsert
    final boms = data['boms'];

        if (boms is List && boms.isNotEmpty) {
          // 1) (root,parent)별로 그룹핑
          final Map<(String,String), List<BomRow>> grouped = {};
          double _toDouble(dynamic v, double fallback) {
            if (v is num) return v.toDouble();
            if (v is String) return double.tryParse(v) ?? fallback;
            return fallback;
          }
          for (final row in boms) {
            if (row is! Map) continue;
            final rootStr  = row['root'] as String?;
            final parentId = row['parentItemId'] as String?;
            final compId   = row['componentItemId'] as String?;
            final kindStr  = row['kind'] as String?;
            if (rootStr == null || parentId == null || compId == null || kindStr == null) continue;

            // ✅ qtyPer / wastePct 안전 파싱 + 정규화
                    double qtyPer = _toDouble(row['qtyPer'], 1.0);
            if (qtyPer <= 0) qtyPer = 1.0;
            double waste = _toDouble(row['wastePct'], 0.0);
            // 퍼센트로 들어오면(>1) → 비율로 변환
            if (waste > 1.0) waste = waste / 100.0;
            // 범위 클램프(0..1)
            if (waste < 0.0) waste = 0.0;
            if (waste > 1.0) waste = 1.0;

            final bomRow = BomRow(
              root: BomRootX.fromString(rootStr),
              parentItemId: parentId,
              componentItemId: compId,
              kind: BomKindX.fromString(kindStr),
              qtyPer: qtyPer,
               wastePct: waste,
            );
            grouped.putIfAbsent((rootStr, parentId), () => []).add(bomRow);
          }
          // 2) 그룹별로 "통째 교체" → 덮어쓰기/유실 방지
          for (final entry in grouped.entries) {
            final root = BomRootX.fromString(entry.key.$1);
            final parentId = entry.key.$2;
            final rows = entry.value;
            // 중복 방지: (component,k ind) 기준으로 정리
            final dedup = <String, BomRow>{};
            for (final r in rows) {
              dedup['${r.componentItemId}|${r.kind.index}'] = r;
            }
            await repo.replaceBomRows(root: root, parentItemId: parentId, rows: dedup.values.toList());
          }
        }

  }

}
