import 'subscription_plan.dart';

class AppEntitlement {
  final SubscriptionPlan plan;
  final bool isAppTrialActive;
  final bool isCloudTrialActive;
  final bool hasCloudBackup;
  final DateTime? appTrialEndsAt;
  final DateTime? cloudTrialEndsAt;

  const AppEntitlement({
    required this.plan,
    required this.isAppTrialActive,
    required this.isCloudTrialActive,
    required this.hasCloudBackup,
    this.appTrialEndsAt,
    this.cloudTrialEndsAt,
  });

  static const signedOut = AppEntitlement(
    plan: SubscriptionPlan.free,
    isAppTrialActive: false,
    isCloudTrialActive: false,
    hasCloudBackup: false,
  );

  bool get isPaidPlan =>
      plan == SubscriptionPlan.pro || plan == SubscriptionPlan.business;

  bool get canUseProFeatures => isAppTrialActive || isPaidPlan;

  bool get canEditData => canUseProFeatures;

  bool get canCreateCloudBackup =>
      isCloudTrialActive || (isPaidPlan && hasCloudBackup);

  bool get canRestoreCloudBackup => true;

  String get planLabel {
    if (isAppTrialActive) return 'Trial';
    return plan.label;
  }

  String get cloudBackupLabel {
    if (hasCloudBackup && isPaidPlan) return '사용 중';
    if (isCloudTrialActive) return 'Cloud Trial';
    return '사용 안 함';
  }
}
