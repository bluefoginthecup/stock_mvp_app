// lib/src/services/order_planning_service.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/types.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/work.dart';
import '../models/purchase.dart';
import '../repos/repo_interfaces.dart';

// 🔑 sourceKey 기반 upsert/lookup 확장
import '../repos/repo_sourcekey_ext.dart';

class OrderPlanningService {
  final ItemRepo items;
  final OrderRepo orders;
  final WorkRepo works;
  final PurchaseRepo purchases;
  final TxnRepo txns;

  final _uuid = const Uuid();

  OrderPlanningService({
    required this.items,
    required this.orders,
    required this.works,
    required this.purchases,
    required this.txns,
  });

  // ---- 내부 유틸 ----

  // 라인 시그니처: (itemId, qty)만을 비교 대상으로 사용 — 메모 변경 등은 무시
  List<String> _signatureOfLines(List<OrderLine> lines) {
    final sigs = lines
        .map((ln) => '${ln.itemId}:${ln.qty}')
        .toList()
      ..sort();
    return sigs;
  }

  // 동일 라인인지(=메타만 바뀌었는지) 판단
  Future<bool> _isOnlyMetaChanged(Order incoming) async {
    final prev = await orders.getOrder(incoming.id);
    if (prev == null) return false; // 신규 주문은 항상 플래닝 대상
    final a = _signatureOfLines(prev.lines);
    final b = _signatureOfLines(incoming.lines);
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true; // 라인 구성/수량 동일 → 메타만 변경
  }

  // 라인별 고정된 sourceKey (라인 id 없으면 index 사용)
  String _lineKey(Order order, int index, OrderLine ln) {
    // 라인에 고유 id가 있으면 그걸 쓰세요. (예: ln.id ?? index)
    return 'ord:${order.id}:ln:$index';
  }

  // ---- 퍼블릭 API ----

