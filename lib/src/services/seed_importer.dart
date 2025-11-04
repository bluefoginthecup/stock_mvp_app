// lib/src/services/seed_importer.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/item.dart';
import '../models/folder_node.dart';
import '../models/bom.dart';
import '../models/lot.dart'; // ✅ Practical-MIN: Lot 모델
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

  /// assets 에서 통합 임포트 (BOM/Lots 옵션)
  Future<void> importUnifiedFromAssets({
    required String itemsAssetPath,
    required String foldersAssetPath,
    String? bomAssetPath,   // optional
    String? lotsAssetPath,  // ✅ optional (Practical-MIN)
    bool clearBefore = false,
  }) async {
    _log('Loading assets...');
    String itemsJson, foldersJson, bomJson = '', lotsJson = '';
    try {
      itemsJson   = await rootBundle.loadString(itemsAssetPath);
      foldersJson = await rootBundle.loadString(foldersAssetPath);
      if (bomAssetPath != null && bomAssetPath.isNotEmpty) {
        bomJson = await rootBundle.loadString(bomAssetPath);
      }
      if (lotsAssetPath != null && lotsAssetPath.isNotEmpty) {
        lotsJson = await rootBundle.loadString(lotsAssetPath);
      }
      _log('Loaded: items(${itemsJson.length}B), folders(${foldersJson.length}B), '
          'bom(${bomJson.isEmpty ? "none" : "${bomJson.length}B"}), '
          'lots(${lotsJson.isEmpty ? "none" : "${lotsJson.length}B"})');
    } catch (e) {
      _log('❌ Asset load failed: $e');
      rethrow;
    }

    await importAll(
      itemsJson: itemsJson,
      foldersJson: foldersJson,
      bomJson: bomJson,
      lotsJson: lotsJson, // ✅
      clearBefore: clearBefore,
    );

    // 디버그 편의 로그 (repo 가 지원할 때만)
    final dyn = itemRepo as dynamic;
    if (dyn.listFolderChildren is Function) {
      try {
        final roots = await dyn.listFolderChildren(null);
        print('🟢 ROOT FOLDERS: ${roots.map((f) => f.name).toList()}');
      } catch (_) {}
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

  /// JSON 문자열 3(+1 lots)종을 직접 받아 임포트
  Future<void> importAll({
    required String itemsJson,
    required String foldersJson,
    required String bomJson, // 빈 문자열일 수 있음
    String lotsJson = '',    // ✅ 기본값 빈 문자열
    bool clearBefore = false,
  }) async {
    dynamic itemsPayload, foldersPayload, bomPayload, lotsPayload;

    try {
      itemsPayload   = jsonDecode(itemsJson);
      foldersPayload = jsonDecode(foldersJson);
      bomPayload     = bomJson.trim().isEmpty ? const [] : jsonDecode(bomJson);
      lotsPayload    = lotsJson.trim().isEmpty ? const [] : jsonDecode(lotsJson);
      _log('Decoded JSON OK.');

      // 가벼운 구조 로그
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
    final lotsMap = _parseLotsV1(lotsPayload, tag: 'lots.json'); // ✅ itemId -> List<Lot>

    _log('Parsed -> items:${items.length}, folders:${folders.length}, bomRows:${bomRows.length}, lotsItems:${lotsMap.length}');
    if (items.isEmpty)  _log('⚠️ items가 0개입니다. payload type=${itemsPayload.runtimeType}, top-level=${_topKeys(itemsPayload)}');
    if (bomRows.isEmpty) _log('ℹ️ bomRows가 0개입니다. (정상일 수도 있음)');
    if (lotsMap.isEmpty) _log('ℹ️ lots가 비어있습니다. (정상일 수도 있음)');

    // 초기화
    if (clearBefore) {
      await _clearAllIfSupported();
    }

    // Folders (repo 가 폴더생성 지원시 생성)
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

    // ✅ LOTS upsert (repo 가 지원할 때만)
    _persistLotsIfSupported(lotsMap);

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
      // 1) 임포트 친화 정규화
      final m = _normalizeItemMap(Map<String, dynamic>.from(e));

      // 2) 확정: Practical-MIN 정합성 위해 Item.fromJson 사용
      try {
        // 기본 보호: id 없으면 스킵
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) {
          _log('[$tag] skip row#$idx: empty id');
          continue;
        }
        // 안전 기본값(선택): conversion_mode 없을 때
        m['conversion_mode'] ??= 'fixed';

        final it = Item.fromJson(m);
        out.add(it);
      } catch (err) {
        _log('[$tag] skip row#$idx: Item parse error $err');
      }
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

  /// ✅ Lots 파서: lots 배열 또는 {lots:[...]} 모두 지원
  Map<String, List<Lot>> _parseLotsV1(dynamic payload, {String tag = ''}) {
    final list = (payload is List)
        ? payload
        : (payload is Map && payload['lots'] is List)
        ? (payload['lots'] as List)
        : const [];

    if (list.isEmpty) {
      _log('[$tag] No lots. shape=${_topKeys(payload)}');
      return const {};
    }

    final byItem = <String, List<Lot>>{};
    var idx = 0;
    for (final e in list) {
      idx++;
      if (e is! Map) {
        _log('[$tag] skip row#$idx: not a Map');
        continue;
      }
      final m = Map<String, dynamic>.from(e);
      try {
        final lot = Lot.fromJson(m);
        byItem.putIfAbsent(lot.itemId, () => []).add(lot);
      } catch (err) {
        _log('[$tag] skip row#$idx: parse error $err');
      }
    }
    return byItem;
  }

  // ===== Persist helpers =====

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

  /// ✅ Lots upsert: repo 가 upsertLots(itemId, List<Lot>) 지원할 때만 수행
  void _persistLotsIfSupported(Map<String, List<Lot>> byItem) {
    if (byItem.isEmpty) return;
    try {
      final dyn = itemRepo as dynamic;
      if (dyn.upsertLots is! Function) {
        _log('Lots persistence not supported by repo (no upsertLots). Skipped.');
        return;
      }
      var itemsCnt = 0, lotsCnt = 0;
      byItem.forEach((itemId, lots) {
        dyn.upsertLots(itemId, lots);
        itemsCnt++;
        lotsCnt += lots.length;
      });
      _log('Lots persisted: items=$itemsCnt lots=$lotsCnt');
    } catch (e) {
      _log('Lots persist failed: $e');
    }
  }

  // ===== Helpers =====

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

  // flat 컬럼들을 stockHints 맵으로 추출 (임포트 친화 정규화)
  Map<String, dynamic>? _extractStockHints(Map<String, dynamic> m) {
    num? _numOrNull(dynamic v) {
      if (v == null || (v is String && v.trim().isEmpty)) return null;
      return _toNum(v);
    }
    String? _strOrNull(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    final qty             = _numOrNull(m['stockHints_qty'] ?? m['h_qty'] ?? m['qty']); // qty는 seed 초기재고 정책과도 겹치므로 우선 보관
    final usableQtyM      = _numOrNull(m['usable_qty_m'] ?? m['usableQtyM']);
    final unitIn          = _strOrNull(m['unit_in'] ?? m['unitIn']);
    final unitOut         = _strOrNull(m['unit_out'] ?? m['unitOut'] ?? m['unit']); // unitOut 없으면 unit 참고
    final conversionRate  = _numOrNull(m['conversion_rate'] ?? m['conversionRate']);

    final hasAny = qty != null || usableQtyM != null || unitIn != null || unitOut != null || conversionRate != null;
    if (!hasAny) return null;

    return {
      if (qty != null) 'qty': qty,
      if (usableQtyM != null) 'usable_qty_m': usableQtyM,
      if (unitIn != null) 'unit_in': unitIn,
      if (unitOut != null) 'unit_out': unitOut,
      if (conversionRate != null) 'conversion_rate': conversionRate,
    };
  }

  /// items.json 의 1 row(Map)를 임포트 친화적으로 정규화
  Map<String, dynamic> _normalizeItemMap(Map<String, dynamic> src) {
    final m = Map<String, dynamic>.from(src);

    // 기본 단위
    m['unit'] = (m['unit'] ?? 'EA');

    // folder 오탈자/대소문자 정규화
    if (m['folder'] is String) {
      final f0 = (m['folder'] as String).trim().toLowerCase();
      if (f0 == 'semifinished' || f0 == 'semifinished') m['folder'] = 'SemiFinished';
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

    // flat → stockHints 묶기 (이미 stockHints가 있으면 보강만)
    final extracted = _extractStockHints(m);
    if (extracted != null) {
      final curr = (m['stockHints'] is Map) ? Map<String, dynamic>.from(m['stockHints']) : <String, dynamic>{};
      m['stockHints'] = {...curr, ...extracted};
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
