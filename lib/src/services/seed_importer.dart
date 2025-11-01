// lib/src/services/seed_importer.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/item.dart';
import '../models/folder_node.dart';
import '../models/bom.dart';
import '../repos/repo_interfaces.dart';



class UnifiedSeedImporter {
  final ItemRepo itemRepo;
  final BomRepo? bomRepo;
  final bool verbose;              // 👈 추가

  UnifiedSeedImporter({
    required this.itemRepo,
    this.bomRepo,
    this.verbose = false,          // 👈 기본 off
  });

  void _log(Object msg) { if (verbose) print('[SeedImporter] $msg'); }

  Future<void> importUnifiedFromAssets({
    required String itemsAssetPath,
    required String foldersAssetPath,
    required String bomAssetPath,
    bool clearBefore = false,
  }) async {
    _log('Loading assets...');
    String itemsJson, foldersJson, bomJson;
    try {
      itemsJson   = await rootBundle.loadString(itemsAssetPath);
      foldersJson = await rootBundle.loadString(foldersAssetPath);
      bomJson     = await rootBundle.loadString(bomAssetPath);
      _log('Loaded: items(${itemsJson.length}B), folders(${foldersJson.length}B), bom(${bomJson.length}B)');
    } catch (e) {
      _log('❌ Asset load failed: $e');
      rethrow;
    }

    await importAll(
      itemsJson: itemsJson,
      foldersJson: foldersJson,
      bomJson: bomJson,
      clearBefore: clearBefore,
    );
    // ✅ 시드 임포트 끝난 직후에 루트 목록 출력
    final dyn = itemRepo as dynamic;
    if (dyn.listFolderChildren is Function) {
      final roots = await dyn.listFolderChildren(null);
      print('🟢 ROOT FOLDERS: ${roots.map((f) => f.name).toList()}');
    }

// ✅ Finished 아이템 몇 개의 경로도 같이 확인
    for (final entry in (await dyn.searchItemsGlobal('rouen_gray'))) {
      print('🔹 Item ${entry.id}  folder=${entry.folder}/${entry.subfolder}/${entry.subsubfolder}');
      print('   pathIds=${dyn.itemPathIds(entry.id)}');
    }

  }

