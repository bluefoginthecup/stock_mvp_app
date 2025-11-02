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
  final bool verbose;

  // 임포트 시 초기재고 채우기 정책 (원하면 false 로 바꿔 0부터 시작)
  static const bool useStockHintsQtyAsInitial = true; // stockHints.qty 를 qty 로 반영
  static const bool useSeedQtyAsInitial = true;       // seedQty 를 qty 로 반영

  UnifiedSeedImporter({
    required this.itemRepo,
    this.bomRepo,
    this.verbose = false,
  });

  void _log(Object msg) {
    if (verbose) print('[SeedImporter] $msg');
  }

  /// assets 에서 통합 임포트 (BOM 은 옵션)
  Future<void> importUnifiedFromAssets({
    required String itemsAssetPath,
    required String foldersAssetPath,
    String? bomAssetPath, // ← optional
    bool clearBefore = false,
  }) async {
    _log('Loading assets...');
    String itemsJson, foldersJson, bomJson = '';
    try {
      itemsJson   = await rootBundle.loadString(itemsAssetPath);
      foldersJson = await rootBundle.loadString(foldersAssetPath);
      if (bomAssetPath != null && bomAssetPath.isNotEmpty) {
        bomJson = await rootBundle.loadString(bomAssetPath);
      }
      _log('Loaded: items(${itemsJson.length}B), folders(${foldersJson.length}B), bom(${bomJson.isEmpty ? "none" : "${bomJson.length}B"})');
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

    // 루트 폴더 / 대표 아이템 경로 확인 로그
    final dyn = itemRepo as dynamic;
    if (dyn.listFolderChildren is Function) {
      final roots = await dyn.listFolderChildren(null);
      print('🟢 ROOT FOLDERS: ${roots.map((f) => f.name).toList()}');
    }
    if (dyn.searchItemsGlobal is Function) {
      try {
        for (final entry in (await dyn.searchItemsGlobal('rouen_gray'))) {
          print('🔹 Item ${entry.id}  folder=${entry.folder}/${entry.subfolder}/${entry.subsubfolder}');
          if (dyn.itemPathIds is Function) {
            print('   pathIds=${dyn.itemPathIds(entry.id)}');
          }
        }
      } catch (_) {}
    }
  }

  /// JSON 문자열 3종을 직접 받아 임포트
  Future<void> importAll({
    required String itemsJson,
    required String foldersJson,
    required String bomJson, // 빈 문자열일 수 있음
    bool clearBefore = false,
  }) async {
    dynamic itemsPayload, foldersPayload, bomPayload;

    try {
      itemsPayload   = jsonDecode(itemsJson);
      foldersPayload = jsonDecode(foldersJson);
      bomPayload     = bomJson.trim().isEmpty ? const [] : jsonDecode(bomJson);
      _log('Decoded JSON OK.');

      // 디버그 로그
      _log('itemsPayload top=${_topKeys(itemsPayload)}');
      if (itemsPayload is Map) {
        final itemsList = itemsPayload['items'] as List?;
        _log('itemsPayload["items"] len=${itemsList?.length ?? 0}');
        if (itemsList != null && itemsList.isNotEmpty && itemsList.first is Map) {
          final first = itemsList.first as Map;
          _log('first item keys=${first.keys.toList()}');
          _log('first item preview=${first['id']}/${first['sku']}/${first['unit']} '
              'folder=${first['folder']}/${first['subfolder']}/${first['subsubfolder']} kind=${first['kind']}');
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

    // Folders (저장 기능이 있는 Repo라면 실제 저장)
    if (folders.isNotEmpty) _persistFoldersIfSupported(folders);

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

    // 레거시 경로 기반 path 백필 (Repo 가 제공할 때만)
    try {
      final dyn = itemRepo as dynamic;
      if (dyn.backfillPathsFromLegacy is Function) {
        await dyn.backfillPathsFromLegacy(createFolders: true);
        _log('backfillPathsFromLegacy() done.');
      } else {
        _log('backfillPathsFromLegacy() not available on repo (skipped).');
      }
    } catch (e) {
      _log('backfillPathsFromLegacy() failed: $e');
    }

    // BOM upsert
    if (bomRepo == null) {
      if (bomRows.isNotEmpty) _log('⚠️ bomRepo == null → BOM 저장 생략');
    } else {
      var bomOk = 0, bomFail = 0;
      for (final r in bomRows) {
        try {
          await bomRepo!.upsertBomRow(r);
          bomOk++;
        } catch (e) {
          bomFail++;
          _log('❌ upsertBomRow failed parent=${r.parentItemId} comp=${r.componentItemId}: $e');
        }
      }
      _log('BOM upsert done: ok=$bomOk fail=$bomFail');
    }

    // UI 갱신(ChangeNotifier 기반 Repo)
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
      final m = _normalizeItemMap(Map<String, dynamic>.from(e));

      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) {
        _log('[$tag] skip row#$idx: empty id');
        continue;
      }

      final String name = (m['name'] ?? '').toString();
      final String sku  = (m['sku'] ?? id).toString();
      final String unit = (m['unit'] ?? 'EA').toString();

      // folder/sub*/subsub* (normalize 에서 path→folder 변환 이미 수행)
      final String folder = (m['folder'] ?? 'Uncategorized').toString();
      final String? subfolder =
      (m['subfolder']?.toString().isEmpty ?? true) ? null : m['subfolder'].toString();
      final String? subsubfolder =
      (m['subsubfolder']?.toString().isEmpty ?? true) ? null : m['subsubfolder'].toString();

      final it = Item(
        id: id,
        name: name,
        displayName: m['displayName'] as String?,
        sku: sku,
        unit: unit,
        folder: folder,
        subfolder: subfolder,
        subsubfolder: subsubfolder,
        minQty: (m['minQty'] is int) ? m['minQty'] : (int.tryParse('${m['minQty']}') ?? 0),
        qty: (m['qty'] is int) ? m['qty'] : (int.tryParse('${m['qty']}') ?? 0),
        kind: m['kind'] as String?,
        attrs: (m['attrs'] is Map) ? Map<String, dynamic>.from(m['attrs']) : null,
        stockHints: StockHints.fromJson(m['stockHints']),
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

    _persistFoldersIfSupported(folders);
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

  // ===== Helpers =====

  Future<void> _clearAllIfSupported() async {
    try {
      final dyn = itemRepo as dynamic;
      if (dyn.clearAll is Function) {
        _log('Clearing repo...');
        await dyn.clearAll();
      }
    } catch (_) {}
  }

  void _persistFoldersIfSupported(List<FolderNode> folders) {
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
            final String? parentRepoId = parentSeedId == null ? null : idMap[parentSeedId];
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

  /// items.json 의 1 row(Map)를 임포트 친화적으로 정규화
  Map<String, dynamic> _normalizeItemMap(Map<String, dynamic> src) {
    final m = Map<String, dynamic>.from(src);

    // 기본 단위
    m['unit'] = (m['unit'] ?? 'EA');

    // folder 오탈자/대소문자 정규화
    if (m['folder'] is String) {
      final f0 = (m['folder'] as String).trim().toLowerCase();
      if (f0 == 'semiFinished' || f0 == 'semifinished') m['folder'] = 'SemiFinished';
      else if (f0 == 'finished') m['folder'] = 'Finished';
      else if (f0 == 'sub') m['folder'] = 'Sub';
    }

    // kind 없으면 folder 기준 유추
    m['kind'] ??= (() {
      final f = (m['folder'] ?? '').toString().toLowerCase();
      if (f.startsWith('semi')) return 'SemiFinished';
      if (f.startsWith('finish')) return 'Finished';
      if (f.startsWith('sub')) return 'Sub';
      return null;
    })();

    // path 만 있고 folder/sub* 비어 있으면 path로 채움
    if ((m['folder'] ?? '').toString().isEmpty) {
      final p = m['path'];
      if (p is List && p.isNotEmpty) {
        m['folder'] = (p.elementAt(0) ?? '').toString();
        if (p.length > 1) m['subfolder'] = (p.elementAt(1) ?? '').toString();
        if (p.length > 2) m['subsubfolder'] = (p.elementAt(2) ?? '').toString();
      }
    }

    // 초기 재고 매핑
    if (m['qty'] == null) {
      if (useStockHintsQtyAsInitial && m['stockHints'] is Map && (m['stockHints']['qty'] != null)) {
        m['qty'] = m['stockHints']['qty'];
      }
      if (m['qty'] == null && useSeedQtyAsInitial && m['seedQty'] != null) {
        m['qty'] = m['seedQty'];
      }
      m['qty'] ??= 0;
    }

    // minQty 기본값
    m['minQty'] ??= 0;
    return m;
  }
}
