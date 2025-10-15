
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

class InMemoryRepo extends ChangeNotifier
    implements ItemRepo, OrderRepo, TxnRepo, BomRepo, WorkRepo, PurchaseRepo {
  final _uuid = const Uuid();
  final Map<String, Item> _items = {};
  final Map<String, Order> _orders = {};
  final Map<String, Txn> _txns = {};
  final Map<String, BomRow> _bom = {};

  InMemoryRepo() {
    _seedFolderRootsIfEmpty();   // ← 추가
  }

  InMemoryRepo.seeded() {
    _seedFolderRootsIfEmpty();   // ← 추가 (시드 아이템 전에 호출해도 OK)
    final i1 = Item(
      id: _uuid.v4(),
      name: '루앙 그레이 50 기본형 방석커버',
      sku: 'LG-50C',
      unit: 'EA',
      folder: 'finished',
      subfolder: 'cushion',
      minQty: 5,
      qty: 12,
    );

    final i2 = Item(
      id: _uuid.v4(),
      name: '루앙 그레이 40 쿠션커버',
      sku: 'LG-40C',
      unit: 'EA',
      folder: 'finished',
      subfolder: 'cushion',
      minQty: 5,
      qty: 4,
    );

    final fabric = Item(
      id: _uuid.v4(),
      name: '원단-루앙 그레이',
      sku: 'FAB-LG',
      unit: 'M',
      folder: 'raw',         // 예: 원자재 카테고리
      subfolder: 'fabric',
      minQty: 10,
      qty: 27,
    );

    _items[i1.id] = i1;
    _items[i2.id] = i2;
    _items[fabric.id] = fabric;

    // 시드 아이템 저장 후 ( _items[...] = ... ) 아래에 추가
    () async {
      // finished > cushion
      final finishedPath = await pathIdsByNames(
        l1Name: 'Finished',
        l2Name: 'cushion',
        createIfMissing: true,
      );
      final rawPath = await pathIdsByNames(
        l1Name: 'Raw',
        l2Name: 'fabric',
        createIfMissing: true,
      );

      _itemPaths[i1.id] = List.unmodifiable([finishedPath[0]!, finishedPath[1]!]);
      _itemPaths[i2.id] = List.unmodifiable([finishedPath[0]!, finishedPath[1]!]);
      _itemPaths[fabric.id] = List.unmodifiable([rawPath[0]!, rawPath[1]!]);
    }();

  }

  void bootstrap() {
    notifyListeners();
  }
  // ===== Folder tree storage (Stage 6) =====
  final Map<String, FolderNode> _folders = <String, FolderNode>{};

  /// parentId -> child folderIds (이름순 정렬)
  final Map<String?, SplayTreeSet<String>> _childrenIndex =
  <String?, SplayTreeSet<String>>{};

  /// itemId -> [l1Id, l2Id?, l3Id?]
  final Map<String, List<String>> _itemPaths = <String, List<String>>{};

  final _uuidStage6 = const Uuid(); // 기존 _uuid와 충돌 피하기 위한 별도 uuid

  void _seedFolderRootsIfEmpty() {
    if (_folders.isNotEmpty) return;
    for (final name in const ['Finished', 'SemiFinished', 'Raw', 'Sub']) {
      final id = _uuidStage6.v4();
      final node = FolderNode(
        id: id,
        name: name,
        depth: 1,
        parentId: null,
        order: 0,
      );
      _folders[id] = node;
      _childrenIndex.putIfAbsent(null, () => SplayTreeSet(
            (a, b) => _folders[a]!.name.compareTo(_folders[b]!.name),
      )).add(id);
    }
  }

  // === 이름 → id 헬퍼 ===
  Future<String?> _folderIdByNameUnder(String name, String? parentId) async {
    final kids = await listFolderChildren(parentId);
    for (final k in kids) {
      if (k.name == name) return k.id;
    }
    return null;
  }

  Future<List<String?>> pathIdsByNames({
    String? l1Name,
    String? l2Name,
    String? l3Name,
    bool createIfMissing = false,
  }) async {
    String? l1Id, l2Id, l3Id;
    if (l1Name != null) {
      l1Id = await _folderIdByNameUnder(l1Name, null);
      if (l1Id == null && createIfMissing) {
        l1Id = (await createFolderNode(parentId: null, name: l1Name)).id;
      }
    }
    if (l2Name != null && l1Id != null) {
      l2Id = await _folderIdByNameUnder(l2Name, l1Id);
      if (l2Id == null && createIfMissing) {
        l2Id = (await createFolderNode(parentId: l1Id, name: l2Name)).id;
      }
    }
    if (l3Name != null && l2Id != null) {
      l3Id = await _folderIdByNameUnder(l3Name, l2Id);
      if (l3Id == null && createIfMissing) {
        l3Id = (await createFolderNode(parentId: l2Id, name: l3Name)).id;
      }
    }
    return [l1Id, l2Id, l3Id];
  }


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
    final id = _uuidStage6.v4();
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
    // 하위 폴더가 있으면 삭제 불가
    final hasChildren = _childrenIndex[id]?.isNotEmpty == true;
    if (hasChildren) throw StateError('Folder has subfolders');

    // 어떤 아이템 경로에도 쓰이면 삭제 불가
    final isUsed = _itemPaths.values.any((path) => path.contains(id));
    if (isUsed) throw StateError('Folder is referenced by items');

    final node = _folders.remove(id);
    if (node != null) {
      _childrenIndex[node.parentId]?.remove(id);
    }
    notifyListeners();
  }

  // === 아이템 목록: 모든 단계 허용 ===
  Future<List<Item>> listItemsByFolderPath({
    String? l1,
    String? l2,
    String? l3,
    String? keyword,
    bool recursive = false, // ← 추가: 기본 비재귀(직속만)
  }) async {
    Iterable<MapEntry<String, Item>> it = _items.entries;

    final wantedDepth = (l1 == null) ? 0 : (l2 == null) ? 1 : (l3 == null) ? 2 : 3;

    bool _pathMatches(String itemId) {
      final path = _itemPaths[itemId];
      if (path == null) return false;
      // ✅ 경로 일부만 지정돼도 허용
      if (l1 != null && (path.isEmpty || path[0] != l1)) return false;
      if (l2 != null && (path.length < 2 || path[1] != l2)) return false;
      if (l3 != null && (path.length < 3 || path[2] != l3)) return false;

      // 🔑 비재귀면 "직속"만 (경로 길이 정확히 일치)
      if (!recursive) return path.length == wantedDepth;

      return true;
    }

    it = it.where((e) => _pathMatches(e.key));

    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim().toLowerCase();
      it = it.where((e) {
        final v = e.value;
        return v.name.toLowerCase().contains(k) || v.sku.toLowerCase().contains(k);
      });
    }
    return it.map((e) => e.value).toList(growable: false);
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
  final items = await searchItems(l1: l1, l2: l2, l3: l3, keyword: keyword, recursive: recursive);

  return (folders, items);
}


