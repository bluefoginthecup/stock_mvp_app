import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_plan.dart';

class SubscriptionPlanService {
  static const _planKey = 'subscription_plan';

  const SubscriptionPlanService();

  Future<SubscriptionPlan> loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_planKey);
    return SubscriptionPlan.values.firstWhere(
      (plan) => plan.name == value,
      orElse: () => SubscriptionPlan.free,
    );
  }

  Future<void> savePlanForDebug(SubscriptionPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey, plan.name);
  }

  Future<void> resetPlanForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planKey);
  }
}
