// lib/src/screens/dashboard_screen.dart
import 'package:provider/provider.dart';
import '../repos/repo_interfaces.dart';
import '../ui/common/ui.dart';
import '../screens/stock/stock_browser_screen.dart';
import '../app/main_tab_controller.dart'; // ✅ 추가

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itemRepo = context.read<ItemRepo>();
    return Scaffold(
      appBar: AppBar(title: Text(context.t.dashboard_title)),
      body: FutureBuilder(
        future: itemRepo.listItems(),
        builder: (context, snap) {
          final items = (snap.data ?? []);
          final low = items.where((e) => e.qty <= e.minQty).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.t.dashboard_summary,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _StatCard(
                  title: context.t.dashboard_total_items,
                  value: items.length.toString(),
                  onTap: () {
                    // ✅ 탭 전환: 재고 탭으로 이동
                    context.read<MainTabController>().setIndex(1);
                  },
                ),
                _StatCard(
                  title: context.t.dashboard_below_threshold,
                  value: low.length.toString(),
                  onTap: () {
                    // ✅ 임계치 이하만 보는 전용 화면 push (탭 내부 네비 그대로 사용)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const StockBrowserScreen(showLowStockOnly: true),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // ✅ 나머지 버튼들은 그대로 pushNamed 써도 OK (또는 탭 전환으로 바꿔도 됨)
              ElevatedButton.icon(
                onPressed: () => context.read<MainTabController>().setIndex(1),
                icon: const Icon(Icons.assignment),
                label: Text(context.t.dashboard_orders),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => context.read<MainTabController>().setIndex(2),
                icon: const Icon(Icons.inventory_2),
                label: Text(context.t.dashboard_stock),
              ),


              // 필요 시 기존 라우트 유지
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => context.read<MainTabController>().setIndex(3),
                icon: const Icon(Icons.swap_vert),
                label: Text(context.t.dashboard_txns),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => context.read<MainTabController>().setIndex(4),
                icon: const Icon(Icons.precision_manufacturing),
                label: Text(context.t.dashboard_works),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => context.read<MainTabController>().setIndex(5),
                icon: const Icon(Icons.local_shipping),
                label: Text(context.t.dashboard_purchases),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => context.read<MainTabController>().setIndex(6),
                icon: const Icon(Icons.settings),
                label: Text(context.t.settings_language_title),
              ),
            ],
          );
        },
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  const _StatCard({required this.title, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

