import 'package:flutter/foundation.dart'; // ChangeNotifier
import 'package:drift/drift.dart';
import 'dart:async';

// DB
import '../db/app_database.dart';

// 도메인 모델
import '../models/item.dart';
import '../models/folder_node.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/order.dart';
import '../models/work.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';
import '../models/suppliers.dart';
import '../models/lot.dart';
import '../models/types.dart';
import 'package:uuid/uuid.dart';

// 표준 repo 인터페이스
import 'repo_interfaces.dart';
import '../models/trash_entry.dart'; // ← 이 줄 추가 (alias 없이)

// ── 여기서부터 모듈 분리
part 'modules/item_repo.part.dart';
part 'modules/folder_repo.part.dart';
part 'modules/txn_repo.part.dart';
part 'modules/bom_repo.part.dart';
part 'modules/order_repo.part.dart';
part 'modules/work_repo.part.dart';
part 'modules/purchase_repo.part.dart';
part 'modules/supplier_repo.part.dart';
part 'modules/lot_repo.part.dart';
part 'modules/trash_repo.part.dart';


/// ============================================================================
///  DriftUnifiedRepo
///  - 앱의 모든 데이터(재고/주문/생산/발주/거래처/레시피)를 Drift 하나로 통합 관리
/// ============================================================================
// 공통 필드/헬퍼를 담은 베이스 (ChangeNotifier 포함)
abstract class _RepoCore extends ChangeNotifier {
  _RepoCore(this.db);

  final AppDatabase db;

  // ====== 📦 캐시 ======
  final Map<String, Item> _itemsById = {};
  final Map<String, int> _stockCache = {};
  Item? _cachedItemOrNull(String id) => _itemsById[id];
  void _cacheItem(Item it) {
    _itemsById[it.id] = it;
    _stockCache[it.id] = it.qty;
  }
  void _cacheItems(Iterable<Item> list) {
    for (final it in list) _cacheItem(it);
  }

  // ─── BOM 캐시 ───
  final Map<String, List<BomRow>> _bomFinishedCache = {};
  final Map<String, List<BomRow>> _bomSemiCache = {};
  void _cacheBomRows(String parentId, List<BomRow> rows) {
    final finished = <BomRow>[];
    final semi = <BomRow>[];
    for (final r in rows) {
      if (r.root == BomRoot.finished) finished.add(r);
      else if (r.root == BomRoot.semi) semi.add(r);
    }
    if (finished.isNotEmpty || _bomFinishedCache.containsKey(parentId)) {
      _bomFinishedCache[parentId] = finished;
    }
    if (semi.isNotEmpty || _bomSemiCache.containsKey(parentId)) {
      _bomSemiCache[parentId] = semi;
    }
  }

  // ─── Folder 정렬 상태 ───
  FolderSortMode _sortMode = FolderSortMode.name;

  // ─── Txn 스냅샷/구독 ───
  List<Txn> _txnSnapshot = [];
  StreamSubscription? _txnSub;

  @override
  void dispose() {
    _txnSub?.cancel();
    _txnSub = null;
    super.dispose();
  }

  //----bom 스냅샷------
  Future<void> refreshBomSnapshot() async {
    final rows = await db.select(db.bomRows).get();
    _bomFinishedCache.clear();
    _bomSemiCache.clear();
    for (final r in rows) {
      final d = r.toDomain();
      if (d.root == BomRoot.finished) {
        (_bomFinishedCache[d.parentItemId] ??= <BomRow>[]).add(d);
      } else if (d.root == BomRoot.semi) {
        (_bomSemiCache[d.parentItemId] ??= <BomRow>[]).add(d);
      }
    }
  }


  // ─── 다른 모듈에서 참조하는 공용 메서드: 인터페이스(추상)만 노출 ───
  Future<void> _ensureFolderPath({required String l1, String? l2, String? l3});
  Future<Item?> getItem(String id);


}
class DriftUnifiedRepo extends _RepoCore
    with
        ItemRepoMixin,
        FolderRepoMixin,
        TxnRepoMixin,
        BomRepoMixin,
        OrderRepoMixin,
        WorkRepoMixin,
        PurchaseRepoMixin,
        SupplierRepoMixin,
        LotRepoMixin,
        TrashRepoMixin
    implements
        ItemRepo,
        TxnRepo,
        BomRepo,
        OrderRepo,
        WorkRepo,
        PurchaseOrderRepo,
        SupplierRepo,
        FolderTreeRepo,
        TrashRepo{

  final _uuid = const Uuid();
  DriftUnifiedRepo(AppDatabase db) : super(db);
}
