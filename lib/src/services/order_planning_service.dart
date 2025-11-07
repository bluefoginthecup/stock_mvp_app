// lib/src/services/order_planning_service.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/types.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/work.dart';
import '../models/purchase_order.dart';
import '../models/purchase_line.dart';
import '../repos/repo_interfaces.dart';

// 🔑 sourceKey 기반 upsert/lookup 확장
import '../repos/repo_sourcekey_ext.dart';

class OrderPlanningService {
  final ItemRepo items;
  final OrderRepo orders;
  final WorkRepo works;
  final PurchaseOrderRepo purchases;
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
        bool forceMake = false, // ← 재고/부족 무시하고 라인 수량대로 생산
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


        // 3) 라인이 바뀐 경우: 각 라인별 '계획 수량' 산출 → sourceKey 기반 upsert

        for (var i = 0; i < order.lines.length; i++) {
      final ln = order.lines[i];
      final it = await items.getItem(ln.itemId);
      if (it == null) continue;

    // 3-A) 부족분(short) 계산 (예약 고려가 있다면 바꾸세요)
          final available = it.qty; // 현재 단순 가용
          final shortRaw = ln.qty - available;
          final double short = shortRaw <= 0 ? 0 : shortRaw.toDouble();

          // 3-B) 최종 계획 수량 결정
          // - forceMake=true  : 재고 무시 → 라인 수량대로 작업
          // - forceMake=false : 부족분만큼만 작업
          final double plannedQty = (forceMake ? ln.qty.toDouble() : short);

    // 라인별 고정키
      final baseKey = _lineKey(order, i, ln);

    // 3-C) 계획 수량이 0 이하면:
          //  - Work(qty>0 assert) 생성을 절대 하지 않음
          //  - 필요 시 예정입고 Txn만 0으로 upsert하여 "취소" 표기
          if (plannedQty <= 0) {
            // preferWork 모드에선 work 스킵. (기존 planned-in 취소만 반영할지 선택)
            final t = Txn(
              id: _uuid.v4(),
              ts: DateTime.now(),
              type: TxnType.in_,
              status: TxnStatus.planned,
              itemId: ln.itemId,
              qty: 0,
              refType: preferWork ? RefType.work : RefType.purchase,
              refId: 'cancel-${_uuid.v4()}',
              note: '예정입고 취소 (order:${order.id})',
              sourceKey: '$baseKey:pin',
            );
            await txns.upsertPlannedInBySourceKey(t);
            continue;
          }

      if (preferWork) {
        // 3-D) 생산 Work 계획 upsert (sourceKey 고정)
        final w = Work(
          id: _uuid.v4(), // upsertPlannedInBySourceKey가 기존 id로 바꿔서 저장
          itemId: ln.itemId,
          qty: plannedQty.toInt(),
// ← short 또는 라인수량(강제생산)
          orderId: order.id,
          status: WorkStatus.planned,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isDeleted: false,
          sourceKey: '$baseKey:work',
        );
        await works.upsertBySourceKey(w);

        // 생산 완료시 입고될 예정 Txn도 upsert (planned in, ref=work)
        final t = Txn(
          id: _uuid.v4(),
          ts: DateTime.now(),
          type: TxnType.in_,
          status: TxnStatus.planned,
          itemId: ln.itemId,
          qty: plannedQty.toInt(),

          refType: RefType.work,
          refId: w.id, // upsertPlannedInBySourceKey가 기존 id로 바꾸며, 같은 key로 덮어쓰기됨
          note: '작업 예정입고 (order:${order.id})',
          sourceKey: '$baseKey:pin', // txn은 별도 suffix로 구분
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
          qty: plannedQty.toInt(), // 구매 모드에서도 동일 로직 사용 가능
          refType: RefType.purchase,
          refId: pid,
          note: '구매 예정입고 (order:${order.id})',
          sourceKey: '$baseKey:pin',
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
