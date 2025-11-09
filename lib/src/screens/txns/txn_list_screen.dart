import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'package:stockapp_mvp/src/repos/inmem_repo.dart' as repos; // ✅ 추가 (중요)

import 'widgets/txn_row.dart';
import '../../ui/common/ui.dart';

class TxnListScreen extends StatelessWidget {
  const TxnListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔔 InMemoryRepo를 구독해서 리빌드 트리거
    context.watch<repos.InMemoryRepo>();

    // 📚 데이터 접근은 인터페이스로
    final txRepo = context.read<TxnRepo>();
    final list = txRepo.snapshotTxnsDesc();

    return Scaffold(
      appBar: AppBar(title: Text(context.t.dashboard_txns)),
      body: list.isEmpty
          ? Center(child: Text(context.t.txns_empty))
          : ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => TxnRow(t: list[i]),
      ),
    );
  }
}