// === 기존 searchItems: 재귀 탐색시 모든 단계 아이템 포함 ===
Future<List<Item>> searchItems({
  String? l1,
  String? l2,
  String? l3,
  required String keyword,
  bool recursive = true,
}) async {
  final k = keyword.trim().toLowerCase();
  if (k.isEmpty) return const [];

  bool pathMatchesPrefix(String itemId) {
    final path = _itemPaths[itemId];
    if (path == null) return false;
    if (l1 != null && (path.isEmpty || path[0] != l1)) return false;
    if (l2 != null && (path.length < 2 || path[1] != l2)) return false;
    // ✅ 재귀 검색 시 l3 미지정이면 하위 전체 포함
    if (!recursive && l3 != null) {
      return path.length >= 3 && path[2] == l3;
    }
    return true;
  }

  return _items.entries
      .where((e) => pathMatchesPrefix(e.key))
      .map((e) => e.value)
      .where((v) =>
  v.name.toLowerCase().contains(k) ||
      v.sku.toLowerCase().contains(k))
      .toList();
}

  // ItemRepo
  @override
  Future<List<Item>> listItems({String? folder, String? keyword}) async {
    Iterable<Item> values = _items.values;
    if (folder != null) {
      values = values.where( (e) => e.folder == folder);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.toLowerCase();
      values = values.where((e) => e.name.toLowerCase().contains(k) || e.sku.toLowerCase().contains(k));
    }
    final list = values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<Item?> getItem(String id) async => _items[id];

  @override
  Future<void> upsertItem(Item item) async {
    _items[item.id] = item;
    notifyListeners();
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.remove(id);
    notifyListeners();
  }

  @override
  Future<void> adjustQty({
    required String itemId,
    required int delta,
    String? refType,  // ← 인터페이스에 맞춰 String?
    String? refId,    // ← 인터페이스에 맞춰 String?
    String? note})
  async {
    final it = _items[itemId];
    if (it == null) return;

    final updated = it.copyWith(qty: it.qty  + delta);
    _items[itemId] = updated;

    // String? -> enum 매핑 (null 안전)
    RefType _parseRefType(String? s) {
      switch (s) {
        case 'order':    return RefType.order;
        case 'work':     return RefType.work;
        case 'purchase': return RefType.purchase;
        default:         return RefType.order; // 기본값
      }
    }

    final txn = Txn(
      id: _uuid.v4(),
      ts: DateTime.now(),
      type: delta >= 0 ? TxnType.in_ : TxnType.out_, // ← enum 값 수정
      itemId: itemId,
      qty: delta.abs(),
      refType: _parseRefType(refType),                 // ✅ enum으로 변환
      refId: refId ?? 'unknown',                       // ✅ null 방지

      note: note,
    );
    _txns[txn.id] = txn;
    notifyListeners();
  }

  @override
  Future<String?> nameOf(String itemId) async {
    return _items[itemId]?.name; // 없으면 null
  }

  // OrderRepo
  @override
  Future<List<Order>> listOrders() async {
    final list = _orders.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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


  // TxnRepo
  @override
  Future<List<Txn>> listTxns({String? itemId}) async {
    final list = _txns.values.where((t) => itemId == null || t.itemId == itemId).toList()
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
      itemId: itemId,
      qty: qty,
      refType: RefTypeX.fromString(refType),
      refId: refId,
      note: note ?? 'planned inbound',
    );
    _txns[txn.id] = txn;
    notifyListeners();
  }

// addInActual
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
    itemId: itemId,
    qty: qty,
    refType: RefTypeX.fromString(refType),
    refId: refId,
    note: note ?? 'actual inbound',
  );
  _txns[txn.id] = txn;       // ✅ Map 저장

    final it = _items[itemId];
    if (it != null) {
      _items[itemId] = it.copyWith(qty: it.qty + qty); // ✅
    }
    notifyListeners();
  }

  // BomRepo
  @override
  Future<List<BomRow>> listBom(String outputItemId) async {
    return _bom.values.where((b) => b.outputItemId == outputItemId).toList();
  }

  @override
  Future<void> upsertBomRow(BomRow row) async {
    _bom[row.id] = row;
    notifyListeners();
  }

  @override
  Future<void> deleteBomRow(String id) async {
    _bom.remove(id);
    notifyListeners();
  }

  // ----------------- WorkRepo -----------------
  final _works = <String, Work>{};

  @override
  Future<String> createWork(Work w) async {
    final now = DateTime.now();
        final id  = (w.id.isNotEmpty) ? w.id : _uuid.v4();
        final saved = w.copyWith(
          id: id,
          status: w.status, // 모델이 non-null이라면 그대로 사용
          // 만약 모델이 nullable이라면 아래처럼 안전장치 두세요:
          // status: w.status ?? WorkStatus.planned,
          createdAt: w.createdAt ?? now,
          updatedAt: now,
        );
        _works[id] = saved;
        print('[InMemoryRepo] createWork -> ${saved.id} ${saved.status}');

    notifyListeners();
        return id;
  }

  @override
  Future<Work?> getWorkById(String id) async => _works[id];

  @override
  Stream<List<Work>> watchAllWorks() {
        // ChangeNotifier -> Stream 브리지
        final c = StreamController<List<Work>>.broadcast();
        void emit() => c.add(_works.values.toList());
        c.onListen = emit;      // 최초 1회
        final listener = () => emit();    // 변경 시마다 emit
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

    // 실제 입고 반영
    await addInActual(
      itemId: w.itemId,
      qty: w.qty,
      refType: 'work',
      refId: id,
      note: '작업 완료 입고',
    );

    // 상태 업데이트
    _works[id] = w.copyWith(
        status: WorkStatus.done,
        updatedAt: DateTime.now());
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
        void emit() => c.add(_purchases.values.toList());
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

    // 실제 입고 반영
    await addInActual(
      itemId: p.itemId,
      qty: p.qty,
      refType: 'purchase',
      refId: id,
      note: '발주 입고 완료',
    );

    // 상태 업데이트
    _purchases[id] =
        p.copyWith(status: PurchaseStatus.received,
            updatedAt: DateTime.now());
    notifyListeners();
  }



}
