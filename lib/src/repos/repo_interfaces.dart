// lib/src/repos/repo_interfaces.dart
import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/work.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';
import '../models/types.dart';
import '../models/suppliers.dart';
import '../models/folder_node.dart';
import 'package:flutter/foundation.dart'; // ChangeNotifier


/// 공통 규칙:
/// - 모든 Repo는 비동기(Future) 시그니처를 기본으로 함.
/// - "표준 인터페이스"는 최소 메서드만 강제.
/// - 구현체에서 더 리치한 메서드를 제공하더라도, 표준과 시그니처가 다르면 @override를 붙이지 말 것.

abstract class ItemRepo {
  /// 폴더 경로/키워드 기반의 기본 조회
  Future<List<Item>> listItems({String? folder, String? keyword});

  /// 전역 단순 검색(경로 무시)
  Future<List<Item>> searchItemsGlobal(String keyword);

  /// 경로 기반 검색 표준화
  Future<List<Item>> searchItemsByPath({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  });

  Future<Item?> getItem(String id);
  Future<void> upsertItem(Item item);
  Future<void> deleteItem(String id);
  /// 아이템 ID로 경로명(루트~디자인)을 반환
  /// 예: ["완제품", "사계절", "루앙 그레이"]
  Future<List<String>> itemPathNames(String itemId);

  /// 재고 조정(입출고 공용)
  Future<void> adjustQty({
    required String itemId,
    required int delta,
    String? refType,
    String? refId,
    String? note,
    String? memo,
});

    /// 단위/환산 프로필 업데이트 (선택적 필드만 변경)
    Future<void> updateUnits({
      required String itemId,
      String? unitIn,
      String? unitOut,
      double? conversionRate,
    });
  /// itemId → 사람 읽는 아이템명
  Future<String?> nameOf(String itemId);



    // ===== BOM (2단계 분리형) =====
    /// Finished 레시피 조회/저장
    List<BomRow> finishedBomOf(String finishedItemId);
    Future<void> upsertFinishedBom(String finishedItemId, List<BomRow> rows);

    /// Semi-finished 레시피 조회/저장
    List<BomRow> semiBomOf(String semiItemId);
    Future<void> upsertSemiBom(String semiItemId, List<BomRow> rows);
  /// itemId에 해당하는 현재 재고 수량을 반환
  int stockOf(String itemId);

}

abstract class OrderRepo {
  Future<List<Order>> listOrders({bool includeDeleted = false});
  Future<Order?> getOrder(String id);
  Future<void> upsertOrder(Order order);

  /// orderId → 사람 읽는 주문자명
  Future<String?> customerNameOf(String orderId);


  // 🧹 삭제 정책
  /// 기본: 소프트 삭제(isDeleted=true). 목록/검색에서 숨김.
  Future<void> softDeleteOrder(String orderId);

  /// 관리용: 하드 삭제. 연계 데이터 처리는 상위 서비스에서 보장.
  Future<void> hardDeleteOrder(String orderId);

  /// 복구: soft delete 해제
  Future<void> restoreOrder(String orderId);
}

abstract class TxnRepo {
  Future<List<Txn>> listTxns();

  Future<void> addInPlanned({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  });

  Future<void> addInActual({
    required String itemId,
    required int qty,
    required String refType,
    required String refId,
    String? note,
  });


  // ✅ 추가: 동기 스냅샷 (정렬까지 된 최신 리스트)
  List<Txn> snapshotTxnsDesc();

  // 🧹 삭제 정책
  /// 단건 하드 삭제(실수 입력 취소 등)
  Future<void> deleteTxn(String txnId);

  /// (선택) 특정 참조에 묶인 planned 기록 일괄 삭제
  Future<void> deletePlannedByRef({
    required String refType,
    required String refId,
  });
}


/// ✅ BOM 표준 인터페이스(최소 메서드)
/// - 구현체 내부에 finished/semi 같은 리치 API가 있더라도, 시그니처가 다르면 @override 금지
abstract class BomRepo {
  /// parentItemId의 BOM 전체 조회 (필요 시 호출부에서 root로 필터)
  Future<List<BomRow>> listBom(String parentItemId);

  /// BOM 행 추가/갱신
  Future<void> upsertBomRow(BomRow row);

  /// BOM 행 삭제: 구현체는 id를 고유 식별자(예: row.id 또는 규칙 기반)로 해석
  Future<void> deleteBomRow(String id);
}