  Future<void> importAll({
    required String itemsJson,
    required String foldersJson,
    required String bomJson,
    bool clearBefore = false,
  }) async {
    dynamic itemsPayload, foldersPayload, bomPayload;

    try {
      itemsPayload   = jsonDecode(itemsJson);
      foldersPayload = jsonDecode(foldersJson);
      bomPayload     = jsonDecode(bomJson);
      _log('Decoded JSON OK.');

      // ✅ 시작부 로그 (payload 모양/키 점검)
      _log('itemsPayload top=${_topKeys(itemsPayload)}');
      if (itemsPayload is Map) {
        final itemsList = itemsPayload['items'] as List?;
        _log('itemsPayload["items"] len=${itemsList?.length ?? 0}');
        if (itemsList != null && itemsList.isNotEmpty && itemsList.first is Map) {
          final first = itemsList.first as Map;
          _log('first item keys=${first.keys.toList()}');
          _log('first item preview=${first['id']}/${first['sku']}/${first['unit']} '
              'path=${first['path']} folder=${first['folder']}/${first['subfolder']}/${first['subsubfolder']}');
        }
      }


    } catch (e) {
      _log('❌ JSON decode failed: $e');
      rethrow;
    }

    // 파싱
    final items   = _parseItemsV1(itemsPayload, tag: 'items.json');
    final folders = _parseFoldersV1(foldersPayload, tag: 'folders.json');
    final bomRows = _parseBomV1(bomPayload, tag: 'bom.json');

    _log('Parsed -> items:${items.length}, folders:${folders.length}, bomRows:${bomRows.length}');
    if (items.isEmpty) {
      _log('⚠️ items가 0개입니다. payload type=${itemsPayload.runtimeType}, top-level=${_topKeys(itemsPayload)}');
    }
    if (bomRows.isEmpty) {
      _log('ℹ️ bomRows가 0개입니다. (정상일 수도 있음)');
    }

    if (clearBefore) {
      await _clearAllIfSupported();
    }

    // Folders (현재 저장 인터페이스 없음)
    if (folders.isNotEmpty) _log('Folders parsed (${folders.length}) — UI 트리 용으로만 사용');

    // Items upsert
    var upsertOk = 0, upsertFail = 0;
    for (final it in items) {
      try {
        await itemRepo.upsertItem(it);
        upsertOk++;
      } catch (e) {
        upsertFail++;
        _log('❌ upsertItem failed for id=${it.id}: $e');
      }
    }
    _log('Items upsert done: ok=$upsertOk fail=$upsertFail');

    // ✅ 예전 동작과 동일하게: 레거시 경로 → _itemPaths 백필
    try {
      final dyn = itemRepo as dynamic;
      if (dyn.backfillPathsFromLegacy is Function) {
        await dyn.backfillPathsFromLegacy(createFolders: false); // 폴더는 이미 생성됨
        _log('backfillPathsFromLegacy() done.');
      } else {
        _log('backfillPathsFromLegacy() not available on repo (skipped).');
      }
    } catch (e) {
      _log('backfillPathsFromLegacy() failed: $e');
    }

    // BOM upsert
    if (bomRepo == null) {
      if (bomRows.isNotEmpty) _log('⚠️ bomRepo가 null이라 BOM을 저장하지 않았습니다.');
    } else {
      var bomOk = 0, bomFail = 0;
      for (final r in bomRows) {
        try {
          await bomRepo!.upsertBomRow(r);
          bomOk++;
        } catch (e) {
          bomFail++;
          _log('❌ upsertBomRow failed for parent=${r.parentItemId} comp=${r.componentItemId}: $e');
        }
      }
      _log('BOM upsert done: ok=$bomOk fail=$bomFail');
    }
    // 🔔 임포트 완료 후 UI 강제 갱신 (ChangeNotifier 기반 Repo)
        try {
          final dyn = itemRepo as dynamic;
          if (dyn.notifyListeners is Function) {
            if (verbose) _log('notifyListeners() called.');
            dyn.notifyListeners();
          }
        } catch (_) {}
  }

  // ===== Parsers =====

  List<Item> _parseItemsV1(dynamic payload, {String tag = ''}) {
    final list = (payload is Map && payload['items'] is List)
        ? (payload['items'] as List)
        : (payload is List ? payload : const []);

    if (list.isEmpty) _log('[$tag] No items found. shape=${_topKeys(payload)}');

    final out = <Item>[];
    var idx = 0;
    for (final e in list) {
      idx++;
      if (e is! Map) {
        _log('[$tag] skip row#$idx: not a Map');
        continue;
      }
      final m = Map<String, dynamic>.from(e);

      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) {
        _log('[$tag] skip row#$idx: empty id');
        continue;
      }

      final String name = (m['name'] ?? '').toString();
      final String sku  = (m['sku'] ?? id).toString();
      final String unit = (m['unit'] ?? 'Ea').toString();

      String folder = 'Uncategorized';
      String? subfolder;
      String? subsubfolder;
      if (m['path'] is List) {
        final p = (m['path'] as List).map((e) => e?.toString() ?? '').toList();
        if (p.isNotEmpty && p[0].trim().isNotEmpty) folder = p[0];
        if (p.length >= 2 && p[1].trim().isNotEmpty) subfolder = p[1];
        if (p.length >= 3 && p[2].trim().isNotEmpty) subsubfolder = p[2];
      }

      // 필수 파라미터 충족
      final it = Item(
        id: id,
        name: name,
        displayName: m['displayName'] as String?,
        sku: sku,
        unit: unit,
        folder: folder,
        subfolder: subfolder,
        subsubfolder: subsubfolder,
        minQty: 0,
        qty: 0,
      );
      out.add(it);
    }

