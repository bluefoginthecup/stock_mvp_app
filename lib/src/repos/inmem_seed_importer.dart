import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/item.dart';
import '../models/folder_node.dart';
import 'inmem_repo.dart';
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
  }

}
