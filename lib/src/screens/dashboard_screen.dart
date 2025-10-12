import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repos/repo_interfaces.dart';
import '../ui/common/ui.dart';

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
              //요약
              Text(context.t.dashboard_summary, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                //전체품목
                _StatCard(title: context.t.dashboard_total_items, value: items.length.toString()),
                //임계치이하
                _StatCard(title: context.t.dashboard_below_threshold, value: low.length.toString()),
              ]),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/orders'),
                icon: const Icon(Icons.assignment),
                label: Text(context.t.dashboard_orders),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/stock'),
                icon: const Icon(Icons.inventory_2),
                label: Text(context.t.dashboard_stock),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/txns'),
                icon: const Icon(Icons.swap_vert),
                label: Text(context.t.dashboard_txns),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/works'),
                icon: const Icon(Icons.precision_manufacturing),
                label: Text(context.t.dashboard_works),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/purchases'),
                icon: const Icon(Icons.local_shipping),
                label: Text(context.t.dashboard_purchases),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings/language'),
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
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
