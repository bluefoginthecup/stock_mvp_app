// lib/src/services/seed_importer.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/item.dart';
import '../models/folder_node.dart';
import '../models/bom.dart';
import '../models/lot.dart'; // ✅ Practical-MIN: Lot 모델
import '../repos/repo_interfaces.dart';
import '../repos/drift_unified_repo.dart'; // ✅ 폴더/lot/path 백필용 (InMemoryRepo)
import 'package:flutter/widgets.dart';            // ⬅️ BuildContext
import 'package:provider/provider.dart';          // ⬅️ context.read()

class UnifiedSeedImporter {
  /// 아이템 저장용 (지금은 SqliteItemRepo)
  final ItemRepo itemRepo;

  /// BOM 저장용 (지금은 InMemoryRepo 래핑)
  final BomRepo? bomRepo;

  /// 폴더 트리 / lots / path 백필 담당 (지금은 InMemoryRepo)
  ///
  /// - upsertFolderNode / createFolderNodeWithId / listFolderChildren
  /// - backfillPathsFromLegacy(createFolders:false)
  /// - upsertLots
  final DriftUnifiedRepo? drift;

  final bool verbose;

  // 임포트 시 초기재고 채우기 정책 (원하면 false 로 바꿔 0부터 시작)
  static const bool useStockHintsQtyAsInitial = true; // stockHints.qty 를 qty 로 반영
  static const bool useSeedQtyAsInitial = true;       // seedQty 를 qty 로 반영

