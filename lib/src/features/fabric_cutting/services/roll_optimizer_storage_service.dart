import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/roll_fabric_plan.dart';

class RollOptimizerStorageService {
  const RollOptimizerStorageService();

  Future<File> get _storageFile async {
    final dir = await getApplicationDocumentsDirectory();
    final featureDir = Directory(p.join(dir.path, 'fabric_cutting'));
    if (!await featureDir.exists()) {
      await featureDir.create(recursive: true);
    }
    return File(p.join(featureDir.path, 'roll_optimizer_plans.json'));
  }

  Future<List<RollOptimizerPlanSet>> loadPlans() async {
    final file = await _storageFile;
    if (!await file.exists()) return [];

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final plans = decoded
          .whereType<Map>()
          .map((e) =>
              RollOptimizerPlanSet.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return plans;
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlan(RollOptimizerPlanSet plan) async {
    final plans = await loadPlans();
    final updated = plan.copyWith(updatedAt: DateTime.now());
    final index = plans.indexWhere((e) => e.id == plan.id);
    if (index >= 0) {
      plans[index] = updated;
    } else {
      plans.insert(0, updated);
    }
    await _writePlans(plans);
  }

  Future<void> deletePlan(String id) async {
    final plans = await loadPlans();
    plans.removeWhere((e) => e.id == id);
    await _writePlans(plans);
  }

  Future<void> _writePlans(List<RollOptimizerPlanSet> plans) async {
    final file = await _storageFile;
    const encoder = JsonEncoder.withIndent('  ');
    await file
        .writeAsString(encoder.convert(plans.map((e) => e.toJson()).toList()));
  }
}
