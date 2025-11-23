
import 'package:provider/provider.dart';

import 'package:stockapp_mvp/src/repos/repo_interfaces.dart';
import 'widgets/txn_row.dart';
import '../../ui/common/ui.dart';
import 'package:stockapp_mvp/src/repos/drift_unified_repo.dart';

class TxnListScreen extends StatefulWidget {
  const TxnListScreen({super.key});

  @override
  State<TxnListScreen> createState() => _TxnListScreenState();
}

class _TxnListScreenState extends State<TxnListScreen> {
  @override
  void initState() {
    super.initState();
    // 프레임 이후에 최초 스냅샷 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriftUnifiedRepo>().listTxns();
    });
  }

  Future<void> _refresh() async {
    await context.read<DriftUnifiedRepo>().listTxns();
  }

  @override
  Widget build(BuildContext context) {
    // notifyListeners()를 구독하려면 read가 아니라 watch
    final txRepo = context.watch<DriftUnifiedRepo>();
    final list = txRepo.snapshotTxnsDesc();

    return Scaffold(
      appBar: AppBar(title: Text(context.t.dashboard_txns)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: list.isEmpty
            ? ListView( // RefreshIndicator가 child가 스크롤 가능해야 함
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(child: Text(context.t.txns_empty)),
            ),
          ],
        )
            : ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => TxnRow(t: list[i]),
        ),
      ),
    );
  }
}