    if (out.isNotEmpty) {
      _log('[$tag] first item => id=${out.first.id}, sku=${out.first.sku}, folder=${out.first.folder}/${out.first.subfolder}/${out.first.subsubfolder}');
    }
    return out;
  }

  List<FolderNode> _parseFoldersV1(dynamic payload, {String tag = ''}) {
    final list = (payload is Map && payload['folders'] is List)
        ? (payload['folders'] as List)
        : (payload is List ? payload : const []);

    final folders = list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return FolderNode(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        depth: (m['depth'] is int) ? m['depth'] : 1,
        parentId: (m['parentId']?.toString().isEmpty ?? true) ? null : m['parentId'].toString(),
        order: (m['order'] is int) ? m['order'] : 0,
      );
    }).toList();
    // 가능한 경우 폴더를 실제로 저장 (부모 → 자식 순), 시드ID→실ID 매핑 유지
        () async {
            try {
              final dyn = itemRepo as dynamic;
              if (dyn.createFolderNode is Function) {
                // depth 오름차순으로 부모 먼저 생성
                folders.sort((a, b) => a.depth.compareTo(b.depth));
                final Map<String, String> idMap = {}; // seedId -> repoId
                var ok = 0, skip = 0;
                for (final f in folders) {
                  final String? parentSeedId = f.parentId;
                  final String? parentRepoId =
                      parentSeedId == null ? null : idMap[parentSeedId];
                  try {
                    final created = await dyn.createFolderNode(
                      parentId: parentRepoId,
                      name: f.name,
                    );
                    // created.id 를 시드 id에 매핑
                    if (created != null && created.id is String) {
                      idMap[f.id] = created.id as String;
                    }
                    ok++;
                  } catch (e) {
                    // 중복 등으로 실패할 수 있음 → 스킵하고 진행
                    skip++;
                    if (verbose) _log('Folder create skipped (${f.name}): $e');
                  }
                }
                if (verbose) _log('Folders persisted: $ok (skipped:$skip)');
              } else {
                if (verbose) _log('Folder persistence not supported by repo.');
              }
            } catch (e) {
              if (verbose) _log('Folder persist failed: $e');
            }
          }();


    return folders;
  }

  List<BomRow> _parseBomV1(dynamic payload, {String tag = ''}) {
    final list = (payload is Map && payload['bom'] is List)
        ? (payload['bom'] as List)
        : (payload is List ? payload : const []);
    if (list.isEmpty) _log('[$tag] No bom rows. shape=${_topKeys(payload)}');

    final out = <BomRow>[];
    var idx = 0;
    for (final e in list) {
      idx++;
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final parentId = (m['parentId'] ?? '').toString();
      final componentItemId = (m['componentItemId'] ?? '').toString();
      if (parentId.isEmpty || componentItemId.isEmpty) {
        _log('[$tag] skip bom#$idx: missing ids');
        continue;
      }
      final kindStr = (m['kind'] ?? '').toString().toLowerCase();
      final qtyPer = _toNum(m['qtyPer'], fallback: 1).toDouble();
      final wastePct = _toNum(m['wastePct'], fallback: 0).toDouble();

      out.add(BomRow(
        root: BomRoot.finished, // v3 제너레이터 기준
        parentItemId: parentId,
        componentItemId: componentItemId,
        kind: _parseBomKind(kindStr),
        qtyPer: qtyPer,
        wastePct: wastePct,
      ));
    }
    if (out.isNotEmpty) {
      final r = out.first;
      _log('[$tag] first bom => parent=${r.parentItemId}, comp=${r.componentItemId}, kind=${r.kind}, qty=${r.qtyPer}');
    }
    return out;
  }

  Future<void> _clearAllIfSupported() async {
    try {
      final dyn = itemRepo as dynamic;
      if (dyn.clearAll is Function) {
        _log('Clearing repo...');
        await dyn.clearAll();
      }
    } catch (_) {}
  }

  BomKind _parseBomKind(String s) {
    switch (s) {
      case 'semi':
      case 'semifinished':
        return BomKind.semi;
      case 'sub':
      case 'material':
        return BomKind.sub;
      case 'raw':
        return BomKind.raw;
      default:
        return BomKind.semi;
    }
  }

  String _topKeys(dynamic p) {
    if (p is Map) return 'Map keys=${p.keys.toList()}';
    if (p is List) return 'List len=${p.length}';
    return p.runtimeType.toString();
  }

  num _toNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    final t = v.toString().replaceAll(',', '.');
    return num.tryParse(t) ?? fallback;
  }
}