  /// 주문 저장 → (변경된 경우에만) 품목별 부족분 계산 → Work/Purchase & Txn 을 sourceKey로 upsert
  Future<void> saveOrderAndAutoPlanShortage(
      Order order, {
        bool preferWork = true,
      }) async {
    // 1) 기존 라인과 동일한지(=메타만 변경인지) 먼저 판단 (이 시점엔 아직 저장 전)
        var onlyMeta = await _isOnlyMetaChanged(order);
        //    단, 이 주문으로 생성된 계획이 하나도 없다면(첫 실행) 메타변경으로 간주하지 않고 진행
        if (onlyMeta && !(await _hasExistingPlans(order.id))) {
          if (kDebugMode) {
            print('[OrderPlanning] no existing plans for ${order.id} → treat as first-time plan');
          }
          onlyMeta = false;
        }
        // 2) 주문 저장
        await orders.upsertOrder(order);
        // 3) 메타만 변경이면 플래닝 생략 (신규주문은 prev==null → onlyMeta=false라 첫 실행 됨)
        if (onlyMeta) {
          if (kDebugMode) {
            print('[OrderPlanning] meta-only edit: skip autoPlan (order:${order.id})');
          }
          return;
        }


    // 3) 라인이 바뀐 경우: 각 라인별 부족분 → sourceKey 기반 upsert
    for (var i = 0; i < order.lines.length; i++) {
      final ln = order.lines[i];
      final it = await items.getItem(ln.itemId);
      if (it == null) continue;

      // 현재 단순 재고 기준 부족분 계산 (예약 고려 로직이 있다면 그 로직을 사용하세요)
      final available = it.qty;
      final short = (ln.qty - available).clamp(0, 1 << 31);

      // 라인별 고정키
      final baseKey = _lineKey(order, i, ln);

      if (short <= 0) {
        // 부족분이 없어졌다면(=기존 계획 취소 필요)
        // sourceKey 로 기존 레코드가 있다면 '0'으로 덮어써도 되고,
        // delete/cancel API가 있다면 거기로 정리하세요. 여기선 0 덮어서 "없음" 상태로 만듭니다.
        if (preferWork) {
          final w = Work(
            id: _uuid.v4(),
            itemId: ln.itemId,
            qty: 0,
            orderId: order.id,
            status: WorkStatus.planned,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isDeleted: false,
            sourceKey: '${baseKey}:work',
          );
          await works.upsertBySourceKey(w);
        } else {
          // 구매안의 Txn planned-in 0 으로 덮어쓰기
          final t = Txn(
            id: _uuid.v4(),
            ts: DateTime.now(),
            type: TxnType.in_,
            status: TxnStatus.planned,
            itemId: ln.itemId,
            qty: 0,
            refType: RefType.purchase,
            refId: 'cancel-${_uuid.v4()}', // 기존 것 덮는게 목적이라 id는 의미 없음
            note: '예정입고 취소 (order:${order.id})',
            sourceKey: '${baseKey}:pin',
          );
          await txns.upsertPlannedInBySourceKey(t);
        }
        continue;
      }

      if (preferWork) {
        // 3-A) 생산 Work 계획 upsert (sourceKey 고정)
        final w = Work(
          id: _uuid.v4(), // upsertPlannedInBySourceKey가 기존 id로 바꿔서 저장
          itemId: ln.itemId,
          qty: short,
          orderId: order.id,
          status: WorkStatus.planned,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isDeleted: false,
          sourceKey: '${baseKey}:work',
        );
        await works.upsertBySourceKey(w);

        // 생산 완료시 입고될 예정 Txn도 upsert (planned in, ref=work)
        final t = Txn(
          id: _uuid.v4(),
          ts: DateTime.now(),
          type: TxnType.in_,
          status: TxnStatus.planned,
          itemId: ln.itemId,
          qty: short,
          refType: RefType.work,
          refId: w.id, // upsertPlannedInBySourceKey가 기존 id로 바꾸며, 같은 key로 덮어쓰기됨
          note: '작업 예정입고 (order:${order.id})',
          sourceKey: '${baseKey}:pin', // txn은 별도 suffix로 구분
        );
        await txns.upsertPlannedInBySourceKey(t);
      } else {
        // 3-B) 구매 계획 + 예정입고 Txn upsert
        final pid = _uuid.v4(); // purchase 자체를 운영하려면 PurchaseRepo에도 sourceKey 확장 권장
        final t = Txn(
          id: _uuid.v4(),
          ts: DateTime.now(),
          type: TxnType.in_,
          status: TxnStatus.planned,
          itemId: ln.itemId,
          qty: short,
          refType: RefType.purchase,
          refId: pid,
          note: '구매 예정입고 (order:${order.id})',
          sourceKey: '${baseKey}:pin',
        );
        await txns.upsertPlannedInBySourceKey(t);
      }
    }

    if (kDebugMode) {
      print('[OrderPlanning] saved order ${order.id} & planned shortages (idempotent).');
    }
  }
}


// === 아래 유틸을 OrderPlanningService 바깥(동일 파일) 최하단에 추가 ===
extension _ExistingPlansCheck on OrderPlanningService {
  /// 이 주문으로 이미 생성된 계획이 존재하는가?
    /// 인터페이스상 목록 조회는 TxnRepo에만 있으므로, Planned Txn(예정입고) 존재 여부로 판단한다.

  Future<bool> _hasExistingPlans(String orderId) async {try {
        final ts = await txns.listTxns();
        // 판단 기준(아래 중 하나라도 true면 "이미 계획 있음"):
        // 1) planned 상태의 in(예정입고) 중 note에 'order:<id>' 포함
        // 2) sourceKey가 'ord:<id>:' 로 시작 (sourceKey를 쓰는 경우)
        return ts.any((t) {
          final noteHit = (t.note ?? '').contains('order:$orderId');
          final srcHit  = (t.sourceKey ?? '').startsWith('ord:$orderId:');
          final isPlannedIn = (t.status == TxnStatus.planned && t.type == TxnType.in_);
          return isPlannedIn && (noteHit || srcHit);
        });
      } catch (_) {
        return false;
      }
    }
  }
