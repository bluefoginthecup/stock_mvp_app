import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/roll_fabric_plan.dart';
import '../services/roll_optimizer_storage_service.dart';

class RollOptimizerPlanListScreen extends StatefulWidget {
  const RollOptimizerPlanListScreen({super.key});

  @override
  State<RollOptimizerPlanListScreen> createState() =>
      _RollOptimizerPlanListScreenState();
}

class _RollOptimizerPlanListScreenState
    extends State<RollOptimizerPlanListScreen> {
  final _storage = const RollOptimizerStorageService();
  late Future<List<RollOptimizerPlanSet>> _future;

  @override
  void initState() {
    super.initState();
    _future = _storage.loadPlans();
  }

  void _reload() {
    setState(() {
      _future = _storage.loadPlans();
    });
  }

  Future<void> _delete(RollOptimizerPlanSet plan) async {
    await _storage.deletePlan(plan.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${plan.displayName} 삭제됨')),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('저장된 롤 최적화')),
      body: FutureBuilder<List<RollOptimizerPlanSet>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final plans = snap.data ?? [];
          if (plans.isEmpty) {
            return const Center(child: Text('저장된 롤 최적화가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final plan = plans[index];
              final cutCount = plan.rolls.fold<int>(
                0,
                (sum, roll) => sum + roll.cuts.length,
              );
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading:
                      CircleAvatar(child: Text(plan.rolls.length.toString())),
                  title: Text(
                    plan.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '롤 ${plan.rolls.length}개 / 재단 항목 $cutCount개\n${DateFormat('yyyy.MM.dd HH:mm').format(plan.updatedAt)}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(context, plan),
                  trailing: IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(plan),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
