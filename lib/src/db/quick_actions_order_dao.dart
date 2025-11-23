import 'package:drift/drift.dart';
import 'app_database.dart';

part 'quick_actions_order_dao.g.dart';

@DriftAccessor(tables: [QuickActionOrders])
class QuickActionsOrderDao extends DatabaseAccessor<AppDatabase>
    with _$QuickActionsOrderDaoMixin {
  QuickActionsOrderDao(AppDatabase db) : super(db);

  /// 저장된 순서를 액션ID 리스트로 로드 (없으면 빈 리스트)
  Future<List<String>> loadOrder() async {
    final rows = await (select(quickActionOrders)
      ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();
    return rows.map((r) => r.action).toList();
  }

  /// 전체 순서를 통째로 저장 (트랜잭션)
  Future<void> saveOrder(List<String> actionIds) async {
    await transaction(() async {
      await delete(quickActionOrders).go(); // 전체 초기화
      for (var i = 0; i < actionIds.length; i++) {
        await into(quickActionOrders).insertOnConflictUpdate(
          QuickActionOrdersCompanion( // ✅ Companion 사용
            action: Value(actionIds[i]),
            orderIndex: Value(i),
          ),
        );
      }
    });
  }

  /// (선택) 개별 upsert
  Future<void> upsert(String action, int index) async {
    await into(quickActionOrders).insertOnConflictUpdate(
      QuickActionOrdersCompanion(
        action: Value(action),
        orderIndex: Value(index),
      ),
    );
  }
}
