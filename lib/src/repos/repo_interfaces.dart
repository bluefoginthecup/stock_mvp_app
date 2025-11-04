// lib/src/repos/repo_interfaces.dart
import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import '../models/work.dart';
import '../models/purchase.dart';
import '../models/types.dart';

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
  Future<List<Order>> listOrders();
  Future<Order?> getOrder(String id);
  Future<void> upsertOrder(Order order);

  /// orderId → 사람 읽는 주문자명
  Future<String?> customerNameOf(String orderId);

  // 🧹 삭제 정책
  /// 기본: 소프트 삭제(isDeleted=true). 목록/검색에서 숨김.
  Future<void> softDeleteOrder(String orderId);

  /// 관리용: 하드 삭제. 연계 데이터 처리는 상위 서비스에서 보장.
  Future<void> hardDeleteOrder(String orderId);
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

// Purchase 전용 — 메서드 이름에 Purchase 접두사
abstract class PurchaseRepo {
  Future<String> createPurchase(Purchase p);
  Future<Purchase?> getPurchaseById(String id);
  Stream<List<Purchase>> watchAllPurchases();
  Future<void> updatePurchase(Purchase p);
  Future<void> completePurchase(String id);

  /// 상태만 변경(재고 반영 없음). 예) planned → ordered
  Future<void> updatePurchaseStatus(String id, PurchaseStatus status);

  /// 선택: 편의 메서드
  Future<void> cancelPurchase(String id) =>
      updatePurchaseStatus(id, PurchaseStatus.canceled);

  // 🧹 삭제 정책
  /// 기본: 소프트 삭제(isDeleted=true)로 숨김
  Future<void> softDeletePurchase(String purchaseId);

  /// 관리용: 하드 삭제
  Future<void> hardDeletePurchase(String purchaseId);
}
