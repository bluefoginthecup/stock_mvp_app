import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repos/repo_interfaces.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itemRepo = context.read<ItemRepo>();
    return Scaffold(
      appBar: AppBar(title: const Text('대시보드')),
      body: FutureBuilder(
        future: itemRepo.listItems(),
        builder: (context, snap) {
          final items = (snap.data ?? []);
          final low = items.where((e) => e.qty <= e.minQty).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _StatCard(title: '전체 품목', value: items.length.toString()),
                _StatCard(title: '임계치 이하', value: low.length.toString()),
              ]),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/orders'),
                icon: const Icon(Icons.assignment),
                label: const Text('주문 관리'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/stock'),
                icon: const Icon(Icons.inventory_2),
                label: const Text('재고 관리'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/txns'),
                icon: const Icon(Icons.swap_vert),
                label: const Text('입·출고 기록'),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
