import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:collection' show SplayTreeSet;
import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/types.dart';
import '../models/work.dart';
import '../models/purchase.dart';

import 'repo_interfaces.dart';
import 'dart:async'; // ✅ StreamController 사용을 위해 필요

import '../models/folder_node.dart';
import '../utils/item_presentation.dart';

import '../models/lot.dart';


// === Common move types (top-level) ===
enum EntityKind { item, folder }

class MoveRequest {
  final EntityKind kind;
  final String id;            // itemId or folderId
  final List<String> pathIds; // [L1], [L1,L2], [L1,L2,L3]
  const MoveRequest({required this.kind, required this.id, required this.pathIds});
}

class InMemoryRepo extends ChangeNotifier
    implements ItemRepo, OrderRepo, TxnRepo, BomRepo, WorkRepo, PurchaseRepo, ItemPathProvider {
  final _uuid = const Uuid();
  final Map<String, Item> _items = {};
  final Map<String, Order> _orders = {};
  final Map<String, Txn> _txns = {};


  /// Finished 레시피 저장소: finishedId → rows
  final Map<String, List<BomRow>> _bomByFinished = {};

  /// Semi 레시피 저장소: semiId → rows
  final Map<String, List<BomRow>> _bomBySemi = {};
  // ── BOM rowId 규칙 유틸(고유 id 필드가 없다면 root|parent|component 조합 사용) ──
    String _bomRowId(BomRow r) => '${r.root.index}|${r.parentItemId}|${r.componentItemId}';
    bool _matchesRowId(BomRow r, String rowId) => _bomRowId(r) == rowId;
    bool _removeBomRowById(String rowId) {
        bool changed = false;
        for (final e in _bomByFinished.entries) {
          final before = e.value.length;
          e.value.removeWhere((r) => _matchesRowId(r, rowId));
          if (e.value.length != before) changed = true;
        }
        for (final e in _bomBySemi.entries) {
          final before = e.value.length;
          e.value.removeWhere((r) => _matchesRowId(r, rowId));
          if (e.value.length != before) changed = true;
        }
        return changed;
      }

  // ===== Folder tree storage (Stage 6) =====
  final Map<String, FolderNode> _folders = <String, FolderNode>{};

  /// parentId -> child folderIds (이름순 정렬)
  final Map<String?, SplayTreeSet<String>> _childrenIndex =
  <String?, SplayTreeSet<String>>{};

  /// itemId -> [l1Id,  l2Id?, l3Id?]
  final Map<String, List<String>> _itemPaths = <String, List<String>>{};

  InMemoryRepo(); // ← 비워둬도 OK

  void bootstrap() {
    notifyListeners();
  }

  /// (Undo 전용) 삭제했던 Txn을 그대로 복원
  void restoreTxnForUndo(Txn t) {
    _txns[t.id] = t;
    notifyListeners();
  }

  // ======================== 경로 유틸 (정규화/탐색) ========================
  // 이름 정규화: 대소문자/공백/하이픈/언더스코어 차이를 흡수
  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll('-', '_').replaceAll(RegExp(r'\s+'), '_');

  // 부모ID 범위 내에서만 자식 폴더를 이름으로 탐색
  String? _findChildFolderIdByName({
    required String? parentId, // null 이면 루트(depth=1 후보들)
    required String name,
  }) {
    if (name.trim().isEmpty) return null;
    final want = _norm(name);
    final kids = _childrenIndex[parentId];
    if (kids == null || kids.isEmpty) return null;

    for (final id in kids) {
      final f = _folders[id];
      if (f == null) continue;
      if (_norm(f.name) == want) return id;
    }
    return null;
  }

  // === 이름 → id 헬퍼 (정규화 버전) ===
  Future<String?> _folderIdByNameUnder(String name, String? parentId) async {
    // 정규화 비교 적용
    final kids = await listFolderChildren(parentId);
    final want = _norm(name);
    for (final k in kids) {
      if (_norm(k.name) == want) return k.id;
    }
    return null;
  }

  /// 이름들(l1/l2/l3)로 경로 id들을 찾거나(선택) 생성
  Future<List<String?>> pathIdsByNames({
    String? l1Name,
    String? l2Name,
    String? l3Name,
    bool createIfMissing = false,
  }) async {
    String? l1Id, l2Id, l3Id;

    if (l1Name != null && l1Name.trim().isNotEmpty) {
      l1Id = await _folderIdByNameUnder(l1Name, null);
      if (l1Id == null && createIfMissing) {
        l1Id = (await createFolderNode(parentId: null, name: l1Name)).id;
      }
    }
    if (l2Name != null && l2Name.trim().isNotEmpty && l1Id != null) {
      l2Id = await _folderIdByNameUnder(l2Name, l1Id);
      if (l2Id == null && createIfMissing) {
        l2Id = (await createFolderNode(parentId: l1Id, name: l2Name)).id;
      }
    }
    if (l3Name != null && l3Name.trim().isNotEmpty && l2Id != null) {
      l3Id = await _folderIdByNameUnder(l3Name, l2Id);
      if (l3Id == null && createIfMissing) {
        l3Id = (await createFolderNode(parentId: l2Id, name: l3Name)).id;
      }
    }
    return [l1Id, l2Id, l3Id];
  }

  // InMemoryRepo 내부
  Future<List<String>> itemPathNames(String itemId) async {
    final it = _items[itemId]; // 보유한 맵/스토리지에 맞춰 조회
    if (it == null) return const [];

    // 예시: 영→한 매핑 테이블(원하시면 앱 공용 utils로 이동)
    String folderKo(String? f) {
      switch (f) {
        case 'Finished': return '완제품';
        case 'Semi-finished': return '반제품';
        case 'Raw': return '원자재';
        case 'Sub': return '부자재';
        default: return f ?? '';
      }
    }

    return [
      folderKo(it.folder),
      it.subfolder ?? '',
      (it.subsubfolder ?? '').replaceAll('_', ' '), // 스네이크 → 공백
    ].where((e) => e.isNotEmpty).toList();
  }


  // ============================== 폴더 CRUD ===============================
  Future<List<FolderNode>> listFolderChildren(String? parentId) async {
    final set = _childrenIndex[parentId];
    if (set == null) return const [];
    return set.map((id) => _folders[id]!).toList(growable: false);
  }

  Future<FolderNode> createFolderNode({required String? parentId, required String name}) async {
    int depth = 1;
    if (parentId != null) {
      final p = _folders[parentId];
      if (p == null) throw StateError('Parent not found');
      depth = p.depth + 1;
      if (depth > 3) throw StateError('Depth > 3 is not supported');
    }
    final id = _uuid.v4();
    final node = FolderNode(id: id, name: name, parentId: parentId, depth: depth, order: 0);
    _folders[id] = node;

    final idx = _childrenIndex.putIfAbsent(parentId, () => SplayTreeSet(
          (a, b) => _folders[a]!.name.compareTo(_folders[b]!.name),
    ));
    idx.add(id);

    notifyListeners();
    return node;
  }

  Future<void> renameFolderNode({required String id, required String newName}) async {
    final cur = _folders[id];
    if (cur == null) throw StateError('Folder not found');
    _folders[id] = cur.copyWith(name: newName);

    // 형제 정렬 갱신
    final parentId = cur.parentId;
    final idx = _childrenIndex[parentId];
    if (idx != null) {
      idx.remove(id);
      idx.add(id);
    }
    notifyListeners();
  }
  Future<void> deleteFolderNode(String id) async {
    // 0) 자식/아이템 참조 검사 (기존 로직 유지)
    final children = _childrenIndex[id];
    if (children != null && children.isNotEmpty) {
      throw StateError('Folder has subfolders');
    }
    final isUsed = _itemPaths.values.any((Object? p) {
      if (p == null) return false;
      if (p is List) return p.contains(id);
      if (p is String) return p.split('/').contains(id);
      return false;
    });

    if (isUsed) {
      throw StateError('Folder is referenced by items');
    }

    // 1) 노드 존재 확인
    final node = _folders[id];
    if (node == null) {
      throw StateError('Folder not found: $id');
    }

    // 2) 부모의 children 인덱스에서 먼저 제거 (여기가 핵심!)
    final pid = node.parentId;
    if (pid != null) {
      _childrenIndex[pid]?.remove(id);
      // 필요하면 비어 있으면 버킷 제거
      if ((_childrenIndex[pid]?.isEmpty ?? false)) {
        _childrenIndex.remove(pid);
      }
    }

    // 3) 이 폴더 키인 버킷도 정리
    _childrenIndex.remove(id);

    // 4) 마지막에 _folders에서 제거
    _folders.remove(id);

    notifyListeners();
  }

  // ========================= 경로/검색 매칭 헬퍼 =========================
  int _wantedDepth(String? l1, String? l2, String? l3) {
    // l1/l2/l3 지정 개수 → 0..3
    if (l1 == null) return 0;
    if (l2 == null) return 1;
    if (l3 == null) return 2;
    return 3;
  }

  /// 경로 prefix 매칭 + 재귀 여부까지 단일 처리
  bool _pathMatches(
      String itemId, {
        String? l1,
        String? l2,
        String? l3,
        required bool recursive,
      }) {
    final path = _itemPaths[itemId];
    if (path == null) return false;

    // 1) prefix 체크
    if (l1 != null && (path.isEmpty || path[0] != l1)) return false;
    if (l2 != null && (path.length < 2 || path[1] != l2)) return false;
    if (l3 != null && (path.length < 3 || path[2] != l3)) return false;

    // 2) 재귀 여부
    if (!recursive) {
      // 비재귀는 "직속만": 경로 길이가 정확히 원하는 깊이와 동일해야 함
      return path.length == _wantedDepth(l1, l2, l3);
    }

    // 재귀면 prefix만 맞으면 OK
    return true;
  }

  // === 아이템 목록: 모든 단계 허용 ===
  @Deprecated('Use searchItemsByPath; pass keyword=null/empty and set recursive as needed')
  Future<List<Item>> listItemsByFolderPath({
    String? l1,
    String? l2,
    String? l3,
    String? keyword,
    bool recursive = false, // ← 기본 비재귀(직속만)
  }) async {
    // 코어로 위임: keyword가 null/empty면 "목록", 있으면 "검색"
    return _queryItemsByPath(
      l1: l1,
      l2: l2,
      l3: l3,
      keyword: keyword,
      recursive: recursive,
    );
  }

  // === 아이템 생성: 경로 일부만 있어도 가능 ===
  Future<void> createItemUnderPath({
    required List<String> pathIds, // [l1Id], [l1Id,l2Id], [l1Id,l2Id,l3Id]
    required Item item,
  }) async {
    if (pathIds.isEmpty || pathIds.length > 3) {
      throw ArgumentError('pathIds must have length 1..3');
    }
    // ✅ 깊이 검증: 3단계까지만 허용, 중간체인만 확인
    for (int i = 0; i < pathIds.length; i++) {
      final n = _folders[pathIds[i]];
      if (n == null) throw StateError('Folder not found: ${pathIds[i]}');
      if (n.depth != (i + 1)) throw StateError('Folder depth mismatch at index $i');
      if (i > 0) {
        final parent = _folders[pathIds[i - 1]];
        if (n.parentId != parent!.id) throw StateError('Folder parent chain invalid');
      }
    }

    _items[item.id] = item;
    _itemPaths[item.id] = List.unmodifiable(pathIds);
    notifyListeners();
  }

  FolderNode? folderById(String id) => _folders[id];

  /// itemId -> [l1Id, l2Id?, l3Id?] (없으면 null)
  List<String>? itemPathIds(String itemId) => _itemPaths[itemId];



  // ──────────── 아이템 편집/이동/삭제 ────────────
  Future<void> renameItem({required String id, required String newName}) async {
    final it = _items[id];
    if (it == null) throw StateError('Item not found: $id');
    final updated = it.copyWith(name: newName);
    _items[id] = updated;
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    if (!_items.containsKey(id)) throw StateError('Item not found: $id');
    _items.remove(id);
    _itemPaths.remove(id);
    notifyListeners();
  }

  // ──────────── Move helpers ────────────
  void _validatePathIds(List<String> pathIds) {
    if (pathIds.isEmpty || pathIds.length > 3) {
      throw ArgumentError('pathIds must have length 1..3');
    }
    for (int i = 0; i < pathIds.length; i++) {
      final n = _folders[pathIds[i]];
      if (n == null) throw StateError('Folder not found: ${pathIds[i]}');
      if (n.depth != (i + 1)) {
        throw StateError('Folder depth mismatch at index $i (got ${n.depth}, want ${i + 1})');
      }
      if (i > 0) {
        final parent = _folders[pathIds[i - 1]];
        if (n.parentId != parent!.id) {
          throw StateError('Folder parent chain invalid at index $i');
        }
      }
    }
  }

  bool _isDescendantFolder(String ancestorId, String targetId) {
    // targetId 의 부모를 타고 올라가다 ancestorId가 나오면 true
    var cur = _folders[targetId];
    while (cur != null && cur.parentId != null) {
      if (cur.parentId == ancestorId) return true;
      cur = _folders[cur.parentId!];
    }
    return false;
  }

  // ──────────── Unified move API ────────────
  Future<void> moveEntityToPath(MoveRequest req) async {
    _validatePathIds(req.pathIds);

    switch (req.kind) {
      case EntityKind.item:
        if (!_items.containsKey(req.id)) {
          throw StateError('Item not found: ${req.id}');
        }
        _itemPaths[req.id] = List.unmodifiable(req.pathIds);
        break;

      case EntityKind.folder:
        {
          // 1) 대상/새 부모 조회 + 가드
          final folder = _folders[req.id];
          if (folder == null) {
            throw StateError('Folder not found: ${req.id}');
          }

          final String newParentId = req.pathIds.last;
          final newParent = _folders[newParentId];
          if (newParent == null) {
            throw StateError('Parent folder not found: $newParentId');
          }
          if (newParent.depth >= 3) {
            throw StateError('Cannot move folder under depth 3 node');
          }
          if (req.id == newParent.id || _isDescendantFolder(req.id, newParent.id)) {
            throw StateError('Cannot move folder inside its own subtree');
          }

          final oldParentId = folder.parentId;
          if (oldParentId == newParent.id) {
            // 같은 부모로 이동이면 변경 없음
            break;
          }

          // 2) children index에서 부모 관계 갱신
          _childrenIndex[oldParentId]?.remove(folder.id);
          final newIdx = _childrenIndex.putIfAbsent(
            newParent.id,
                () => SplayTreeSet<String>(
                  (a, b) => _folders[a]!.name.compareTo(_folders[b]!.name),
            ),
          );
          newIdx.add(folder.id);

          // 3) depth delta 계산 (서브트리 전체 depth 보정)
          final newDepth = newParent.depth + 1;
          final delta = newDepth - folder.depth;

          // 이동 대상 포함 서브트리 depth 업데이트
          void _bumpDepthsRecursively(String fid) {
            final f = _folders[fid];
            if (f == null) return;
            _folders[fid] = f.copyWith(depth: f.depth + delta);
            final kids = _childrenIndex[fid];
            if (kids == null) return;
            for (final childId in kids) {
              _bumpDepthsRecursively(childId);
            }
          }

          // 4) 루트 노드의 parentId와 depth부터 갱신 후 서브트리 보정
          _folders[folder.id] = folder.copyWith(
            parentId: newParent.id,
            depth: newDepth,
          );
          // 자식들 depth 일괄 보정
          final children = _childrenIndex[folder.id];
          if (children != null && children.isNotEmpty) {
            for (final childId in children) {
              _bumpDepthsRecursively(childId);
            }
          }
          break;
        }
    }


    notifyListeners();
  }

  // (하위호환) 아이템 전용 이동 → 통합 API 위임
  Future<void> moveItemToPath({
    required String itemId,
    required List<String> pathIds, // [L1], [L1,L2], [L1,L2,L3] 허용
  }) async {
    await moveEntityToPath(
      MoveRequest(kind: EntityKind.item, id: itemId, pathIds: pathIds),
    );
  }
  // itemId -> FIFO 리스트
  final Map<String, List<Lot>> _lotsByItem = {};

// FIFO 조회 (receivedAt asc)
  List<Lot> lotsByItem(String itemId) {
    final list = _lotsByItem[itemId] ?? const [];
    final sorted = [...list]..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return sorted;
  }

// 일괄 upsert (같은 lotNo 있으면 교체, 없으면 추가)
  void upsertLots(String itemId, List<Lot> lots) {
    final map = {for (final l in lotsByItem(itemId)) l.lotNo: l};
    for (final l in lots) {
      map[l.lotNo] = l;
    }
    _lotsByItem[itemId] = map.values.toList()
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    notifyListeners();
  }

// 간단 입고 헬퍼
  void receiveLots(String itemId, List<Map<String, dynamic>> inputs) {
    final newLots = inputs.map((m) => Lot(
      itemId: itemId,
      lotNo: m['lot_no'] as String,
      receivedQtyRoll: (m['received_qty_roll'] ?? 1).toDouble(),
      measuredLengthM: (m['measured_length_m'] ?? m['length_m'] ?? 0).toDouble(),
      usableQtyM: (m['usable_qty_m'] ?? m['measured_length_m'] ?? 0).toDouble(),
      status: (m['status'] as String?) ?? 'active',
      receivedAt: DateTime.tryParse(m['received_at'] ?? '') ?? DateTime.now(),
    )).toList();
    upsertLots(itemId, newLots);
  }

// FIFO 차감: outQtyM만큼 앞에서부터 차감, 변경된 Lot 리스트 반환
  List<Lot> consumeLotsFifo(String itemId, double outQtyM) {
    double remain = outQtyM;
    final lots = lotsByItem(itemId);
    final changed = <Lot>[];

    for (final l in lots) {
      if (remain <= 0) break;
      if (l.usableQtyM <= 0) continue;

      final take = remain <= l.usableQtyM ? remain : l.usableQtyM;
      l.usableQtyM -= take;
      remain -= take;
      changed.add(l);
    }

    // 저장
    _lotsByItem[itemId] = lots;
    notifyListeners();

    if (remain > 0) {
      // 필요 시 경고/예외 처리: 잔량 부족
      // throw StateError('Not enough lot qty for $itemId: short ${remain}m');
    }
    return changed;
  }


  // === 폴더+아이템 동시 검색 ===
  Future<(List<FolderNode>, List<Item>)> searchAll({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  }) async {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return (<FolderNode>[], <Item>[]);

    // 🔍 1) 폴더 검색
    final folders = _folders.values.where((f) {
      bool matchesDepth() {
        if (l1 == null) return true;
        // 현재 기준 폴더의 경로가 포함되는지 판단
        if (l1 != null && f.depth == 1 && f.id != l1) return false;
        if (l2 != null && f.depth == 2 && f.parentId != l1) return false;
        if (l3 != null && f.depth == 3 && f.parentId != l2) return false;
        return true;
      }

      return matchesDepth() && f.name.toLowerCase().contains(k);
    }).toList();

    // 🔍 2) 아이템 검색 (기존 로직 활용)
    final items = await searchItemsByPath(l1: l1, l2: l2, l3: l3, keyword: keyword, recursive: recursive);

    return (folders, items);
  }

  // === 내부 코어: 경로 + (옵션)키워드로 아이템 조회 ===
  Future<List<Item>> _queryItemsByPath({
    String? l1,
    String? l2,
    String? l3,
    String? keyword,
    bool recursive = true,
  }) async {
    // 1) 경로(prefix) 매칭
    Iterable<MapEntry<String, Item>> it = _items.entries.where(
          (e) => _pathMatches(e.key, l1: l1, l2: l2, l3: l3, recursive: recursive),
    );

    // 2) 키워드(이름/sku/폴더명) 매칭
    final k = (keyword ?? '').trim();
    if (k.isNotEmpty) {
      it = it.where((e) {
        final item = e.value;
        final names = _itemPaths[e.key]?.map((fid) => _folders[fid]?.name ?? '').toList() ?? const <String>[];
        return matchesItemOrPath(item: item, pathNames: names, keyword: k);
      });
    }

    // 3) ✅ 항상 반환
    return it.map((e) => e.value).toList(growable: false);
  }

  @override
  Future<List<Item>> searchItemsGlobal(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    // 전역 검색: 경로 제한 없음 → 코어로 위임
    return _queryItemsByPath(keyword: keyword, recursive: true);
  }

  @override
  Future<List<Item>> searchItemsByPath({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  }) {
    if (keyword.trim().isEmpty) return Future.value(const []);
    return _queryItemsByPath(
      l1: l1,
      l2: l2,
      l3: l3,
      keyword: keyword,
      recursive: recursive,
    );
  }

  // =============================== ItemRepo ===============================
  @override
  @Deprecated('Use searchItemsByPath / listItemsByFolderPath (path-based).')
  Future<List<Item>> listItems({String? folder, String? keyword}) async {
    // 레거시 호환: folder가 오면 L1 이름으로 간주하여 경로 기반으로 변환
    if (folder != null) {
      final mapped = _mapLegacyL1Name(folder); // Finished/Raw 등으로 매핑
      final ids = await pathIdsByNames(l1Name: mapped, createIfMissing: true);
      return _queryItemsByPath(
        l1: ids[0],
        keyword: keyword,
        recursive: true,
      );
    }
    // folder가 없으면 전체 검색
    return _queryItemsByPath(keyword: keyword, recursive: true);
  }

  @override
  Future<Item?> getItem(String id) async => _items[id];

  // 동기 캐시 접근용 (UI용)
  Item? getItemById(String id) => _items[id];


  @override
  Future<void> upsertItem(Item item) async {
    _items[item.id] = item;
    notifyListeners();
  }

  @override
  Future<void> adjustQty({
    required String itemId,
    required int delta,
    String? refType, // ← 인터페이스에 맞춰 String
    String? refId,   // ← 인터페이스에 맞춰 String
    String? note,
  }) async {
    final it = _items[itemId];
    if (it == null) return;

    final updated = it.copyWith(qty: it.qty + delta);
    _items[itemId] = updated;

    final txn = Txn(
      id: _uuid.v4(),
      ts: DateTime.now(),
      type: delta >= 0 ? TxnType.in_ : TxnType.out_,
      status: TxnStatus.actual,
      itemId: itemId,
      qty: delta.abs(),
      refType: RefTypeX.fromString(refType ?? 'order'),
      refId: refId ?? 'unknown',
      note: note,
    );
    _txns[txn.id] = txn;
    notifyListeners();
  }
  @override
  Future<void> updateUnits({
    required String itemId,
    String? unitIn,
    String? unitOut,
    double? conversionRate,
  }) async {
    final it = _items[itemId];
    if (it == null) return;

    print('[updateUnits] $itemId, unitIn=$unitIn, unitOut=$unitOut, conv=$conversionRate');

    final updated = it.copyWith(
      unitIn: unitIn ?? it.unitIn,
      unitOut: unitOut ?? it.unitOut,
      conversionRate: conversionRate ?? it.conversionRate,
    );

    _items[itemId] = updated;
    notifyListeners();
  }

  @override
  Future<String?> nameOf(String itemId) async {
    return _items[itemId]?.name; // 없으면 null
  }
// ===== Item partial update (meta) =====
  void updateItemMeta({
    required String id,

    // 표시/분류
    String? displayName,
    int? minQty,
    String? unit,
    String? folder,
    String? subfolder,
    String? subsubfolder,
    String? kind,
    Map<String, dynamic>? attrs,

    // 환산(롤/하이브리드)
    String? unitIn,
    String? unitOut,
    double? conversionRate,
    String? conversionMode,

    // 레거시 폴백 메타
    StockHints? stockHints,

    // attrs 병합 동작 제어
    bool mergeAttrs = true,
  }) {
    final old = _items[id];
    if (old == null) return;

    // attrs는 기본 병합: 새 값이 있으면 덮어쓰고, 없는 키는 유지
    final mergedAttrs = (mergeAttrs && attrs != null && old.attrs != null)
        ? {...old.attrs!, ...attrs}
        : (attrs ?? old.attrs);

    final updated = old.copyWith(
      displayName: displayName ?? old.displayName,
      minQty: minQty ?? old.minQty,
      unit: unit ?? old.unit,
      folder: folder ?? old.folder,
      subfolder: subfolder ?? old.subfolder,
      subsubfolder: subsubfolder ?? old.subsubfolder,
      kind: kind ?? old.kind,
      attrs: mergedAttrs,

      unitIn: unitIn ?? old.unitIn,
      unitOut: unitOut ?? old.unitOut,
      conversionRate: conversionRate ?? old.conversionRate,
      conversionMode: conversionMode ?? old.conversionMode,

      stockHints: stockHints ?? old.stockHints,
    );

    _items[id] = updated;
    notifyListeners();
  }

  // ============================== OrderRepo ===============================
  @override
  Future<List<Order>> listOrders() async {
    final list = _orders.values.where((o) => o.isDeleted != true).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<Order?> getOrder(String id) async => _orders[id];

  @override
  Future<void> upsertOrder(Order order) async {
    _orders[order.id] = order;
    notifyListeners();
  }

  @override
  Future<String?> customerNameOf(String orderId) async {
    final o = _orders[orderId];
    return o?.customer; // ✅ Order 클래스에 있는 필드명과 일치
  }

  @override
  Future<void> softDeleteOrder(String orderId) async {
    final o = _orders[orderId];
    if (o == null) return;
    _orders[orderId] = o.copyWith(isDeleted: true, updatedAt: DateTime.now());
    notifyListeners();
  }

  @override
  Future<void> hardDeleteOrder(String orderId) async {
    // 주문과 연결된 작업/예약txn 정리
    final workIds = _works.values.where((w) => w.orderId == orderId).map((w) => w.id).toList();
    for (final wid in workIds) {
      await hardDeleteWork(wid);
    }
    _orders.remove(orderId);
    notifyListeners();
  }

//===== items, folders 내보내기  ========

  /// ✅ 현재 메모리에 있는 모든 아이템 반환
  List<Item> allItems() => _items.values.toList();

  /// (선택) 폴더도 필요하면 이렇게
  List<FolderNode> allFolders() => _folders.values.toList();

  // =============================== TxnRepo ================================
  @override
  Future<List<Txn>> listTxns() async {
      final list = _txns.values.toList()
  ..sort((a, b) => b.ts.compareTo(a.ts));
    return list;
  }
  // 내부 편의: 특정 아이템만 보고 싶을 때
    Future<List<Txn>> listTxnsByItem(String itemId) async {
      final list = _txns.values.where((t) => t.itemId == itemId).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
      return list;
    }
  // ===== TxnRepo helpers =====
  @override
  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    final txn = Txn(
      id: _uuid.v4(),
      ts: DateTime.now(),
      type: TxnType.in_,
      status: TxnStatus.planned,
      itemId: itemId,
      qty: qty,
      refType: RefTypeX.fromString(refType),
      refId: refId,
      note: note ?? 'planned inbound',
    );
    _txns[txn.id] = txn;
    notifyListeners();
  }

  @override
  Future<void> addInActual({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  }) async {
    final txn = Txn(
      id: _uuid.v4(),
      ts: DateTime.now(),
      type: TxnType.in_,
      status: TxnStatus.actual,
      itemId: itemId,
      qty: qty,
      refType: RefTypeX.fromString(refType),
      refId: refId,
      note: note ?? 'actual inbound',
    );
    _txns[txn.id] = txn; // ✅ Map 저장

    final it = _items[itemId];
    if (it != null) {
      _items[itemId] = it.copyWith(qty: it.qty + qty); // ✅
    }
    notifyListeners();
  }

  @override
  Future<void> deleteTxn(String txnId) async {
    _txns.remove(txnId);
    notifyListeners();
  }

  @override
  Future<void> deletePlannedByRef({required String refType, required String refId}) async {
    final toRemove = _txns.values
        .where((t) => t.refType == refType && t.refId == refId && t.isPlanned == true)
        .map((t) => t.id)
        .toList();
    for (final id in toRemove) {
      _txns.remove(id);
    }
    if (toRemove.isNotEmpty) notifyListeners();
  }

  // ===================== HELPERS =====================
  Future<void> _removePlannedTxnsByRef({required String refType, required String refId}) async {
    final ids = _txns.values
        .where((t) => t.refType == refType && t.refId == refId && t.isPlanned == true)
        .map((t) => t.id)
        .toList();
    for (final id in ids) {
      _txns.remove(id);
    }
  }

  // ── stockHints 기반 폴백 헬퍼들 ────────────────────────────

// Seed 힌트: 출고단위 기준 수량 (예: Roll이 아닌, item.unit/혹은 unit_out 기준)
  double hintQtyOut(String itemId) {
    final it = _items[itemId];
    if (it == null) return 0;
    final q = it.stockHints?.qty;
    return q == null ? 0 : q.toDouble();
  }

// Seed 힌트: 사용가능 미터 (usable_qty_m가 있으면 우선, 없으면 qty*conversion_rate)
  double hintUsableMeters(String itemId) {
    final it = _items[itemId];
    if (it == null) return 0;
    final u = it.stockHints?.usableQtyM;
    if (u != null) return u.toDouble();
    final q = it.stockHints?.qty;
    final r = it.stockHints?.conversionRate;
    if (q != null && r != null) return q.toDouble() * r.toDouble();
    return 0;
  }

// Seed 힌트: 출고단위 표시용 (없으면 Item.unit)
  String hintUnitOut(String itemId) {
    final it = _items[itemId];
    if (it == null) return '';
    return (it.stockHints?.unitOut ?? it.unit).toString();
  }


  // =============================== BomRepo ================================
  // ─────────────────────────────────────────────
  // ItemRepo: BOM APIs (2단계 구조) 구현
  // ─────────────────────────────────────────────
// InMemoryRepo 클래스 안쪽에 추가

// ─────────────────────────────────────────────
// BomRepo 기본 구현 (최소한의 더미 or 새 구조와 연결)
// ─────────────────────────────────────────────
  // ─────────────────────────────────────────────
  // BomRepo (표준 시그니처) 구현
  // ─────────────────────────────────────────────
    @override
    Future<List<BomRow>> listBom(String parentItemId) async {
      // root 파라미터가 없으므로 finished/semi 양쪽을 합쳐 반환
      final finished = finishedBomOf(parentItemId);
      final semi = semiBomOf(parentItemId);
      return List<BomRow>.unmodifiable([...finished, ...semi]);
    }

    @override
    Future<void> upsertBomRow(BomRow row) async {
      if (row.root == BomRoot.finished) {
        final cur = finishedBomOf(row.parentItemId);
      // 🔧 교체 기준을 (componentItemId, kind)로 강화
            final next = [
              ...cur.where((r) =>
                  !(r.componentItemId == row.componentItemId && r.kind == row.kind)),
              row,
            ];
        upsertFinishedBom(row.parentItemId, next);
      } else {
        final cur = semiBomOf(row.parentItemId);
        final next = [
              ...cur.where((r) =>
                  !(r.componentItemId == row.componentItemId && r.kind == row.kind)),
              row,
            ];
        upsertSemiBom(row.parentItemId, next);
      }
    }

    @override
    Future<void> deleteBomRow(String id) async {
      final changed = _removeBomRowById(id);
      if (changed) notifyListeners();
    }
  // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    // (내부/리치 API) finished/semi 전용 메서드들 — @override 제거
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑
    // 루트별 조회/업서트/삭제를 계속 쓰고 싶으면 화면/서비스에서 이 메서드들을 직접 호출
    List<BomRow> listBomByRoot({
      required BomRoot root,
      required String parentItemId,
    }) {
    return root == BomRoot.finished
        ? finishedBomOf(parentItemId)
        : semiBomOf(parentItemId);
  }

  void deleteBomRowDetailed({
    required BomRoot root,
    required String parentItemId,
    required String componentItemId,
  }) {
    final list = listBomByRoot(root: root, parentItemId: parentItemId);
    final next = list.where((r) => r.componentItemId != componentItemId).toList();
    if (root == BomRoot.finished) {
      upsertFinishedBom(parentItemId, next);
    } else {
      upsertSemiBom(parentItemId, next);
    }
  }

  List<BomRow> finishedBomOf(String finishedItemId) {
    final rows = _bomByFinished[finishedItemId];
    if (rows == null) return const [];
    return List.unmodifiable(rows);
  }

  // ✅ 부모별 BOM을 한 번에 교체(배치) — 시드용으로 안정적
    Future<void> replaceBomRows({
      required BomRoot root,
      required String parentItemId,
      required List<BomRow> rows,
    }) async {
    if (root == BomRoot.finished) {
      await upsertFinishedBom(parentItemId, rows);
    } else {
      await upsertSemiBom(parentItemId, rows);
    }
  }

  @override
   Future<void>upsertFinishedBom(String finishedItemId, List<BomRow> rows) async{
    // 방어: root/parent/kind 정합성
    final normalized = <BomRow>[];
    for (final r in rows) {
      if (r.root != BomRoot.finished) {
        throw StateError('Finished BOM에는 root=finished만 허용됩니다. (got: ${r.root})');
      }
      final fixed = (r.parentItemId == finishedItemId)
          ? r
          : r.copyWith(parentItemId: finishedItemId);
      // finished 레시피는 semi/raw/sub 모두 허용
      normalized.add(fixed);
    }
    _bomByFinished[finishedItemId] = normalized;
    notifyListeners();
    return;
  }

  List<BomRow> semiBomOf(String semiItemId) {
    final rows = _bomBySemi[semiItemId];
    if (rows == null) return const [];
    return List.unmodifiable(rows);
  }
  @override
  Future<void> upsertSemiBom(String semiItemId, List<BomRow> rows) async{
    // 방어: root=semi, kind!=semi
    final normalized = <BomRow>[];
    for (final r in rows) {
      if (r.root != BomRoot.semi) {
        throw StateError('Semi BOM에는 root=semi만 허용됩니다. (got: ${r.root})');
      }
      if (r.kind == BomKind.semi) {
        throw StateError('Semi BOM에는 kind=semi 금지입니다.');
      }
      final fixed = (r.parentItemId == semiItemId)
          ? r
          : r.copyWith(parentItemId: semiItemId);
      normalized.add(fixed);
    }
    _bomBySemi[semiItemId] = normalized;
    notifyListeners();
    return;
  }

  @override
  int stockOf(String itemId) {
    final item = _items[itemId];
    if (item == null) return 0;
    return item.qty; // ← Item 모델에 qty 필드가 있을 것
  }


  // ----------------- WorkRepo -----------------
  final _works = <String, Work>{};

  @override
  Future<String> createWork(Work w) async {
    final now = DateTime.now();
    final id = (w.id.isNotEmpty) ? w.id : _uuid.v4();
    final saved = w.copyWith(
      id: id,
      status: w.status,
      createdAt: w.createdAt ?? now,
      updatedAt: now,
    );
    _works[id] = saved;
    // print('[InMemoryRepo] createWork -> ${saved.id} ${saved.status}');

    notifyListeners();
    return id;
  }

  @override
  Future<Work?> getWorkById(String id) async => _works[id];

  @override
  Stream<List<Work>> watchAllWorks() {
    // ChangeNotifier -> Stream 브리지
    final c = StreamController<List<Work>>.broadcast();
    void emit() => c.add(_works.values.where((w) => w.isDeleted != true).toList());
    c.onListen = emit; // 최초 1회
    final listener = () => emit(); // 변경 시마다 emit
    addListener(listener);
    c.onCancel = () => removeListener(listener);
    return c.stream;
  }

  @override
  Future<void> updateWork(Work w) async {
    _works[w.id] = w;
    notifyListeners();
  }

  @override
  Future<void> updateWorkStatus(String id, WorkStatus status) async {
    final w = _works[id];
    if (w == null) return;
    _works[id] = w.copyWith(status: status, updatedAt: DateTime.now());
    notifyListeners();
  }

  @override
  Future<void> cancelWork(String id) async {
    await updateWorkStatus(id, WorkStatus.canceled);
  }

  // ===== WorkRepo.completeWork =====
  @override
  Future<void> completeWork(String id) async {
    final w = _works[id];
    if (w == null) return;
    if (w.status == WorkStatus.done) return;

    // 상태 업데이트
    _works[id] = w.copyWith(
      status: WorkStatus.done,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // ==== delete work ==== //
  @override
  Future<void> softDeleteWork(String workId) async {
    final w = _works[workId];
    if (w == null) return;
    // 진행/완료면 canceled 권장, planned면 삭제 플래그
    if (w.status == WorkStatus.inProgress || w.status == WorkStatus.done) {
      _works[workId] = w.copyWith(status: WorkStatus.canceled, updatedAt: DateTime.now());
    } else {
      _works[workId] = w.copyWith(isDeleted: true, updatedAt: DateTime.now());
    }
    await _removePlannedTxnsByRef(refType: 'work', refId: workId);
    notifyListeners();
  }

  @override
  Future<void> hardDeleteWork(String workId) async {
    await _removePlannedTxnsByRef(refType: 'work', refId: workId);
    _works.remove(workId);
    notifyListeners();
  }

  // ----------------- PurchaseRepo -----------------
  final _purchases = <String, Purchase>{};

  @override
  Future<String> createPurchase(Purchase p) async {
    _purchases[p.id] = p;
    notifyListeners();
    return p.id;
  }

  @override
  Future<Purchase?> getPurchaseById(String id) async => _purchases[id];

  @override
  Stream<List<Purchase>> watchAllPurchases() {
    final c = StreamController<List<Purchase>>.broadcast();
    void emit() => c.add(_purchases.values.where((p) => p.isDeleted != true).toList());
    c.onListen = emit;
    final listener = () => emit();
    addListener(listener);
    c.onCancel = () => removeListener(listener);
    return c.stream;
  }

  @override
  Future<void> updatePurchase(Purchase p) async {
    _purchases[p.id] = p;
    notifyListeners();
  }

  @override
  Future<void> updatePurchaseStatus(String id, PurchaseStatus status) async {
    final p = _purchases[id];
    if (p == null) return;
    _purchases[id] = p.copyWith(status: status, updatedAt: DateTime.now());
    notifyListeners();
  }

  @override
  Future<void> cancelPurchase(String id) async {
    await updatePurchaseStatus(id, PurchaseStatus.canceled);
  }

  // ===== PurchaseRepo.completePurchase =====
  @override
  Future<void> completePurchase(String id) async {
    final p = _purchases[id];
    if (p == null) return;
    if (p.status == PurchaseStatus.received) return;

    // 상태 업데이트
    _purchases[id] = p.copyWith(status: PurchaseStatus.received, updatedAt: DateTime.now());
    notifyListeners();
  }

  @override
  Future<void> softDeletePurchase(String purchaseId) async {
    final p = _purchases[purchaseId];
    if (p == null) return;
    _purchases[purchaseId] = p.copyWith(isDeleted: true, updatedAt: DateTime.now());
    notifyListeners();
  }

  @override
  Future<void> hardDeletePurchase(String purchaseId) async {
    _purchases.remove(purchaseId);
    notifyListeners();
  }

  // (하위호환) 폴더 전용 이동 → 통합 API 위임
  @Deprecated('Use moveEntityToPath instead.')
  Future<void> moveFolderToPath({
    required String folderId,
    required List<String> pathIds, // [L1], [L1,L2], [L1,L2,L3]
  }) async {
    await moveEntityToPath(
      MoveRequest(kind: EntityKind.folder, id: folderId, pathIds: pathIds),
    );
  }

  // =============================== 시드 주입 ===============================

  // === For seed loader access ===
  Uuid get uuid => _uuid;
  Map<String, FolderNode> get folders => _folders;
  Map<String?, SplayTreeSet<String>> get childrenIndex => _childrenIndex;
  int get folderCount => _folders.length;

  Future<void> importSeed({
    List<FolderNode>? folders,
    List<Item>? items,
  }) async {
    if (folders != null) {
      for (final f in folders) {
        _folders[f.id] = f;
        _childrenIndex
            .putIfAbsent(
          f.parentId,
              () => SplayTreeSet((a, b) => _folders[a]!.name.compareTo(_folders[b]!.name)),
        )
            .add(f.id);
      }
    }
    if (items != null) {
      for (final i in items) {
        _items[i.id] = i;
      }
    }

    // ✅ 아이템의 레거시 필드(folder/subfolder[/subsubfolder])로 경로 백필
    await backfillPathsFromLegacy(createFolders: false);

    notifyListeners();
  }

  // ===================== 레거시 경로 백필 (L1→L2→L3) =====================
  /// 레거시 Item.folder/subfolder(/subsubfolder) 를 트리 경로(_itemPaths)로 백필.
  /// 이미 경로가 있으면 건너뜀. 없는 것만 채움.
  Future<void> backfillPathsFromLegacy({bool createFolders = true}) async {
    for (final e in _items.entries) {
      final item = e.value;
      if (_itemPaths.containsKey(item.id)) continue; // 이미 배치된 아이템 스킵

      // 레거시 필드가 전혀 없으면 스킵
      final legacyL1 = (item.folder).trim();
      final legacyL2Raw = (item.subfolder ?? '').trim();
      final legacyL3Raw = (item is dynamic && (item as dynamic).subsubfolder != null)
          ? ((item as dynamic).subsubfolder as String).trim()
          : '';
      if (legacyL1.isEmpty && legacyL2Raw.isEmpty && legacyL3Raw.isEmpty) continue;

      // L1 이름 매핑 (finished/FINISHED 등 → 'Finished')
      final l1Name = _mapLegacyL1Name(legacyL1);

      // L2/L3 분해 로직: subsubfolder가 있으면 우선 사용, 없으면 subfolder에서 분해("a/b")
      String l2Name = legacyL2Raw;
      String l3Name = legacyL3Raw;
      if (l3Name.isEmpty && l2Name.contains('/')) {
        final parts = l2Name.split(RegExp(r'\s*[/|>\u203A]\s*'));
        l2Name = parts.isNotEmpty ? parts[0] : '';
        l3Name = parts.length > 1 ? parts[1] : '';
      }

      // ID 탐색/생성
      final ids = await pathIdsByNames(
        l1Name: l1Name,
        l2Name: l2Name.isEmpty ? null : l2Name,
        l3Name: l3Name.isEmpty ? null : l3Name,
        createIfMissing: createFolders,
      );
      final path = ids.whereType<String>().toList();
      if (path.isNotEmpty) {
        _itemPaths[item.id] = List.unmodifiable(path);
      }
    }
    notifyListeners();
  }

  /// 레거시 L1 이름 → 트리 L1 이름 매핑
  String _mapLegacyL1Name(String legacy) {
    final v = legacy.trim().toLowerCase();
    switch (v) {
      case 'finished':
        return 'Finished';
      case 'semifinished':
      case 'semi_finished':
      case 'semi-finished':
        return 'SemiFinished';
      case 'raw':
        return 'Raw';
      case 'sub':
        return 'Sub';
      default: // 모르는 값은 TitleCase 정도로
        if (v.isEmpty) return 'Finished';
        return v[0].toUpperCase() +  v.substring(1);
    }
  }
}
