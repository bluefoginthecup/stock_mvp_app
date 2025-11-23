import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/inventory_service.dart';
import '../../repos/repo_interfaces.dart';
// import '../../repos/inmem_repo.dart'; // ❌ 제거

import '../../models/order.dart';
import '../../models/work.dart';
import '../../models/purchase_order.dart'; // ✅ 변경: purchase.dart → purchase_order.dart
import '../../models/txn.dart';

import '../common/ui.dart'; // confirmDelete, showUndoSnackBar

enum _MoreAction { softDelete, hardDelete }

/// 더보기(⋯) 메뉴에 "삭제" 액션을 공통 제공하는 위젯.
/// T: Order / Work / PurchaseOrder / Txn
class DeleteMoreMenu<T> extends StatelessWidget {
  final T entity;

  /// 삭제 완료/Undo 이후 리스트를 갱신하거나 상위 상태를 조정하고 싶을 때 훅
  final VoidCallback? onChanged;

  const DeleteMoreMenu({
    super.key,
    required this.entity,
    this.onChanged,
  });

  // 타입별 문자열
  (String title, String softMsg, String hardMsg, String undoMsg) _stringsFor(BuildContext ctx) {
    if (entity is Order) {
      return ('주문', '이 주문을 삭제할까요?', '이 주문을 완전히 삭제할까요? (되돌릴 수 없음)', '주문을 삭제했어요');
    } else if (entity is Work) {
      return ('작업계획', '이 작업을 삭제할까요? (진행/완료면 취소 처리)', '이 작업을 완전히 삭제할까요? (되돌릴 수 없음)', '작업계획을 삭제했어요');
    } else if (entity is PurchaseOrder) {
      return ('발주', '이 발주를 삭제할까요?', '이 발주를 완전히 삭제할까요? (되돌릴 수 없음)', '발주를 삭제했어요');
    } else if (entity is Txn) {
      return ('입출고 기록', '이 기록을 삭제할까요?', '이 기록을 완전히 삭제할까요? (되돌릴 수 없음)', '입출고 기록을 삭제했어요');
    }
    return ('항목', '삭제할까요?', '완전히 삭제할까요?', '삭제했어요');
  }

  Future<void> _handleDelete(BuildContext context, {required bool hard}) async {
    final (title, softMsg, hardMsg, undoMsg) = _stringsFor(context);
    final confirmed = await confirmDelete(
      context,
      title: '$title 삭제',
      message: hard ? hardMsg : softMsg,
      confirmLabel: hard ? '완전 삭제' : '삭제',
    );
    if (!confirmed) return;

    // ✅ 필요한 의존성/레포를 "지금" 캡처
    final inv       = context.read<InventoryService>();
    final orderRepo = context.read<OrderRepo>();
    final workRepo  = context.read<WorkRepo>();
    final poRepo    = context.read<PurchaseOrderRepo>();
    final txnRepo   = context.read<TxnRepo>(); // ✅ InMemoryRepo 대신 TxnRepo 사용

    if (entity is Order) {
      final id = (entity as Order).id;
      final snap = await orderRepo.getOrder(id);

      await inv.deleteOrderCascade(id, hard: hard);
      if (!hard) {
        showUndoSnackBar(context, message: undoMsg, onUndo: () async {
          if (snap != null) {
            await orderRepo.upsertOrder(snap.copyWith(isDeleted: false));
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문을 완전 삭제했어요')),
        );
      }
      onChanged?.call();

    } else if (entity is Work) {
      final id = (entity as Work).id;
      final snap = await workRepo.getWorkById(id);

      await inv.deleteWorkSafe(id, hard: hard);
      if (!hard) {
        showUndoSnackBar(context, message: undoMsg, onUndo: () async {
          if (snap != null) {
            await workRepo.updateWork(snap.copyWith(isDeleted: false));
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('작업계획을 완전 삭제했어요')),
        );
      }
      onChanged?.call();

    } else if (entity is PurchaseOrder) {
      final id = (entity as PurchaseOrder).id;
      final snap = await poRepo.getPurchaseOrderById(id);

      // InventoryService 안에서 발주 삭제 처리(soft/hard) 수행
      await inv.deletePurchase(id, hard: hard);

      if (!hard) {
        showUndoSnackBar(context, message: undoMsg, onUndo: () async {
          if (snap != null) {
            await poRepo.updatePurchaseOrder(snap.copyWith(isDeleted: false));
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('발주를 완전 삭제했어요')),
        );
      }
      onChanged?.call();

    } else if (entity is Txn) {
      final t = entity as Txn;

      await inv.deleteTxn(t.id); // 삭제(및 필요 시 재고 롤백) 처리

      // ✅ Undo: InMemoryRepo.restoreTxnForUndo(t) 대신 TxnRepo로 원상 복구
      //  - 어떤 종류(planned/actual)였는지 모르겠다면 실제 반영되는 addInActual로 복원하는 것이 실무적으로 안전
      showUndoSnackBar(context, message: undoMsg, onUndo: () async {
        try {
          final refId = (t.refId.isEmpty) ? 'undo:${t.id}' : t.refId; // 빈 문자열 방어만
          await txnRepo.addInActual(
            itemId: t.itemId,      // String
            qty: t.qty,            // int
            refType: t.refType.name,    // RefType(enum) ✅
            refId: refId,          // String
            note: t.note,          // String?
            // ts: t.ts,  // 필요하면 전달
          );
        } catch (_) {
          // 실패 시 사용자에게 간단 안내(침묵 실패 방지)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기록 복원에 실패했어요')),
          );
        }
      });
      onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, _, __, ___) = _stringsFor(context);
    return PopupMenuButton<_MoreAction>(
      tooltip: '더보기',
      onSelected: (act) async {
        switch (act) {
          case _MoreAction.softDelete:
            await _handleDelete(context, hard: false);
            break;
          case _MoreAction.hardDelete:
            await _handleDelete(context, hard: true);
            break;
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<_MoreAction>>[
        PopupMenuItem(
          value: _MoreAction.softDelete,
          child: Row(
            children: [
              const Icon(Icons.delete_outline),
              const SizedBox(width: 8),
              Text('$title 삭제'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MoreAction.hardDelete,
          child: Row(
            children: [
              const Icon(Icons.delete_forever),
              const SizedBox(width: 8),
              Text('$title 완전 삭제'),
            ],
          ),
        ),
      ],
    );
  }
}