// Work 전용 — 메서드 이름에 Work 접두사
abstract class WorkRepo {
  Future<String> createWork(Work w);
  Future<Work?> getWorkById(String id);
  Stream<List<Work>> watchAllWorks();
  Future<void> updateWork(Work w);
  Future<void> completeWork(String id);

  /// 상태만 변경(재고 반영 없음). 예) planned → inProgress, 또는 취소
  Future<void> updateWorkStatus(String id, WorkStatus status);

  /// 선택: 편의 메서드
  Future<void> cancelWork(String id) => updateWorkStatus(id, WorkStatus.canceled);

  // 🧹 삭제 정책
  /// 기본: 소프트 삭제 (planned면 삭제, 진행/완료면 canceled 권장)
  Future<void> softDeleteWork(String workId);

  /// 관리용: 하드 삭제(연계 planned Txn 등은 상위/내부에서 정리)
  Future<void> hardDeleteWork(String workId);
}

abstract class PurchaseOrderRepo {
  Future<String> createPurchaseOrder(PurchaseOrder po);
  Future<void> updatePurchaseOrder(PurchaseOrder po);
  Future<void> updatePurchaseOrderStatus(String id, PurchaseOrderStatus status);
  Stream<List<PurchaseOrder>> watchAllPurchaseOrders();
  Future<PurchaseOrder?> getPurchaseOrderById(String id);
  Future<void> softDeletePurchaseOrder(String id);
  Future<void> hardDeletePurchaseOrder(String id);
  /// 복구: soft delete 해제
  Future<void> restorePurchaseOrder(String id);


  // Lines
  Future<void> upsertLines(String orderId, List<PurchaseLine> lines);
  Future<List<PurchaseLine>> getLines(String orderId);


}

abstract class SupplierRepo {
  Future<List<Supplier>> list({String? q, bool onlyActive = true});
  Future<Supplier?> get(String id);
  /// 새로 만들기/수정 공용. 반환: 저장된 id
  Future<String> upsert(Supplier s);
  Future<void> softDelete(String id); // 필요 시 실제 삭제로 교체 가능
  Future<void> toggleActive(String id, bool isActive);
}
// 맨 아래 부분만 이렇게 정리 👇

// === Common move types (top-level) ===
enum EntityKind { item, folder }
enum FolderSortMode { name, manual }

class MoveRequest {
  final EntityKind kind;      // itemId or folderId
  final String id;            // itemId or folderId
  final List<String> pathIds; // [L1], [L1,L2], [L1,L2,L3]
  const MoveRequest({
    required this.kind,
    required this.id,
    required this.pathIds,
  });
}

enum TrashEntityKind { order, purchase /*, item, txn, work, supplier, folder */ }

class TrashEntry {
    final TrashEntityKind kind;
    final String entityId;
    final String title;
    final DateTime deletedAt;
    final String? metaJson;
    const TrashEntry({
      required this.kind,
      required this.entityId,
      required this.title,
      required this.deletedAt,
      this.metaJson,
    });
  }

abstract class TrashRepo {
    Future<List<TrashEntry>> list({
      TrashEntityKind? kind,
      String? keyword,
      int limit = 50,
    });
    Future<void> restore(TrashEntityKind kind, String entityId);
    Future<void> hardDelete(TrashEntityKind kind, String entityId);
    Future<int> purgeOlderThan(Duration keep);
  }

/// 폴더 트리 + 경로 기반 검색/이동용 Repo
abstract class FolderTreeRepo extends ChangeNotifier {
  FolderSortMode get sortMode;
  /// 정렬 모드 변경 (동기)
  void setSortMode(FolderSortMode mode);

  /// parentId가 null이면 L1 roots
  Future<List<FolderNode>> listFolderChildren(String? parentId);

  FolderNode? folderById(String id);


  /// parentId가 null이면 루트 폴더
  Future<FolderNode> createFolderNode({
    required String? parentId,
    required String name,
  });

  Future<void> renameFolderNode({
    required String id,
    required String newName,
  });

  Future<void> deleteFolderNode(String id);

  /// 폴더/아이템 공통 이동 (기존 moveEntityToPath 그대로)
  Future<void> moveEntityToPath(MoveRequest req);

  /// 아이템 여러 개를 특정 경로로 이동
  Future<int> moveItemsToPath({
    required List<String> itemIds,
    required List<String> pathIds,
  });

  /// 검색: 폴더 + 아이템 동시에
  Future<(List<FolderNode>, List<Item>)> searchAll({
    String? l1,
    String? l2,
    String? l3,
    required String keyword,
    bool recursive = true,
  });

}