  UnifiedSeedImporter({
    required this.itemRepo,
    this.bomRepo,
    this.drift,
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

    // 디버그 편의 로그
    // - 폴더 트리는 drift(있으면) 우선
    final dynFolders = (drift ?? itemRepo) as dynamic;
    try {
      if (dynFolders.listFolderChildren is Function) {
        final roots = await dynFolders.listFolderChildren(null);
        print('🟢 ROOT FOLDERS: ${roots.map((f) => f.name).toList()}');
      }
    } catch (_) {}

    // - 아이템 검색은 itemRepo(SQLite) 기준
    final dynItems = itemRepo as dynamic;
    if (dynItems.searchItemsGlobal is Function) {
      try {
        for (final entry in (await dynItems.searchItemsGlobal('rouen_gray'))) {
          print('🔹 Item ${entry.id}  folder=${entry.folder}/${entry.subfolder}/${entry.subsubfolder}');
          if (dynFolders.itemPathIds is Function) {
            print('   pathIds=${dynFolders.itemPathIds(entry.id)}');
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

    // Folders: 시드의 id/parentId를 **보존**하여 저장
    if (folders.isNotEmpty) _persistFoldersIfSupported(folders);
    // Items upsert (트리 지원 repo면 폴더 경로까지 같이 세팅, 아니면 그냥 upsertItem)
    var upsertOk = 0, upsertFail = 0;
    for (final it in items) {
      try {
        bool handledByTree = false;

        try {
          final dyn = itemRepo as dynamic;

          // 여기서 getter 접근 자체가 NoSuchMethod를 낼 수 있으므로
          // 전체를 try로 감싸놓고 실패하면 곧바로 폴백한다.
          final hasPathIdsByNames = dyn.pathIdsByNames is Function;
          final hasCreateItemUnderPath = dyn.createItemUnderPath is Function;

          if (hasPathIdsByNames && hasCreateItemUnderPath) {
            final l1 = (it.folder ?? '').toString();
            final l2 = (it.subfolder ?? '').toString();
            final l3 = (it.subsubfolder ?? '').toString();

            if (l1.isNotEmpty) {
              // 폴더 이름 → 폴더 ID 체인
              final ids = await dyn.pathIdsByNames(
                l1Name: l1,
                l2Name: l2.isEmpty ? null : l2,
                l3Name: l3.isEmpty ? null : l3,
                createIfMissing: true,
              ) as List?;

              final pathIds = (ids ?? const [])
                  .whereType<String>()
                  .toList(growable: false);

              if (pathIds.isNotEmpty) {
                await dyn.createItemUnderPath(
                  pathIds: pathIds,
                  item: it,
                );
                handledByTree = true;
              }
            }
          }
        } catch (_) {
          // pathIdsByNames / createItemUnderPath 가 없는 repo(예: SqliteItemRepo)면
          // 여기로 떨어지고, 아래에서 자동으로 upsertItem 폴백
        }

        // 2) 트리 방식으로 처리 못했으면 그냥 upsertItem
        if (!handledByTree) {
          await itemRepo.upsertItem(it);
        }

        upsertOk++;
      } catch (e) {
        upsertFail++;
        _log('❌ upsertItem failed for id=${it.id}: $e');
      }
    }
    _log('Items upsert done: ok=$upsertOk fail=$upsertFail');

    // ❌ backfillPathsFromLegacy 호출은 이제 필요 없음 (경로는 위에서 바로 세팅)

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

    // ✅ LOTS upsert (→ driftoryRepo 우선)
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
        parentId: (m['parentId']?.toString().isEmpty ?? true)
            ? null
            : m['parentId'].toString(),
        order: (m['order'] is int) ? m['order'] : 0,
      );
    }).toList();

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
        _log('[$tag] skip bom#$idx: missing ids'
            ' (parentId="${parentId.isEmpty ? 'EMPTY' : parentId}",'
            ' componentItemId="${componentItemId.isEmpty ? 'EMPTY' : componentItemId}")');
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
      final dynItem = itemRepo as dynamic;
      if (dynItem.clearAll is Function) {
        _log('Clearing itemRepo...');
        await dynItem.clearAll();
      }

      if (drift != null) {
        final dynMem = drift as dynamic;
        if (dynMem.clearAll is Function) {
          _log('Clearing drift...');
          await dynMem.clearAll();
        }
      }
    } catch (_) {}
  }

  void _persistFoldersIfSupported(List<FolderNode> folders) {
    () async {
      try {
        // 폴더 트리는 drift(있으면) 우선, 없으면 itemRepo에 시도
        final dyn = (drift ?? itemRepo) as dynamic;

        // depth, order 기준으로 부모 먼저
        folders.sort((a, b) {
          final d = a.depth.compareTo(b.depth);
          return d != 0 ? d : a.order.compareTo(b.order);
        });

        var ok = 0, skip = 0, warn = 0;

        // 1) 최우선: upsertFolderNode(FolderNode)
        if (dyn.upsertFolderNode is Function) {
          for (final f in folders) {
            try {
              await dyn.upsertFolderNode(f); // id/parentId 그대로 보존
              ok++;
            } catch (e) {
              skip++;
              if (verbose) {
                _log('Folder upsert skipped (${f.id}:${f.name}): $e');
              }
            }
          }
          if (verbose) {
            _log('Folders persisted via upsertFolderNode: ok=$ok skipped=$skip');
          }

          // 2) 다음: createFolderNodeWithId(...)
        } else if (dyn.createFolderNodeWithId is Function) {
          for (final f in folders) {
            try {
              await dyn.createFolderNodeWithId(
                id: f.id,
                parentId: f.parentId,
                name: f.name,
                depth: f.depth,
                order: f.order,
              );
              ok++;
            } catch (e) {
              // 이미 존재 등 → 스킵
              skip++;
              if (verbose) {
                _log('Folder createWithId skipped (${f.id}:${f.name}): $e');
              }
            }
          }
          if (verbose) {
            _log(
                'Folders persisted via createFolderNodeWithId: ok=$ok skipped=$skip');
          }

          // 3) 마지막 수단: createFolderNode(parentId,name) — ⚠️ id 보존 불가
        } else if (dyn.createFolderNode is Function) {
          _log('⚠️ Repo에 upsertFolderNode/createFolderNodeWithId가 없습니다. '
              'createFolderNode(parentId,name)로 생성하면 시드 id가 보존되지 않습니다.');
          for (final f in folders) {
            try {
              // parentId는 시드 id 이므로, repo에서 같은 id를 찾을 방법이 없으면 그대로 전달 불가
              // 일부 repo가 getFolderById를 지원한다면 보정 가능
              String? parentRepoId = f.parentId;
              if (dyn.getFolderById is Function && f.parentId != null) {
                final parent = await dyn.getFolderById(f.parentId);
                parentRepoId = parent?.id; // 없으면 null
              }
              await dyn.createFolderNode(parentId: parentRepoId, name: f.name);
              ok++;
              warn++;
            } catch (e) {
              skip++;
              if (verbose) {
                _log('Folder create (no-id) skipped (${f.name}): $e');
              }
            }
          }
          if (verbose) {
            _log(
                'Folders persisted via createFolderNode: ok=$ok skipped=$skip (⚠️id 보존 안됨:$warn)');
          }
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
      final dyn = (drift ?? itemRepo) as dynamic;
      if (dyn.upsertLots is! Function) {
        _log(
            'Lots persistence not supported by repo (no upsertLots). Skipped.');
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

    final qty             =
    _numOrNull(m['stockHints_qty'] ?? m['h_qty'] ?? m['qty']); // qty는 seed 초기재고 정책과도 겹치므로 우선 보관
    final usableQtyM      =
    _numOrNull(m['usable_qty_m'] ?? m['usableQtyM']);
    final unitIn          = _strOrNull(m['unit_in'] ?? m['unitIn']);
    final unitOut         =
    _strOrNull(m['unit_out'] ?? m['unitOut'] ?? m['unit']); // unitOut 없으면 unit 참고
    final conversionRate  =
    _numOrNull(m['conversion_rate'] ?? m['conversionRate']);

    final hasAny = qty != null ||
        usableQtyM != null ||
        unitIn != null ||
        unitOut != null ||
        conversionRate != null;
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
      if (f0 == 'Semifinished' || f0 == 'semifinished') {
        m['folder'] = 'SemiFinished';
      } else if (f0 == 'finished') {
        m['folder'] = 'Finished';
      } else if (f0 == 'sub') {
        m['folder'] = 'Sub';
      }
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
      final curr = (m['stockHints'] is Map)
          ? Map<String, dynamic>.from(m['stockHints'])
          : <String, dynamic>{};
      m['stockHints'] = {...curr, ...extracted};
    }

    // 초기 재고 매핑
    if (m['qty'] == null) {
      if (useStockHintsQtyAsInitial &&
          m['stockHints'] is Map &&
          (m['stockHints']['qty'] != null)) {
        m['qty'] = m['stockHints']['qty'];
      }
      if (m['qty'] == null &&
          useSeedQtyAsInitial &&
          m['seedQty'] != null) {
        m['qty'] = m['seedQty'];
      }
      m['qty'] ??= 0;
    }

    // minQty 기본값
    m['minQty'] ??= 0;

    return m;
  }
  // ===== Path resolve helpers (items.json → folders.json 매칭) =====

  String _normName(String s) =>
      s.trim().toLowerCase(); // 지금은 generator가 동일한 이름 쓰니까 이 정도면 충분

  String _mapLegacyL1NameForSeed(String legacy) {
    final v = legacy.trim().toLowerCase();
    switch (v) {
      case 'finished':
        return 'Finished';
      case 'semifinished':
      case 'semi_finished':
        return 'SemiFinished';
      case 'raw':
        return 'Raw';
      case 'sub':
        return 'Sub';
      default:
        if (v.isEmpty) return 'Finished';
        return v[0].toUpperCase() + v.substring(1);
    }
  }

  /// items.json 의 Item 1개에 대해, folders.json 리스트에서 [L1, L2, L3] 폴더ID 체인을 찾아줌.
  /// 못 찾으면 빈 리스트 반환.
  List<String> _resolvePathIdsForItem(Item it, List<FolderNode> folders) {
    final legacyL1 = (it.folder).trim();
    final legacyL2 = (it.subfolder ?? '').trim();
    final legacyL3 = (it.subsubfolder ?? '').trim();

    if (legacyL1.isEmpty && legacyL2.isEmpty && legacyL3.isEmpty) {
      return const [];
    }

    final l1Name = _mapLegacyL1NameForSeed(legacyL1);
    final l1Norm = _normName(l1Name);
    final l2Norm = _normName(legacyL2);
    final l3Norm = _normName(legacyL3);

    // 1) depth=1, parentId=null, name=l1Name
    final l1 = folders.firstWhere(
          (f) =>
      f.depth == 1 &&
          f.parentId == null &&
          _normName(f.name) == l1Norm,
      orElse: () => FolderNode(
        id: '',
        name: '',
        depth: 0,
        parentId: null,
        order: 0,
      ),
    );
    if (l1.id.isEmpty) {
      // 못 찾으면 경로 매칭 포기
      return const [];
    }

    String? l2Id;
    if (legacyL2.isNotEmpty) {
      final l2 = folders.firstWhere(
            (f) =>
        f.depth == 2 &&
            f.parentId == l1.id &&
            _normName(f.name) == l2Norm,
        orElse: () => FolderNode(
          id: '',
          name: '',
          depth: 0,
          parentId: null,
          order: 0,
        ),
      );
      if (l2.id.isNotEmpty) {
        l2Id = l2.id;
      }
    }

    String? l3Id;
    if (legacyL3.isNotEmpty && l2Id != null) {
      final l3 = folders.firstWhere(
            (f) =>
        f.depth == 3 &&
            f.parentId == l2Id &&
            _normName(f.name) == l3Norm,
        orElse: () => FolderNode(
          id: '',
          name: '',
          depth: 0,
          parentId: null,
          order: 0,
        ),
      );
      if (l3.id.isNotEmpty) {
        l3Id = l3.id;
      }
    }

    final path = <String>[l1.id];
    if (l2Id != null) path.add(l2Id);
    if (l3Id != null) path.add(l3Id);

    return path;
  }

  /// ------------------------------------------------------------------------
  /// ✅ 편의용: Settings 화면 등에서 간단히 호출할 수 있는 정적 실행기
  /// - Provider에서 필요한 Repo들을 안전하게 읽어와서 importer를 구성
  /// - 기본 에셋 경로를 제공 (필요 시 파라미터로 덮어쓰기)
  static Future<void> run(
      BuildContext context, {
        String itemsAssetPath = 'assets/seeds/2025-10-26/items.json',
        String foldersAssetPath = 'assets/seeds/2025-10-26/folders.json',
        String? bomAssetPath = 'assets/seeds/2025-10-26/bom.json',
        String? lotsAssetPath = 'assets/seeds/2025-10-26/lots.json',
        bool clearBefore = false,
        bool verbose = false,
      }) async {
    // 필수
    final itemRepo = context.read<ItemRepo>();

    // 선택(없어도 동작)
    BomRepo? bomRepo;
    try { bomRepo = context.read<BomRepo>(); } catch (_) {}

    DriftUnifiedRepo? drift;
    try { drift = context.read<DriftUnifiedRepo>(); } catch (_) {}

    final importer = UnifiedSeedImporter(
      itemRepo: itemRepo,
      bomRepo: bomRepo,
      drift: drift,
      verbose: verbose,
    );

    await importer.importUnifiedFromAssets(
      itemsAssetPath: itemsAssetPath,
      foldersAssetPath: foldersAssetPath,
      bomAssetPath: bomAssetPath,
      lotsAssetPath: lotsAssetPath,
      clearBefore: clearBefore,
    );
  }
/// ------------------------------------------------------------------------



}

