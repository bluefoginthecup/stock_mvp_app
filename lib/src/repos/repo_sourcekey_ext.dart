
import '../models/work.dart';
import '../models/txn.dart';
import 'repo_interfaces.dart';


/// ===== Work: sourceKey 기반 멱등 upsert =====
extension WorkRepoSourceKeyExt on WorkRepo {
  /// watchAllWorks()가 즉시 스냅샷을 내보내는(Behavior/Replay 성격) 전제.
  /// 그렇지 않다면 timeout 시간을 늘리거나, 레포 구현에서 초기 emit을 보장하세요.
  Future<List<Work>> _listAllWorks() async {
    // 즉시 스냅샷 1회 획득
    return await watchAllWorks()
        .first
        .timeout(const Duration(seconds: 3), onTimeout: () => <Work>[]);
  }

  Future<Work?> findBySourceKey(String key) async {
    final all = await _listAllWorks();
    for (final w in all) {
      if (w.sourceKey == key) return w;
    }
    return null;
  }

  /// create / update 표준 패턴으로 멱등 upsert
  Future<void> upsertBySourceKey(Work w) async {
    final key = w.sourceKey;
    if (key == null || key.isEmpty) {
      await createWork(w); // 키 없으면 신규
      return;
    }
    final existed = await findBySourceKey(key);
    if (existed == null) {
      await createWork(w);
    } else {
      // 기존 id 유지하며 업데이트
      await updateWork(w.copyWith(id: existed.id));
    }
  }
}

/// ===== Txn(예정입고 중심): sourceKey 기반 멱등 upsert =====
/// 프로젝트의 TxnRepo 시그니처에 맞춰 _listAllTxns 구현을 선택하세요.
extension TxnRepoSourceKeyExt on TxnRepo {
  Future<List<Txn>> _listAllTxns() async {  return await listTxns();
  }

  Future<Txn?> findBySourceKey(String key) async {
    final all = await _listAllTxns();
    for (final t in all) {
      if (t.sourceKey == key) return t;
    }
    return null;
  }

  /// planned-in 전용 upsert
  Future<void> upsertPlannedInBySourceKey(Txn t) async {
    final key = t.sourceKey;

    if (key == null || key.isEmpty) {
      // 키 없으면 중복 가능성 감수하고 그냥 addInPlanned 사용
      await addInPlanned(
        itemId: t.itemId,
        qty: t.qty,
        refType: t.refType.name,
        refId: t.refId,
        note: t.note ?? '',
      );
      return;
    }

    final existed = await findBySourceKey(key);
    if (existed == null) {
      await addInPlanned(
        itemId: t.itemId,
        qty: t.qty,
        refType: t.refType.name,
        refId: t.refId,
        note: t.note ?? '',
      );
    } else {
      // updateTxn이 있다면 그걸 사용:
      // await updateTxn(t.copyWith(id: existed.id));
      // 없다면 정책에 맞게 처리 — 임시로 다시 add 전략 유지
      await addInPlanned(
        itemId: t.itemId,
        qty: t.qty,
        refType: t.refType.name,
        refId: t.refId,
        note: t.note ?? '',
      );
    }
  }
}
