import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'package:stockapp_mvp/src/repos/inmem_repo.dart';

import 'package:stockapp_mvp/src/models/txn.dart';
import 'widgets/txn_row.dart';


class TxnListScreen extends StatelessWidget {
  const TxnListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TxnRepo>();
    context.watch<InMemoryRepo>(); // 🔔 트랜잭션 변경 시 리빌드

    return Scaffold(
      appBar: AppBar(title: const Text('입·출고 기록')),
      body: FutureBuilder<List<Txn>>(
        future: repo.listTxns(),
        builder: (context, snap) {
          final txns = snap.data ?? const <Txn>[];
          if (txns.isEmpty) {
            return const Center(child: Text('기록이 없습니다.'));
          }
          return ListView.separated(
            itemCount: txns.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => TxnRow(t: txns[i]),
          );
        },
      ),
    );
  }
}