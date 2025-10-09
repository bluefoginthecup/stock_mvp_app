import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'package:stockapp_mvp/src/repos/inmem_repo.dart';

import 'package:stockapp_mvp/src/models/txn.dart';
import 'package:stockapp_mvp/src/models/types.dart'; // ✅ TxnType, RefType 여기서 옴

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
            itemBuilder: (_, i) {
              final t = txns[i];

              // ✅ enum 값은 in_ / out_
              final isIn = t.type == TxnType.in_;
              final sign = isIn ? '+' : '-';

              return ListTile(
                leading: Icon(
                  isIn ? Icons.call_received : Icons.call_made,
                ),
                // itemId만 있으므로 우선 그대로 표시 (원하면 item 이름 lookup 해도 됨)
                title: Text('$sign${t.qty} • ${t.itemId}'),
                // ✅ refType은 enum, nullable 아님 → name 사용
                subtitle: Text(
                  '${t.ts.toIso8601String()} • ${t.refType.name} / ${t.refId}',
                ),
                dense: true,
              );
            },
          );
        },
      ),
    );
  }
}
